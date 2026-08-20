# DualV7 `rocket64z2m` 频率提升调研报告

**日期**：2026-05-17
**任务**：`069x-genesys2-clock-and-z2m-frequency-up-research`
**状态**：调研完成

---

## 1. 当前 `rocket64z2m` 频率事实

### 1.1 三层频率口径

按 `§12.2.8` 规定的三层拆解：

| 层次 | 值 | 来源 |
|------|-----|------|
| **Declared frequency** | 20.0 MHz | `workspace/rocket64z2m/system-dualv7.tcl:4` (`set riscv_clock_frequency 20.0`) 和 `board/rocket-freq` 默认规则 `.* Rocket64[xyz].* 20.0` |
| **Effective hardware clock** | **10 MHz** | `board/dualv7/riscv-2025.1.tcl:737` (`CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {10.000}`) — 直接驱动 `RocketChip/clock`、`MEM_AXI4`、`IO_AXI4`、`DMA_AXI4`、`Ethernet`、`XADC`、`LEDGPIO`、`DDRSTAT` |
| **Software-visible timer** | **200 kHz** | OpenSBI: `aclint-mtimer @ 200000Hz`、Linux: `sched_clock: 64 bits at 200kHz`、`Calibrating delay loop ... 0.40 BogoMIPS (lpj=2000)` |

**关键事实**：当前 20 MHz 声明从未变成硬件实际时钟。SoC 主域实际运行在 10 MHz。

### 1.2 硬件时钟分配表

| 时钟/域 | 频率 | 来源 | 消费者 |
|---------|------|------|--------|
| `AXI_clock` | **10 MHz** | clk_wiz clk_out1 | RocketChip core、MEM/IO/DMA AXI、Ethernet(MAC侧)、XADC、LEDGPIO、DDRSTAT |
| `clock_100MHz` | 100 MHz | clk_wiz clk_out3 | UART、SD、io_axi_s/m aclk1 |
| `clock_200MHz` | 200 MHz | clk_wiz clk_out2 | MIG sys_clk_i/clk_ref_i |
| MIG UI clk | 100 MHz | MIG 内部 PLL | MIG AXI slave、axi_smc_1/aclk1 |
| DDR3 PHY IO | 400 MHz | MIG 内部 PLL | DDR3 (800 MT/s) |
| phy_tx/rx_clk | 25 MHz | KSZ8081 PHY | Ethernet MII 物理侧 |

### 1.3 clk_wiz 配置证据

来自 `board/dualv7/riscv-2025.1.tcl`（远端 202 直接确认）：

```
line 735: set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
line 737:   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {10.000}
line 738:   CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000}
line 740:   CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {100.000}
line 745:   CONFIG.MMCM_CLKIN1_PERIOD {10.000}    (100MHz 板载输入)
```

时钟连接（`board/dualv7/riscv-2025.1.tcl:774-793`）：
```
clk_out1 → RocketChip/clock, DDR/axi_clock, IO/axi_clock  (= AXI_clock)
clk_out2 → DDR/clock_200MHz, IO/clock_200MHz              (= clock_200MHz)
clk_out3 → IO/clock_100MHz                                 (= clock_100MHz)
```

### 1.4 "20 MHz 声明 vs 10 MHz 实际" 的根本原因

**vivado.tcl 第 94-95 行对 dualv7 有显式排除**：

```tcl
if { $vivado_board_name ne "dualv7" } {
    set_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $riscv_clock_frequency \
        [get_bd_cells clk_wiz_0]
}
```

这意味着：
1. `system-dualv7.tcl` 设置的 `riscv_clock_frequency = 20.0` 不会覆盖 `clk_wiz_0`
2. `board/rocket-freq` 返回的任何频率值（当前匹配 `.* Rocket64[xyz].* 20.0`）也不会生效
3. 最终 `clk_out1` 频率完全由板级 TCL (`riscv-2025.1.tcl`) 硬编码的 `10.000 MHz` 决定

**历史原因**：026x 时期为 MIG DDR3 PHY timing 收敛临时降频到 10 MHz。后续未改回。

### 1.5 运行时频率证据

来自 066x/068x 已验证的启动日志：

```
OpenSBI:
  Platform Timer Device : aclint-mtimer @ 200000Hz
  Platform HART Count   : 2

Linux (066x):
  Kernel command line: earlycon console=ttyAU0,115200 root=/dev/nfs ...
  sched_clock: 64 bits at 200kHz, resolution 5000ns
  Calibrating delay loop (skipped), value calculated using timer
    frequency.. 0.40 BogoMIPS (lpj=2000)
  smp: Brought up 1 node, 2 CPUs
```

**能够证明**：SoC timer 频率为 200 kHz，2 核均正常启动。
**不能证明**：CPU 主频是多少（BogoMIPS 仅反映 timer 频率，不反映 CPU 时钟）。

