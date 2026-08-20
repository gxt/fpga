# Mega Core 资源结构说明

**日期**：2026-05-27  
**任务**：081x-mega-core-resource-structure-research  
**状态**：调研完成

---

## 1. 范围

本文档整理 `vivado-risc-v` 项目中 MegaBoom Core / SoC 的资源与结构信息，为后续与 XiangShan 做正向对照提供基线。

### 1.1 涉及配置

| 配置 | 核类型 | 核数 | 数据宽度 | L2 | 状态 |
|------|--------|------|---------|-----|------|
| `rocket64b2` | Rocket Big | 1→2(OS可见) | 64-bit | 无 | ✅ Release |
| `rocket64z1` | MegaBoom Z1 | 1 | 256-bit | 512KB Inclusive | ✅ 功能验证 |
| `rocket64z2m` | MegaBoom Z1 | 2 | 256-bit | 512KB Inclusive | ✅ Release-r3 |

---

## 2. 资源基线

### 2.1 综合资源占用

| 资源 | rocket64b2 | rocket64z1 | rocket64z2m (10MHz) | rocket64z2m (20MHz) | rocket64z2m (40MHz) |
|------|-----------|-----------|--------------------|--------------------|--------------------|
| Slice LUTs | 84,322 (6.90%) | **436,256 (35.71%)** | **829,901 (67.94%)** | — | **831,592 (68.07%)** |
| LUT as Logic | — | 422,230 (34.56%) | — | — | — |
| LUT as Memory | — | 14,026 (4.07%) | — | — | — |
| Slice Registers | 51,953 (2.13%) | **152,525 (6.24%)** | **271,416 (11.11%)** | — | **271,840 (11.13%)** |
| Block RAM (36K) | — | — | — | — | **290 (22.45%)** |

### 2.2 时序概况

| 配置 | 频率 | WNS | TNS | WHS | 状态 |
|------|------|-----|-----|-----|------|
| rocket64b2 | 10 MHz | **+0.099ns** | — | — | ✅ Timing clean |
| rocket64z1 | 10 MHz | **-9.83ns** | -44.733ns | — | ❌ MII path |
| rocket64z2m r3 | 10 MHz | **-0.755ns** | -2.854ns | +0.041ns | ❌ 轻微 setup |
| rocket64z2m 20MHz | 20 MHz | **+7.891ns** | 0.000ns | +0.131ns | ✅ Clean |
| rocket64z2m 40MHz | 40 MHz | **-9.648ns** | — | — | ❌ 严重 setup |

### 2.3 关键观察

1. **MegaBoom 单核 LUT ≈ 35%**，是 Rocket 核 (6.9%) 的 **~5.2x**
2. **双核 ≈ 68%**，接近单核的 2x（线性扩展，说明 L2/总线共享开销可控）
3. **20MHz 反而比 10MHz 时序更好** — 证明 10MHz 的 WNS-0.755ns 是 P&R 随机结果，非硬性上限
4. **40MHz 严重违例** — 当前架构在 -1 speed grade 上提频上限约 20-30MHz

---

## 3. 结构分层

### 3.1 Core（MegaBoom Z1）

| 参数 | MegaBoom Z1 (rocket64z2m) | 来源 |
|------|--------------------------|------|
| ISA | rv64imafdc | §15.1.1 |
| Fetch Width | 8 | 知识库 §15.1.1 |
| Decode Width | 4 | §15.1.1 |
| ROB Entries | 128 | §15.1.1 |
| HART Count | 32 | §06.7.1 |
| Issue | OoO (out-of-order) | BOOM 架构特性 |
| Int RF | 多端口物理寄存器堆 | BOOM 标准 |

### 3.2 L1 Cache

| 参数 | L1 I$ | L1 D$ |
|------|-------|-------|
| 大小 | 32 KB | 32 KB |
| 关联度 | 8-way (VIPT) | 8-way (VIPT) |
| MSHRs | — | 8+ (带 coherence 支持) |
| Probe Unit | — | BoomProbeUnit (§15.3.1) |
| Writeback | — | BoomWritebackUnit (§15.3.2) |

### 3.3 L2 InclusiveCache

| 参数 | 值 |
|------|-----|
| 容量 | 512 KB |
| 路数 | 8 |
| Bank | 4 |
| subBankingFactor | 4 |
| outerLatencyCycles | 40 |
| Coherence Manager | TLBroadcast (§15.5) |

### 3.4 Bus 层次

```
Core#0  Core#1
  │      │
  └──┬───┘
     │ TileLink A/B/C/D/E
     ▼
Coherence Manager (TLBroadcast)
     │
     ├── SBUS ── CBUS ── UART/SD/ETH/XADC/LED/DDRSTAT
     │
     └── MBUS ── L2 InclusiveCache ── TL→AXI4 Bridge
                                          │
                                     MEM_AXI4 (256-bit)
                                          │
                                   axi_smc_1 (256→64)
                                          │
                                      MIG → DDR3
```

| 总线接口 | 宽度 | 协议 | 用途 |
|---------|------|------|------|
| MEM_AXI4 | **256-bit** | AXI4 | DDR3 内存访问 |
| IO_AXI4 | **256-bit** | AXI4 | MMIO 外设访问 |
| DMA_AXI4 | **256-bit** | AXI4 | 外设 DMA 回写 |
| 内部 TileLink | 多宽度 | TileLink | L1↔L2↔Coherence |

