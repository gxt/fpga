# Chipyard 1.13.0 x DualV7 RTL 接口差异报告

> 任务：045x
> 状态：实质成功（Verilog 已生成，045x 交付物未完全收口）
> 日期：2026-05-14

---

## 1. 验证进度总结

| 验证项 | 状态 | 说明 |
|--------|------|------|
| Bootstrap 环境 | ✓ 通过 | sbt launcher 1.7.1、riscv-gcc 9.2.0、Java 17 |
| Submodule 版本 | ✓ 通过 | BOOM @ `d2a64f7`、rocket-chip @ `72690b07c`，均正确 |
| 构建命令确认 | ✓ 通过 | `cd sims/verilator && make verilog CONFIG=SmallBoomV4Config` |
| Baseline config | ✓ 选定 | SmallBoomV4Config（单核 V4，目标 commit 是 V4 fix） |
| 缺失 submodule | ✓ 绕过 | cva6/ibex/ara/nvdla（创建 dummy .mk，非 BOOM 编译所需） |
| `make verilog` | ✓ 通过 | 已生成 `.fir`、`ChipTop.sv`、`DigitalTop.sv`、`TestHarness.sv` |
| `reports/045x` 交付物 | ✗ 未收口 | 仅保留了早期失败 `verilog.log`，缺 `top-module.txt` 等 4 个文件 |

**045x 当前应补的收口动作**：
1. 从真实生成结果提取 `top-module.txt / generated-path.txt /
   port-list.txt / filelist.txt`
2. 用新的构建日志替换当前 stale `verilog.log`
3. 后续集成一律基于真实 `ChipTop.sv`，不再停留在源码级预判

---

## 2. 实际生成层级与接口（基于 202 实际 RTL）

### 2.1 生成层级

```
TestHarness                          ← 仿真顶层（common.mk 的 MODEL）
  ├── ChipTop (system)               ← SoC 顶层（common.mk 的 TOP）
  │   ├── DigitalTop                 ← 内部系统
  │   │   ├── SmallBoomTile ×1       ← BOOM v4 核心
  │   │   ├── CBUS（控制总线）       ← UART/SPI/GPIO/BootROM 等
  │   │   ├── MBUS（内存总线）       ← L2 Cache → AXI4 Mem
  │   │   └── SBUS（系统总线）
  │   └── IO Ports（IOBinder 生成）  ← 对外物理端口
  └── HarnessBinders（仿真模型）     ← SimDRAM/UARTAdapter 等
```

### 2.2 ChipTop 顶层关键端口（基于实际 `ChipTop.sv`）

| 端口名称 | 方向 | 宽度 | 协议 | 来源 |
|----------|------|------|------|------|
| `axi4_mem_0_*` | Master | AXI4 | AX4-Full | 真实生成 RTL |
| `uart_0_txd/rxd` | Bidir | 2-bit | UART I/O | 真实生成 RTL |
| `jtag_TCK/TMS/TDI/TDO` | Bidir | JTAG | JTAG | 真实生成 RTL |
| `custom_boot` | Input | 1-bit | Boot mode | 真实生成 RTL |
| `reset_io` | Input | 1-bit | Reset | 真实生成 RTL |
| `clock_uncore` | Input | 1-bit | Clock | 真实生成 RTL |
| `clock_tap` | Output | 1-bit | Clock tap | 真实生成 RTL |
| `serial_tl_0_*` | Bidir | 32-bit | Serial TL | 真实生成 RTL |

**关键事实**：
- `WithNoMMIOPort` → **没有** AXI4 MMIO 端口（`IO_AXI4` 不存在）
- `WithNoSlavePort` → **没有** AXI4 Slave/DMA 端口（`DMA_AXI4` 不存在）
- 外设（UART 等）是**内部 TileLink 设备**，不是外部 AXI4 外设
- AXI4 内存端口是 `ClockedIO[AXI4Bundle]` 格式（自带 clock 信号）
- 045x 初版口径漏掉了 `custom_boot / reset_io / clock_uncore /
  clock_tap / serial_tl_0_*`

### 2.3 AXI4 内存端口信号结构

Chipyard 1.13.0 的 `WithAXI4MemPunchthrough` 生成如下 Verilog 端口：