---

## 2. Genesys2 时钟对照

### 2.1 Genesys2 时钟树

来源：028x/030x 调研 + `board/genesys2/riscv-2025.1.tcl`

| 时钟 | 频率 | 用途 |
|------|------|------|
| 板载晶振 | **200 MHz** (LVDS, AD12/AD11) | IBUFDS 差分输入 |
| clk_wiz clk_in1 | 200 MHz (5.000ns period) | MMCM 输入 |
| clk_out1 | **100 MHz** | CPU/AXI (`RocketChip/clock`, SmartConnects) |
| clk_out2 | 200 MHz | MIG sys_clk_i |
| clk_out3 | 100 MHz | 外设 (UART, SD) |
| clk_out4 | 125 MHz | RGMII Ethernet PHY |
| NUM_OUT_CLKS | **4** | — |
| MMCM VCO | 1000 MHz | CLKFBOUT_MULT_F=5 × 200MHz |

### 2.2 Genesys2 MIG 关键参数

| 参数 | Genesys2 | DualV7 (z2m) |
|------|----------|-------------|
| FPGA | `xc7k325t-ffg900/-2` | `xc7v2000t-flg1925/-1` |
| Speed Grade | **-2** | -1 |
| DDR 类型 | DDR3 Component | DDR3 Component |
| DataWidth | **32-bit** | 64-bit |
| AXI Data Width | **256-bit** | 64-bit |
| TimePeriod | **1250 ps** (800 MHz) | 2500 ps (400 MHz) |
| InputClkFreq | 200 MHz | 200 MHz |
| PHYRatio | 4:1 | 4:1 |
| MemoryVoltage | 1.5V | 1.5V |
| VccAuxIO | **2.0V** | 1.8V |
| CAS Latency | 11 | (未确认) |
| DDR 速率 | **800 MT/s** | 400 MT/s |

### 2.3 CPU 配置对比

| 维度 | Genesys2 | DualV7 z2m |
|------|----------|------------|
| SoC 主频 | **100 MHz** | **10 MHz** |
| CPU 类型 | Rocket64b2 (1×Rocket) | **2×MegaBoom Z1** |
| 核数 | 1 | 2 |
| 宽总线 | 否 | 是 (256-bit MEM/IO/DMA) |
| Cache | 标准 | InclusiveCache |
| axi_smc 桥接 | 256→256 (直通) | 256→64 (降宽) |
| 外设数 | 4 | 6 |

### 2.4 Genesys2 与 DualV7 时钟差异总结

1. **板载晶振**：Genesys2 200 MHz vs DualV7 100 MHz — 这是根本差异
2. **MMCM VCO**：两者均为 1000 MHz，但输入不同导致分频比不同
3. **SoC 主频**：Genesys2 100 MHz vs DualV7 10 MHz — 差 10 倍
4. **DDR 速率**：Genesys2 800 MT/s vs DualV7 400 MT/s — 差 2 倍
5. **FPGA speed grade**：Genesys2 用 -2（更快），DualV7 用 -1
6. **架构复杂度**：DualV7 的 2×MegaBoom + 256-bit + InclusiveCache 显著增加时序压力
7. **额外时钟输出**：Genesys2 有 clk_out4 (125 MHz RGMII)，DualV7 只有 3 路输出

---

## 3. 当前 `rocket64z2m` 提频的真正阻塞

### 3.1 生成链阻塞

| 阻塞点 | 位置 | 说明 | 可修复性 |
|--------|------|------|----------|
| `vivado.tcl` dualv7 guard | `vivado.tcl:94-95` | `if { $vivado_board_name ne "dualv7" }` 直接跳过频率覆盖 | **可修**：移除 guard 或改为用 `system-*.tcl` 的值 |
| 板级 TCL 硬编码 | `board/dualv7/riscv-2025.1.tcl:737` | `CLKOUT1_REQUESTED_OUT_FREQ {10.000}` 不随 `riscv_clock_frequency` 变化 | **可修**：改为引用变量 |
| `board/rocket-freq` 无 dualv7 规则 | `board/rocket-freq` | dualv7 不在任何 board-specific 规则中，全走默认 `.* Rocket64[xyz].* 20.0` | **可修**：添加 dualv7 条目 |

**优先级**：这是第一个要解决的问题。不先修生成链，任何提频尝试都无意义。

### 3.2 时序阻塞（当前 066x/068x 数据）

当前 `rocket64z2m-r3.bit` 的实现后结果：

| 指标 | 值 | 含义 |
|------|-----|------|
| WNS | **-0.755 ns** | 最差负 slack（setup 违例） |
| TNS | **-2.854 ns** | 总负 slack |
| WHS | +0.041 ns | 保持时间勉强满足 |