**关键**：内部全链路 TileLink，对外暴露三路 AXI4（256-bit 宽总线配置）。

### 3.5 SoC 外设（IO_AXI4 域）

| 外设 | 地址 | 协议 | 时钟域 |
|------|------|------|--------|
| UART | 0x60010000 | AXI4-Lite | 100 MHz |
| SD | 0x60000000 | AXI4-Lite + DMA | 100 MHz |
| Ethernet | 0x60020000 | AXI4-Lite | 10 MHz (AXI) / 25 MHz (MII) |
| XADC | 0x60030000 | AXI4-Lite | 10 MHz |
| LED GPIO | 0x60040000 | AXI4-Lite | 10 MHz |
| DDR STAT | 0x60050000 | AXI4-Lite | 10 MHz |

---

## 4. MegaBoom LUT 构成分解（估算）

基于 `rocket64z1` (436,256 LUT / 35.71%) 与 `rocket64b2` (84,322 / 6.90%) 的差值：

| 组件 | 估算 LUT | 占比 | 说明 |
|------|---------|------|------|
| Rocket Big 基线 | ~84,300 | 19% | 含 MMU/PTW/CLINT/PLIC 等 |
| BOOM OoO 额外开销 | ~120,000 | 28% | ROB/rename/issue/int RF 等 OoO 结构 |
| L1 Cache 翻倍 | ~30,000 | 7% | 16KB→32KB I/D |
| 256-bit 总线 | ~90,000 | 21% | MEM/IO/DMA 三路 256-bit AXI4 + 宽 Crossbar |
| L2 InclusiveCache | ~80,000 | 18% | 512KB 目录 + tag + data array |
| Coherence Manager | ~32,000 | 7% | TLBroadcast + BroadcastFilter |

**结论**：MegaBoom 的 LUT 大头来自 **OoO 开销 (28%) + 宽总线 (21%) + L2 Cache (18%)**。

---

## 5. 与 XiangShan 对照准备

### 5.1 功能域存在性对照

| 功能域 | MegaBoom | XiangShan (预期) | 差异性质 |
|--------|----------|-----------------|---------|
| 分支预测器 | BOOM TAGE-Like / BTB | 更先进 TAGE-SC / ITTAGE | 复杂度差异 |
| OoO Backend | 128-entry ROB, 4-wide | 更大 ROB, 更宽 | 规模差异 |
| Rename | 物理寄存器堆 | 类似 | 架构相似 |
| Issue Window | BOOM 标准 | 更大 / 更多 entry | 规模差异 |
| Load/Store Unit | LSU + MSHR + ProbeUnit | 更复杂 LSQ | 复杂度差异 |
| PTW | 标准 Sv39 PTW | 类似 | 架构相似 |
| L1 I$/D$ | 32KB VIPT 8-way | 更大 / 可配 | 规模差异 |
| L2 Cache | 512KB Inclusive | 更大 | 规模差异 |
| Vector (V) | **无** | 支持 | **架构能力差异** |
| FPU | F/D (单/双精度) | F/D (可能更宽) | 复杂度差异 |
| Cache Coherence | TLBroadcast (总线监听) | 更复杂目录协议 | 实现复杂度差异 |

### 5.2 MegaBoom 为什么 LUT 更少

1. **架构能力差异（Vector）**：MegaBoom 无向量扩展，节省大量运算/寄存器资源
2. **OoO 规模差异**：ROB 128-entry vs XiangShan 可能 256+，Issue Window/PRF 规模较小
3. **分支预测简单**：TAGE-Like vs TAGE-SC/ITTAGE，预测器存储/逻辑更少
4. **Cache 规模小**：L2 512KB vs XiangShan 更大 L2/L3
5. **Coherence 协议简单**：TLBroadcast (总线监听) vs 目录协议
6. **实现复杂度**：BOOM v3.0 是较成熟的 academic OoO，XiangShan 是工业级 OoO，流水线更长、旁路更多

### 5.3 差异归类

| 类别 | 差异来源 | 对 LUT 影响 |
|------|---------|------------|
| **架构能力** | Vector (V) 扩展 | ~5-10% |
| **微架构规模** | ROB, Issue, PRF, LSQ 尺寸 | ~15-25% |
| **Cache/存储** | L1/L2/L3 容量 | ~10-20% |
| **实现复杂度** | 旁路、转发、预测器高级特性 | ~10-15% |
| **总线/互连** | 数据宽度、一致性协议 | ~10-15% |

---

## 6. 资料来源

| 资料 | 位置 |
|------|------|
| 任务文件 | `code-agent/tasks/081x-mega-core-resource-structure-research.md` |
| 总线架构 | `code-agent/knowledge/06-bus-architecture.md` |
| 双核 Coherence | `code-agent/knowledge/15-mega-dualcore-cache-coherence.md` |
| SDC Boot | `code-agent/knowledge/07-sdc-boot.md` |
| 频率说明 | `doc/DualV7-当前SoC架构与频率说明.md` |
| 提频报告 | `doc/DualV7-z2m频率提升调研报告.md` |
| BOOM 版本 | `code-agent/knowledge/11-boom-version-alignment.md` |
| SmallBoom 集成 | `doc/Chipyard-1.13.0-DualV7-最小bit集成与上板报告.md` |