```verilog
module ChipTop(
  // AXI4 Memory Port (ClockedIO wrapper)
  input         axi4_mem_0_clock,
  output [3:0]  axi4_mem_0_bits_aw_id,
  output [31:0] axi4_mem_0_bits_aw_addr,
  output [7:0]  axi4_mem_0_bits_aw_len,
  ...
  input         axi4_mem_0_bits_r_ready,
  // ...
);
```

**注意**：AXI4 端口自带独立 clock（ClockedIO），来自 MBUS 时钟域。在 Vivado 集成时需要注意跨时钟域处理。

---

## 3. 与当前 DualV7 vivado-risc-v Shell 的差异

### 3.1 当前 vivado-risc-v RocketChip 顶层端口

基于 `riscv_wrapper.v` / BD TCL（§06.1）：

| 端口 | 方向 | 用途 |
|------|------|------|
| `MEM_AXI4` | Master | DDR3 内存访问 |
| `IO_AXI4` | Master | 外设 MMIO（UART/SD/ETH/XADC/GPIO）|
| `DMA_AXI4` | Slave | 外设 DMA 回写主存 |
| `clock_ok` | Input | PLL 锁定信号 |
| `mem_ok` | Input | DDR 就绪信号 |
| `io_ok` | Input | IO 就绪信号 |

### 3.2 差异矩阵

| 接口 | Chipyard 1.13.0 (AbstractConfig) | vivado-risc-v | 差异 |
|------|----------------------------------|---------------|------|
| **内存端口** | 1× AXI4 Mem (ClockedIO) | 1× AXI4 MEM (标准) | 自带 clock 信号，需 adapter |
| **MMIO 端口** | **无**（WithNoMMIOPort） | 1× AXI4 IO | Chipyard 需新增 MMIO punchthrough |
| **DMA 端口** | **无**（WithNoSlavePort） | 1× AXI4 Slave | Chipyard 需新增 slave punchthrough |
| **clock_ok** | 无 | 输入 | Chipyard 需新增状态输入 |
| **mem_ok** | 无 | 输入 | Chipyard 需新增状态输入 |
| **UART** | 内部 TileLink（不暴露 AXI4） | 外部 AXI4-Lite | **根本架构差异** |
| **interrupt** | 端口拴死（WithTieOffInterrupts） | 无集中端口 | 需按需暴露 |

### 3.3 根本架构差异

```
vivado-risc-v:                    Chipyard 1.13.0:
┌──────────────┐                  ┌─────────────────┐
│  RocketChip  │                  │    ChipTop      │
│  CPU Core    │                  │  ┌────────────┐ │
│              │                  │  │DigitalTop  │ │
│ MEM  IO  DMA │                  │  │ CPU Core   │ │
│ AXI4 AXI4AXI4│                  │  │ UART (TL)  │ │
└──┬───┬───┬───┘                  │  │ SPI  (TL)  │ │
   │   │   │                      │  │ GPIO (TL)  │ │
   ▼   ▼   ▼                      │  └────────────┘ │
 Vivado BD ──► 外设 (UART/        │  MEM_AXI4 (only)│
 SD/ETH via AXI4-Lite)            └────────┬────────┘
                                           │
                                     Vivado BD
```

**简单说**：vivado-risc-v 把外设挂在 SoC 外部的 Vivado Block Design 里，
通过 AXI4 端口连接；Chipyard 把外设放在 SoC 内部（TileLink CBUS），
只暴露内存 AXI4 端口。

---

## 4. 集成路径分析

### 4.1 路线 A：保持 Chipyard 内建外设 + 单 AXI4 内存端口

**操作**：不改 Chipyard config，直接使用 AbstractConfig + SmallBoomV4Config 生成的 ChipTop。

**优点**：零 config 改动
**缺点**：
- DualV7 shell 的外设全部作废（UART/SD/ETH/XADC 等在自己这边重新设计）
- AXI4 内存端口自带独立 clock，需要 clock adapter
- 缺少 mem_ok/clock_ok 等状态信号

**适合**：最快验证 DDR3 基本通路

### 4.2 路线 B：新增 MMIO/DMA punchthrough

**操作**：
1. 修改 AbstractConfig 或创建 DualV7Config：
   - 替换 `WithNoMMIOPort` → `WithMMIOPort`（启用 MMIO AXI4 master）
   - 替换 `WithNoSlavePort` → `WithSlavePort`（启用 DMA AXI4 slave）