**分析**：

- **当前 10 MHz 已有 setup 违例**（WNS=-0.755ns），这意味着即使在当前极低频率下，时序也没能完全收敛
- 10 MHz 时钟周期 = 100 ns，WNS=-0.755 ns 意味着关键路径延迟 ≈ 100.755 ns
- 若拉到 20 MHz（周期 50 ns），WNS ≈ 50 - 100.755 = **-50.755 ns**（必定失败）
- 违例路径大概率落在：
  - 2×MegaBoom 核间关键路径
  - 256-bit MEM/IO 宽总线布线
  - `axi_smc_1` 256→64 跨宽桥
  - InclusiveCache 长延迟路径

**结论**：时序是当前最硬的阻塞。提频必须先收敛时序。

### 3.3 架构阻塞

| 架构要素 | 对提频的影响 | 说明 |
|----------|-------------|------|
| **2×MegaBoom Z1** | 高 | 双核设计增加逻辑深度和布线压力，关键路径更长 |
| **256-bit MEM/IO/DMA** | 高 | 宽数据通路布线拥塞严重，V7 资源虽多但布线不一定能跟上 |
| **InclusiveCache** | 中 | L2 Cache 在关键路径上 |
| **axi_smc_1 256→64** | 中 | 跨宽桥转换逻辑增加延迟 |
| **6 个 IO 外设** | 低 | 外设挂在独立时钟域 (100 MHz)，对主频影响有限 |
| **MIG 64-bit DDR3** | 中 | DDR 接口本身在 200 MHz 参考时钟域，但 MIG AXI 接口在 100 MHz UI clk |

**与 Genesys2 对比**：Genesys2 使用 1×Rocket（非 MegaBoom）、无宽总线、标准 Cache、4 外设——架构复杂度低得多。即使 FPGA 速度等级更优（-2 vs -1），架构简单也是能跑 100 MHz 的重要原因。

### 3.4 板级阻塞

| 阻塞点 | 历史证据 | 当前状态 |
|--------|---------|---------|
| MIG DDR3 校准 | 026x 因 MIG PHY timing 降频到 10 MHz | 当前 400 MT/s 可工作，但提高 MIG 速率可能触发新问题 |
| MII RX timing | 历史 MII 时序问题（§04.1-§04.6） | 当前 25 MHz PHY 时钟下已验证可用 |
| DualV7 信号完整性 | 板级走线质量不如开发板 | 长走线、连接器等因素增加不确定性 |

### 3.5 阻塞优先级排序

按严重程度从高到低：

1. **时序 WNS=-0.755ns**：当前已有违例，提频前必须先收敛（最硬阻塞）
2. **生成链口径不一致**：必须先修，否则任何频率改动都不可追踪
3. **2×MegaBoom + 256-bit 架构**：天然提频上限低于简单单核
4. **FPGA speed grade -1**：Virtex-7 -1 速度等级本身不差，但搭配高复杂度架构时提频空间有限
5. **板级因素**：MIG 时序不确定性在提频时可能暴露新问题

---

## 4. 分阶段提频路线

### 阶段 0：口径清理（推荐立即执行）

**目标**：让生成链、硬件、文档、DTS 的频率口径一致。

**需要修改的文件**：

| 文件 | 改动 |
|------|------|
| `board/dualv7/riscv-2025.1.tcl` | 将 `CLKOUT1_REQUESTED_OUT_FREQ {10.000}` 改为引用 `$riscv_clock_frequency`，若 dualv7 仍需特殊值则显式注释原因 |
| `vivado.tcl:94-95` | 移除或修改 dualv7 guard；若保留则将注释改为明确说明为何排除 |
| `workspace/rocket64z2m/system-dualv7.tcl` | 将 `riscv_clock_frequency` 改为与实际硬件一致的值 |
| `board/rocket-freq` | 添加 `dualv7` 条目 |
| DTS 文件 | 确保 `clock-frequency` 与实际一致 |
| `doc/DualV7-当前SoC架构与频率说明.md` | 更新频率表格 |

**改动量**：≤ 10 行，不改 RTL，可本地 diff 验证。
**风险**：低。只改声明不改硬件。
**成功判据**：`system-*.tcl` 中的 `riscv_clock_frequency`、板级 TCL 的 `CLKOUT1_REQUESTED_OUT_FREQ`、DTS 的 `clock-frequency` 三者一致。

### 阶段 1：提频到 20 MHz（需要综合验证）

**目标**：将 SoC 主频从 10 MHz 提升到 20 MHz。

**为什么先选 20 MHz**：
1. `system-dualv7.tcl` 当前声明值就是 20.0，说明设计者认为 20 MHz 是合理目标
2. `board/rocket-freq` 对 `Rocket64z2m` 默认匹配 20 MHz
3. 20 MHz 是最小提频步长，风险可控