2. 保留内建外设（UART 等），但同时暴露 AXI4 MMIO 和 DMA 端口
3. Vivado side 把 UART/SD/ETH 等挂在外部 AXI4 bus 上

**优点**：端口形式与当前 vivado-risc-v 对齐
**缺点**：需要新建 Chipyard config
**关键问题**：MMIO port 的地址空间可能与内部 TileLink 外设冲突

### 4.3 路线 C：最小 FPGA config（推荐第一轮）

**操作**：
1. 创建一个 `DualV7BOOMConfig`：
```scala
class DualV7BOOMConfig extends Config(
  new boom.v4.common.WithNSmallBooms(1) ++
  new chipyard.config.AbstractConfig ++
  // Override: enable MMIO AXI4 port
  new freechips.rocketchip.subsystem.WithMMIOPort ++  // NOT WithNoMMIOPort
  // Override: keep only AXI4 mem punchthrough + clock
)
```
2. 第一轮只验证 DDR3 + UART 通路
3. 后续再逐步添加 DMA/ETH/SD 支持

**但需解决**：
- MMIO port 地址空间分配（当前 vivado-risc-v 用 `0x6000xxxx`）
- clock adapter（Chipyard 的 ClockedIO 格式）
- mem_ok/clock_ok 信号桥接

### 4.4 推荐第一阶段行动

**最小验证路径**：

```
Step 1: 创建 DualV7BOOMConfig
        - SmallBoomV4 + WithAXI4Mem + WithAXI4MMIO
        - 生成 ChipTop Verilog

Step 2: 创建 integration wrapper (Verilog)
        - 将 ChipTop 的 axi4_mem_0 接出标准 AXI4
        - 将 ChipTop 的 axi4_mmio_0 接出标准 AXI4  
        - 统一 clock/reset 接口
        - 添加 mem_ok/clock_ok stub

Step 3: Vivado Block Design 对接
        - 用 integration wrapper 替代当前 RocketChip
        - 复用现有 axi_smc / MIG / 外设
```

---

## 5. 下一轮应修改的内容

按优先级排序：

| 优先级 | 修改对象 | 内容 |
|--------|----------|------|
| **P0** | Chipyard config | 新建 `DualV7BOOMConfig`（AbstractConfig 基 + MMIO port） |
| **P1** | Integration wrapper | Verilog/VHDL adapter：ClockedIO→标准 AXI4 + Clock/Reset |
| **P2** | Vivado TCL | 修改 BD 顶层，用新 wrapper 替换原 RocketChip 实例 |
| **P3** | BootROM/DTS | 地址映射调整（MMIO 空间分配） |
| **P4** | 外设移植 | UART/SD/ETH 逐步验证 |

---

## 6. 附录

### 6.1 源码路径速查

| 文件 | 用途 |
|------|------|
| `generators/chipyard/src/main/scala/ChipTop.scala` | SoC 顶层定义 |
| `generators/chipyard/src/main/scala/config/BoomConfigs.scala` | BOOM config 类 |
| `generators/chipyard/src/main/scala/config/AbstractConfig.scala` | 基础 config |
| `generators/chipyard/src/main/scala/iobinders/IOBinders.scala` | AXI4 Port punchthrough |
| `generators/chipyard/src/main/scala/harness/TestHarness.scala` | 仿真 TestHarness |
| `generators/boom/src/main/scala/v4/common/config-mixins.scala` | BOOM v4 配置 mixin |
| `generators/rocket-chip/src/main/scala/subsystem/Configs.scala` | RocketChip 子系统 config |
| `variables.mk` | 构建变量定义 |

### 6.2 关键 Config 参数对照

| Chipyard 参数 | 当前设置 | vivado-risc-v 等效 |
|---------------|----------|---------------------|
| `WithNMemoryChannels(1)` | 1 通道 | MEM_AXI4 ×1 |
| `WithNoMMIOPort` | 无 MMIO | 需改为 WithMMIOPort |
| `WithNoSlavePort` | 无 Slave | 需改为 WithSlavePort |
| `WithUART` | 内部 UART | 外部 AXI4 UART |
| `WithBootROM` | 内部 BootROM | 独立 bootrom/ |

---

*报告结束。045x 之后的重点已不再是“能否生成 Verilog”，而是基于
真实 `ChipTop.sv` 继续做 wrapper / 最小 bit 集成。*