**需要修改的文件**：
- `board/dualv7/riscv-2025.1.tcl`：将 `CLKOUT1_REQUESTED_OUT_FREQ` 从 10.000 改为 20.000
- 或在阶段 0 修好生成链的前提下，直接修 `system-dualv7.tcl` 的 `riscv_clock_frequency`

**需要验证**：
1. `make verilog` 能否通过
2. `make vivado-project` 能否正常生成 Block Design
3. 综合后 WNS/TNS 是否恶化
4. 实现后 WNS/TNS 是否可接受
5. 若仍有违例：Open Synthesized Design / Implemented Design 分析关键路径

**预期风险**：
- 时序违例预计会显著恶化（当前 10 MHz 已有 WNS=-0.755ns）
- 可能需要多次迭代 P&R 策略才能收敛

**回退点**：恢复原 10.000 MHz 配置，时序已有基线可对比。

### 阶段 2：中间频点 30~40 MHz（视阶段 1 结果决定）

**目标**：尝试 30 MHz 或 40 MHz。

**判断依据**：
- 若阶段 1（20 MHz）时序能收敛，可尝试 30 MHz
- 若阶段 1 时序仍无法收敛（WNS 仍为负），**不建议继续提频**——说明 20 MHz 已接近当前架构在 DualV7 上的上限

**额外考量**：
- 40 MHz 对应 `board/rocket-freq` 的 `.* Rocket.*b[2-9].* 40.0` 规则
- 当前 DTS 中 `clock-frequency = <40000000>` 正好是 40 MHz（虽然之前是因为 rocket-freq 误匹配）——若硬提到 40 MHz，DTS 反而不需要改

**风险**：30-40 MHz 时，256-bit 宽总线和双核 MegaBoom 的布局布线拥塞可能成为硬上限。

### 阶段 3：更高频上限评估

**结论：不建议当前在 DualV7 + 2×MegaBoom Z1 上追求 >40 MHz。**

**理由**：
1. Genesys2 能跑 100 MHz 靠的是：单核 Rocket（非 MegaBoom）、-2 speed grade、无宽总线、板级信号质量好
2. DualV7 的 2×MegaBoom Z1 + 256-bit + InclusiveCache 组合天然有更高的逻辑深度和布线压力
3. 当前 10 MHz 已有 WNS=-0.755ns 违例，即使收敛后，提升到 20 MHz 已属挑战
4. 板级因素（走线、连接器、MIG 64-bit 宽接口）进一步限制提频空间
5. 如果确实需要更高主频，建议两条路径：
   - **路径 A（短期）**：换用更简单的 CPU 配置（如 Rocket64b2 单核），复用 Genesys2 的经验
   - **路径 B（长期）**：优化 MegaBoom 关键路径、考虑流水线级数调整、或换用 -2/-3 speed grade FPGA

**截止点**：40 MHz 为当前架构的合理目标上限。超过此值应视作新架构任务。

---

## 5. 推荐下一步

1. **立即执行阶段 0**（口径清理）：修 3 处 TCL + DTS，让频率声明一致
2. **执行阶段 1**（20 MHz）：改 `CLKOUT1_REQUESTED_OUT_FREQ` 为 20.000，综合看时序
3. **分析时序**：利用 Vivado 时序报告定位关键路径，判断是否可收敛
4. **若要继续提频**：先收敛 20 MHz 的时序，再评估 30 MHz 的可行性
5. **若 20 MHz 时序无法收敛**：考虑放弃提频或改为简化架构（如单核 Rocket64b2）

---

## 6. 证据源

| 证据 | 文件 |
|------|------|
| 生成链声明 | `workspace/rocket64z2m/system-dualv7.tcl:4` |
| 板级时钟硬编码 | `board/dualv7/riscv-2025.1.tcl:737-740, 774-793` |
| vivado.tcl guard | `vivado.tcl:94-95` |
| rocket-freq 规则 | `board/rocket-freq` |
| 硬件时钟树 | `code-agent/knowledge/06-bus-architecture.md §06.1.1` |
| OpenSBI 频率日志 | `workspace/066x/uart-netboot-z2m.log:66` |
| Linux BogoMIPS 日志 | `workspace/066x/uart-netboot-z2m.log:233` |
| Timing 数据 | `doc/DualV7-当前SoC架构与频率说明.md §6` |
| Genesys2 时钟树 | `code-agent/tasks/028x-genesys2-arch-analysis.md Part C` |
| Genesys2 MIG 配置 | `code-agent/tasks/030x-genesys2-ip-detail.md §2.2` |
| 当前 SoC 架构 | `doc/DualV7-当前SoC架构与频率说明.md` |
