# §06 总线架构与时钟树

## §06.1 当前 vivado-risc-v RocketChip 总线

### §06.1.1 时钟树

```
板载时钟芯片 (100MHz LVDS)
  │
  s2cclk_1_p (L4, DIFF_HSTL_II_18)
  s2cclk_1_n (L3, DIFF_HSTL_II_18)
  │
  ├─ create_clock -period 10 -name pclk1_p (XDC 约束, 100MHz)
  │
  ▼
util_ds_buf:2.2 (IBUFGDS → 单端)
  │  sys_diff_clock_buf/IBUF_OUT
  │
  ▼  sys_clock (100MHz)
clk_wiz:6.0 (MMCM/PLL, PRIMARY)
  │  CONFIG.MMCM_CLKIN1_PERIOD = 10.000  (100MHz)
  │  CONFIG.MMCM_CLKFBOUT_MULT_F = 10.0  (VCO = 1000MHz)
  │
  ├── clk_out1 = 100.000 MHz ──►  AXI_clock
  │     │                          ├── RocketChip/clock          (CPU + SBUS/MBUS/CBUS @100MHz)
  │     │                          ├── DDR/axi_clock             (MIG AXI slave @100MHz)
  │     │                          └── IO/axi_clock              (IO hier block)
  │     │                              ├── io_axi_s/aclk         (SmartConnect, IO_AXI4 → 外设)
  │     │                              └── io_axi_m/aclk         (SmartConnect, DMA_AXI4 ← 外设)
  │     │
  │     │  DTS: timebase-frequency = 400000 (0.4MHz), cpu clock-frequency = 40000000 (40MHz)
  │     │  ⚠ DTS 频率与硬件 100MHz 不一致（Rocket64b2 Scala config 未再生）
  │     │
  ├── clk_out2 = 200.000 MHz ──►  clock_200MHz
  │     │                          ├── DDR/mem_reset_control_0/clock
  │     │                          ├── IO/clock_200MHz
  │     │                          │   (未使用，仅透传到 IO hier block)
  │     │                          └── MIG sys_clk_i  = 200MHz
  │     │                              MIG clk_ref_i  = 200MHz
  │     │                              │
  │     │      MIG 内部 PLL (sys_clk_i → DDR PHY):
  │     │        TimePeriod = 2500ps → DDR3 IO clock = 400MHz (800 MT/s)
  │     │        PHYRatio   = 4:1    → UI Clock = 100MHz
  │     │        InputClkFreq = 200  → 参考时钟 200MHz
  │     │
  │     │      MIG ui_clk = 100MHz ──► axi_smc_1/aclk1
  │     │                                   (MIG AXI slave 接口 @100MHz)
  │     │
  │     │      MIG mmcm_locked → mem_reset_control_0/mmcm_locked
  │     │      MIG init_calib_complete → mem_reset_control_0/calib_complete
  │     │
  ├── clk_out3 = 100.000 MHz ──►  clock_100MHz
  │     │                          ├── UART/clock          (AXI4-Lite @100MHz)
  │     │                          ├── SD/clock             (AXI4-Lite @100MHz)
  │     │                          ├── io_axi_s/aclk1       (外设 SmartConnect @100MHz)
  │     │                          └── io_axi_m/aclk1       (DMA SmartConnect @100MHz)
  │     │
  │     │  ⚠ UART baud = 115200 @100MHz → hardware prescaler = 867 (hardcoded in RTL)
  │     │     实际波特率 = 100000000 / (867 + 1) = 115207 (误差 +0.006%)
  │     │
  └── locked ──►  clock_ok
                    ├── RocketChip/clock_ok
                    └── RocketChip/io_ok

  RocketChip/mem_ok ← clock_ok (临时 bypass, 非 MIG calib)
  ⚠ 实际应接 mem_reset_control_0/mem_ok (等待 init_calib_complete)
```

### §06.1.2 复位链

```
SW1 (AP31, active-low, LVCMOS18, PULLUP TRUE)
  │
  ├── XDC: create_clock → top level port "reset"
  │
  ▼
mem_reset_control (DDR hier block, custom module)
  │  inputs: sys_reset, clock_ok (clk_wiz locked), mmcm_locked (MIG),
  │          calib_complete (MIG init_calib_complete),
  │          ui_clk_sync_rst (MIG), clock (200MHz)
  │
  ├── mem_reset → MIG sys_rst (DDR3 PHY 复位)
  ├── aresetn   → MIG aresetn (AXI 复位)
  ├── ui_clk_sync_rst → MIG (MIG UI 时钟域复位)
  ├── mem_ok → RocketChip/mem_ok (DDR 就绪, 当前被 bypass = clock_ok)
  └── (控制 RocketChip memory reset sequence)

IO/IO_AXI4 域:
  axi_clock → io_axi_s/aclk, io_axi_m/aclk
  axi_reset → UART/async_resetn, SD/async_resetn, Ethernet/async_resetn,
              XADC/s_axi_aresetn, LEDGPIO/s_axi_aresetn, DDRSTAT/s_axi_aresetn,
              io_axi_m/aresetn, io_axi_s/aresetn

DDR 域:
  axi_clock → axi_smc_1/aclk
  axi_reset → axi_smc_1/aresetn

顶层:
  ethernet_stream_0/reset ← reset
  EthernetDualV7/reset     ← Ethernet/reset
```

### §06.1.3 时钟域汇总

| 时钟域 | 频率 | 来源 | 消费者 |
|--------|------|------|--------|
| `AXI_clock` | 100 MHz | clk_wiz clk_out1 | RocketChip core, DDR AXI, IO block |
| `clock_100MHz` | 100 MHz | clk_wiz clk_out3 | UART, SD, io_axi_s/m/aclk1 |
| `clock_200MHz` | 200 MHz | clk_wiz clk_out2 | MIG sys_clk_i/clk_ref_i, mem_reset_control |
| MIG UI clk | 100 MHz | MIG 内部 PLL | axi_smc_1, MIG AXI slave |
| MIG DDR3 clk | 400 MHz | MIG 内部 PLL | DDR3 PHY IO (800 MT/s) |

**注意**: `AXI_clock` 和 `clock_100MHz` 虽然同频 100MHz，但它们是 clk_wiz 的**不同输出**，在 Vivado 中视为**异步时钟域**。跨域访问（如 UART 寄存器 read）需经过 AXI SmartConnect 内部的跨时钟域逻辑。

### RocketChip 暴露的总线端口（VHDL 顶层）

```
RocketChip (rocket64b2):
  MEM_AXI4  → AXI4 Master  → DDR   → axi_smc_1 → MIG → DDR3 (0x00000000 ~ addr_range)
  IO_AXI4   → AXI4 Master  → IO/io_axi_s → UART/SD/ETH/XADC/LEDGPIO/DDRSTAT (0x60000000~)
  DMA_AXI4  ← AXI4 Slave   ← IO/io_axi_m ← SD/M_AXI + Ethernet/M_AXI (DMA 回写内存)
  clock_ok  ← clk_wiz locked
  mem_ok    ← clk_wiz locked (临时 bypass)
  io_ok     ← clk_wiz locked
```

三个 AXI4 端口均使用 `ASSOCIATED_BUSIF MEM_AXI4:DMA_AXI4:IO_AXI4`，共同时钟域。

### 地址映射

| 地址范围 | 设备 | 总线路径 |
|---------|------|---------|
| `0x00000000` ~ addr_range | DDR3 DRAM | RocketChip/MEM_AXI4 → DDR/axi_smc_1 → MIG |
| `0x60000000` | SD 控制器 | RocketChip/IO_AXI4 → IO/io_axi_s/M01_AXI |
| `0x60010000` | UART | RocketChip/IO_AXI4 → IO/io_axi_s/M00_AXI |
| `0x60020000` | Ethernet (Lite) | RocketChip/IO_AXI4 → IO/io_axi_s/M02_AXI |
| `0x60030000` | XADC | RocketChip/IO_AXI4 → IO/io_axi_s/M03_AXI |
| `0x60040000` | LED GPIO | RocketChip/IO_AXI4 → IO/io_axi_s/M04_AXI |
| `0x60050000` | DDR Status GPIO | RocketChip/IO_AXI4 → IO/io_axi_s/M05_AXI |

### 外设总线协议

- SD/UART/Ethernet: 自定义 RTL, AXI4-Lite Slave → `io_axi_s` (smartconnect)
- SD/Ethernet: 同时有 AXI4 Master → `io_axi_m` (smartconnect) → RocketChip/DMA_AXI4
- LEDGPIO/DDRSTAT: Xilinx AXI GPIO IP, AXI4-Lite Slave
- io_axi_s NUM_MI=6, io_axi_m NUM_MI=1 (从 Ethernet/SD 收集 DMA 请求)

### IO 层级结构（TCL create_hier_cell_IO）

```
IO (hier block):
  create_bd_intf_pin (Slave)  S00_AXI    → RocketChip/IO_AXI4
  create_bd_intf_pin (Master) M00_AXI    → RocketChip/DMA_AXI4
  create_bd_intf_pin (Master) uart       → rs232_uart 顶层端口
  # 内部:
  io_axi_s: SmartConnect → M00_UART, M01_SD, M02_ETH, M03_XADC, M04_LED, M05_DDRSTAT
  io_axi_m: SmartConnect ← S00_SD_DMA, S01_ETH_DMA
```

## §06.2 旧 Chipyard DualV7 总线

### §06.2.1 时钟树

```
板载时钟芯片 (100MHz LVDS)
  │
  s2cclk_1_p (L4)
  s2cclk_1_n (L3)
  │
  ▼
IBUFGDS (TestHarness Chisel BlackBox)
  │  sys_clk_in (100MHz 单端)
  │
  ▼
MMCME2_BASE (TestHarness Chisel BlackBox, Xilinx primitive)
  │  CLKIN1_PERIOD   = 10.0     (100MHz 输入)
  │  CLKFBOUT_MULT_F = 10.0     (VCO = 1000MHz)
  │  BANDWIDTH       = OPTIMIZED
  │  STARTUP_WAIT    = FALSE
  │
  ├── CLKOUT1_DIVIDE = 100  ──►  soc_clk = 10MHz
  │     │                          buildtopClock → ChipTop (全 SoC 时钟)
  │     │                          所有 TileLink 域 (SBUS/CBUS/MBUS): 10MHz
  │     │                          Core (RocketTile/SmallBoomTile): 10MHz
  │     │                          UART (SiFive TL-UART): 10MHz
  │     │                          SPI/SPIFlash/GPIO: 10MHz
  │     │
  │     │  Config: WithFPGAFrequency(10)
  │     │  DTSTimebase = 1e6 (1MHz)
  │     │  UART 115200 @ 10MHz → software div = 86
  │     │    实际波特率 = 10000000 / (86 + 1) = 114943 (误差 -0.223%)
  │     │    设为 div=85 则实际 = 116279 (误差 +0.94%)
  │     │
  │     │  ⚠ 10MHz 是极低主频（仅为 DDR3 验证保守值）
  │     │    Chipyard 可配置更高频率 (WithFPGAFrequency(50) → 50MHz 等)
  │     │
  ├── CLKOUT2_DIVIDE = 5    ──►  mig_sys_clk = 200MHz
  │     │                          → MIG BlackBox sys_clk_i / clk_ref_i
  │     │                          → 与 vivado-risc-v 相同的 DDR3 参考时钟
  │     │                          → MIG 内部 TimePeriod=2500ps, PHYRatio=4:1
  │     │                          → DDR3 400MHz / 800 MT/s
  │     │
  ├── CLKOUT3/4/5/6: 禁用 (DIVIDE=1, 未使用)
  │
  ├── CLKOUT0: 禁用
  │
  └── LOCKED ──►  soc_locked
                    └→ soc_reset_raw = !reset_sw1 || !soc_locked
                       → ResetCatchAndSync → dutReset (async reset)
```

### §06.2.2 复位链

```
SW1 (AP31, active-low, internal PULLUP)
  │
  ├── 取反: MMCM.RST = !reset_sw1 (active-high for MMCM)
  │
  ▼
soc_reset_raw = !reset_sw1 || !soc_locked
  │  (按键按下 或 PLL 未锁定 → reset asserted)
  │
  ▼
ResetCatchAndSync (soc_clk 同步)
  │  去除亚稳态，产生同步 async reset
  │
  ▼
dutReset (AsyncReset)
  ├── buildtopReset → ChipTop 全局复位
  ├── childReset    → 子模块复位
  └── ChipTop 内部自动分发到各 TileLink 域
```

### §06.2.3 时钟域汇总

| 时钟域 | 频率 | 来源 | 消费者 |
|--------|------|------|--------|
| `soc_clk` | 10 MHz | MMCM CLKOUT1 | ChipTop (CPU, SBUS, CBUS, MBUS, UART, SPI, GPIO) |
| `mig_sys_clk` | 200 MHz | MMCM CLKOUT2 | MIG 参考时钟 → DDR3 400MHz |
| DDR3 IO | 400 MHz | MIG 内部 PLL | DDR3 物理层 (800 MT/s) |

**关键差异 vs vivado-risc-v**:
- Chipyard SoC 全链路 10MHz 单一同步域（CPU + 外设 + 总线）
- vivado-risc-v 有 AXI_clock(100MHz) 和 clock_100MHz(100MHz) 两个异步域
- Chipyard 无独立外设时钟域（UART/SPI 与 CPU 同频）
- Chipyard UART 波特率由软件 div 控制，vivado-risc-v UART 由 RTL 硬编码

### 内部 SoC 总线（纯 TileLink）

```
ChipTop (SoC):
  Core (RocketTile / SmallBoomTile)
    │
    ▼
  SBUS (System Bus Xbar)
    ├── [addr[31]=0] → CBUS (Control Bus / Peripheral Bus)
    │   ├── BootROM     0x00010000
    │   ├── GPIO        0x10012000
    │   ├── UART        0x64000000 (SiFive TL-UART)
    │   ├── SPI (ctrl)  0x64001000
    │   └── SPIFlash    0x64004000
    │
    └── [addr[31]=1] → MBUS (Memory Bus)
        ├── L2 Cache (InclusiveCache, 可选)
        └── TL→AXI4 桥 → ExtMem → MIG → DDR3
```

### 关键设计特点

1. **纯 TileLink 内部互连**: Core→SBUS→CBUS/MBUS 全链 TileLink
2. **外设挂在 CBUS**: UART/SPI/GPIO 均为 TileLink-UL 设备
3. **DDR3 通过 TL→AXI4 桥接**: MBUS → `WithAXI4MemPunchthrough` → AXI4 → MIG
4. **引脚绑定在 FPGA Shell**: `WithDualV7UARTBinder` 直接把 SoC UARTPortIO 连到 TestHarness pad

### FPGA Shell（TestHarness）层

```
TestHarness:
  MMCM (100MHz → 10MHz) → soc_clk → buildtopClock → ChipTop
  ResetCatchAndSync → soc_clk → dutReset → ChipTop
  IBUFGDS → 差分时钟
  UART: uart_txd ← ChipTop UARTPortIO.txd, uart_rxd → UARTPortIO.rxd
  DDR: MIG BlackBox → AXI4 → TL→AXI4 Bridge → MBUS
  SPI: io_spi_* ← SPIPortIO → CBUS
```

**关键**: Chipyard TestHarness 不通过 Vivado BD IPI，而是 Chisel 直接生成所有互连逻辑（从 Verilog 顶层到 MIG BlackBox 再到 pad）。无 SmartConnect、无 xlconstant 手动接。

### 时钟

- `WithFPGAFrequency(10)`: 所有 SoC 时钟域 = 10MHz（CPU + SBUS + CBUS + MBUS）
- UART baud rate 由软件 div 寄存器控制（div=86 for 115200@10MHz）
- 不使用 Vivado BD 的时钟层次

### 地址空间

| 地址 | 设备 | 总线 | 协议 |
|------|------|------|------|
| `0x00010000` | BootROM | CBUS | TileLink |
| `0x10012000` | GPIO | CBUS | TileLink |
| `0x20000000` | SPI XIP | CBUS | TileLink |
| `0x64000000` | UART | CBUS | TileLink |
| `0x64001000` | SPI (ctrl) | CBUS | TileLink |
| `0x64004000` | SPIFlash | CBUS | TileLink |
| `0x80000000` | BackingScratchpad/DDR | MBUS | TileLink→AXI4 |

## §06.3 MEM/IO/DMA 分工对比

### vivado-risc-v 三总线模型

| 总线 | 方向 | 用途 | 连接 |
|------|------|------|------|
| `MEM_AXI4` | Master (core→DDR) | CPU 内存读写、指令/数据缓存 miss | RocketChip → axi_smc_1 → MIG → DDR3 |
| `IO_AXI4` | Master (core→外设) | CPU 访问外设寄存器 (MMIO) | RocketChip → io_axi_s → UART/SD/ETH/XADC/GPIO |
| `DMA_AXI4` | Slave (外设→core) | SD/Ethernet DMA 写回主存 | SD/Ethernet/M_AXI → io_axi_m → RocketChip |

### Chipyard 单一 TileLink 模型

| 路径 | 方向 | 协议 | 用途 |
|------|------|------|------|
| Core→SBUS→MBUS→TL→AXI4→MIG | L/S/IFetch | TileLink→AXI4 | 内存访问 |
| Core→SBUS→CBUS→UART/SPI/GPIO | MMIO | TileLink-UL | 外设访问 |
| DMA 路径 | 内建 TL bus | TileLink | 外设 DMA (若有) |

### RISC-V 核是否需要"专用总线"

**核心事实**:
1. RISC-V ISA 不规定总线协议。Rocket/BOOM 内部使用 **TileLink** 作为原生协议
2. RocketChip 框架通过 Diplomacy 参数化生成总线桥：可自动将 TileLink 转换为 AXI4 对外暴露
3. vivado-risc-v 的 RocketChip 已配置为生成 AXI4 端口（`MEM_AXI4`、`IO_AXI4`、`DMA_AXI4`）
4. 因此 vivado-risc-v 中的 RocketChip 内部仍是 TileLink，但对外暴露的是 AXI4

**结论**: RISC-V 核不需要"专用总线"即 AXI4 以外的总线。TileLink 是 RocketChip 内部互连协议，通过框架自动转换为 AXI4 或 AHB 等标准协议。vivado-risc-v 已正确配置为 AXI4 输出。

## §06.4 UART/MEM bring-up 影响

### UART 挂接位置

- vivado-risc-v: UART 挂在 `IO_AXI4` (via io_axi_s/M00_AXI)，地址 `0x60010000`
- **完全合理**: MMIO 外设应挂在 IO 总线，不挂在 MEM 总线
- BootROM 写 `0x60010000` 经 RocketChip IO_AXI4 → io_axi_s → UART，路径正确

### MEM test 路径

- BootROM 写 `0x80000000` → RocketChip MEM_AXI4 → axi_smc_1 → MIG → DDR3
- **完全合理**: DDR3 是 `MEM_AXI4` 的目标空间

### DDRSTAT 位置

- `0x60050000` 挂在 `IO_AXI4` (io_axi_s/M05_AXI)
- **合理**: DDRSTAT 是低速状态寄存器（4-bit GPIO input），应走 IO 总线
- 它不访问 DDR 数据，只是读 MIG 状态引脚的 GPIO 值

### 挂错总线风险分析

当前 vivado-risc-v 的 UART 挂 `IO_AXI4` **没有错误**:
- 021x/022x UART 无输出来自 CTS floating，与总线拓扑无关
- 如果 UART 错误挂在 `MEM_AXI4`，地址 `0x60010000` 会路由到 DDR 物理空间（低地址），造成冲突

### 移植 Chipyard UART 到 IO_AXI4

**不能直接挂**: Chipyard UART 是 TileLink-UL 接口，vivado-risc-v 的 `IO_AXI4` 是 AXI4 接口。
需要:
1. TileLink-to-AXI4-Lite 桥（sifive-blocks 有 `TLToAXI4` 可复用）
2. 或重写 UART RTL 为 AXI4-Lite Slave
3. 或复用 vivado-risc-v 现有 `uart.v` (最简单)

### 方案 A 继续修当前 UART 的总线结论

- `uart.v` 已是 AXI4-Lite Slave，挂 `io_axi_s/M00_AXI`
- 总线层面没有问题，不需要改动
- 只差 022x CTS 修复的 bit 重建

## §06.5 外设移植原则

| 移植目标 | 当前位置 | 协议 | 是否合理 | 备注 |
|---------|---------|------|---------|------|
| UART | IO_AXI4/M00 | AXI4-Lite | ✓ | CTS 修复后待验证 |
| SD | IO_AXI4/M01 | AXI4-Lite | ✓ | |
| ETH Lite | IO_AXI4/M02 | AXI4-Lite | ✓ | MII PHY |
| XADC | IO_AXI4/M03 | AXI4-Lite | ✓ | |
| LED GPIO | IO_AXI4/M04 | AXI4-Lite | ✓ | Xilinx IP |
| DDRSTAT | IO_AXI4/M05 | AXI4-Lite | ✓ | MIG 状态轮询 |
| DDR3 | MEM_AXI4 | AXI4-Full | ✓ | 64-bit 直连 |
| ETH DMA | io_axi_m → DMA_AXI4 | AXI4-Full | ✓ | eth 回写内存 |
| SD DMA | io_axi_m → DMA_AXI4 | AXI4-Full | ✓ | SD 回写内存 |

**原则**:
1. 纯 MMIO 低速外设（UART/GPIO/SPI/I2C）→ `IO_AXI4` (AXI4-Lite Slave)
2. 带 DMA 的外设（ETH/SD）→ MMIO 走 `IO_AXI4`，DMA 通路走 `DMA_AXI4`
3. 内存类设备（DDR3/SRAM）→ `MEM_AXI4`
4. 状态寄存器（如 DDRSTAT）→ `IO_AXI4`，不占 MEM 地址空间

## §06.7 MegaBoom Z1 (rocket64z1) 总线架构

### §06.7.1 CONFIG 差异

| 参数 | rocket64b2 (RocketBaseConfig) | rocket64z1 (RocketWideBusConfig) |
|------|------------------------------|----------------------------------|
| 核心 | `WithNBigCores(1)` | `WithNMegaBooms(1)` |
| 数据宽度 | `WithEdgeDataBits(64)` | **`WithEdgeDataBits(256)`** |
| 核数 | 1 | 1 |
| HART 数 | ~4 | **32** |
| LUT | 6.90% | 35.71% |
| WNS | +0.099ns | -9.83ns (MII 接收路径) |

### §06.7.2 总线拓扑

```
                    ┌─────────────────────────────────────┐
                    │         RocketChip (MegaBoom)        │
                    │                                      │
                    │  MegaBoom Core ×1 (32 HARTs)         │
                    │  L1 I/D Cache                        │
                    │  L2 InclusiveCache                    │
                    │  TileLink → AXI4 Bridges             │
                    │                                      │
                    │  MEM_AXI4      IO_AXI4      DMA_AXI4 │
                    │  (256-bit)    (256-bit)    (256-bit) │
                    └──┬──────────────┬──────────────┬─────┘
                       │              │              │
         ┌─────────────┼──────────────┼──────────────┼─────────┐
         │             ▼              ▼              ▼         │
         │   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐│
         │   │  DDR hier    │ │  IO hier     │ │  IO hier     ││
         │   │              │ │              │ │              ││
         │   │ S00_AXI      │ │ S00_AXI      │ │ M00_AXI      ││
         │   │  ┌─────────┐ │ │  ┌─────────┐ │ │  ┌─────────┐ ││
         │   │  │axi_smc_1│ │ │  │io_axi_s │ │ │  │io_axi_m │ ││
         │   │  │256→64b  │ │ │  │ NUM_MI=6│ │ │  │ NUM_MI=1│ ││
         │   │  └────┬────┘ │ │  └──┬──┬───┘ │ │  └────┬────┘ ││
         │   │       │      │ │     │  │     │ │       │      ││
         │   │  ┌────▼────┐ │ │  ┌──▼──▼───┐ │ │  ┌────▼────┐ ││
         │   │  │  MIG    │ │ │  │ UART    │ │ │  │RocketChip│ ││
         │   │  │ 64-bit  │ │ │  │(0x60010)│ │ │  │ DMA_AXI4 │ ││
         │   │  └────┬────┘ │ │  ├─────────┤ │ │  └─────────┘ ││
         │   │       │      │ │  │ SD ctrl │ │ │              ││
         │   │  ┌────▼────┐ │ │  │(0x60000)│ │ │              ││
         │   │  │  DDR3   │ │ │  ├─────────┤ │ │              ││
         │   │  │ SO-DIMM │ │ │  │ ETH MII │ │ │              ││
         │   │  │  1 GB   │ │ │  │(0x60020)│ │ │              ││
         │   │  └─────────┘ │ │  ├─────────┤ │ │              ││
         │   └──────────────┘ │  │ XADC    │ │ │              ││
         │                     │  │(0x60030)│ │ │              ││
         │                     │  ├─────────┤ │ │              ││
         │                     │  │ LEDGPIO │ │ │              ││
         │                     │  │(0x60040)│ │ │              ││
         │                     │  ├─────────┤ │ │              ││
         │                     │  │ DDRSTAT │ │ │              ││
         │                     │  │(0x60050)│ │ │              ││
         │                     │  └─────────┘ │ │              ││
         │                     └──────────────┘ └──────────────┘│
         └─────────────────────────────────────────────────────┘
```

### §06.7.3 与 rocket64b2 的关键区别

| 维度 | rocket64b2 | rocket64z1 |
|------|-----------|-----------|
| **MEM_AXI4 宽度** | 64-bit（直连 MIG） | 256-bit → axi_smc_1 转 64-bit → MIG |
| **IO_AXI4/DMA_AXI4 宽度** | 64-bit | 256-bit |
| **SmartConnect 作用** | 基本旁路 | **数据宽度转换**（256→64） |
| **L2 Cache** | 无（RocketBaseConfig） | 自带 InclusiveCache |
| **时序风险** | MEM 路径简单 | MEM 宽总线 + 跨宽桥可能增加布线压力 |

### §06.7.4 时钟树（同 §06.1.1，保持不变）

```
s2cclk_1 (100MHz LVDS, L4/L3)
  │
  ▼ IBUFGDS
sys_clock (100MHz)
  │
  ▼ clk_wiz (MMCM, VCO=1000MHz)
  ├── clk_out1 = 100MHz → AXI_clock → RocketChip + DDR AXI
  ├── clk_out2 = 200MHz → clock_200MHz → MIG sys_clk_i / clk_ref_i
  └── clk_out3 = 100MHz → clock_100MHz → IO/UART/SD/ETH
```

**时钟拓扑与 rocket64b2 完全相同**，TCL 共享同一 `board/dualv7/riscv-2025.1.tcl`。

### §06.7.5 当前 `rocket64z2m` 已验证 bit 的实际频率（2026-05-18 复核）

这条结论只对应当前 release：

- `dualv7-r3-z2m-busybox-netboot`
- bit：`rocket64z2m-r3.bit`

需要把两层口径分开：

1. **软件声明频率**
   - `workspace/rocket64z2m/system-dualv7.tcl` 中：
     `set riscv_clock_frequency 20.0`
2. **硬件实际时钟**
   - `board/dualv7/riscv-2025.1.tcl` 中 `clk_wiz_0` 固定：
     `CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {10.000}`
   - 同一文件把：
     `clk_wiz_0/clk_out1 -> RocketChip/clock`
   - `vivado.tcl` 对 `dualv7` 有特判，不会再用
     `riscv_clock_frequency` 覆盖 `clk_out1`

因此，当前 `rocket64z2m` release 的**硬件实际频率**是：

| 对象 | 频率 | 说明 |
|------|------|------|
| CPU core (`2 × MegaBoom Z1`) | `10 MHz` | `RocketChip/clock <- clk_out1` |
| `MEM_AXI4` / `IO_AXI4` / `DMA_AXI4` | `10 MHz` | RocketChip 主域 |
| `UART` | `100 MHz` | `UART/clock <- clock_100MHz` |
| `SD` | `100 MHz` | `SD/clock <- clock_100MHz` |
| Ethernet AXI/MMIO/MAC 逻辑侧 | `10 MHz` | `Ethernet/clock <- AXI_clock` |
| Ethernet MII PHY 侧 | `25 MHz` | `phy_tx_clk / phy_rx_clk` 来自 PHY |
| `XADC` / `LEDGPIO` / `DDRSTAT` AXI 接口 | `10 MHz` | `s_axi_aclk <- AXI_clock` |
| MIG `sys_clk_i` / `clk_ref_i` | `200 MHz` | DDR 参考时钟 |
| MIG UI AXI | `100 MHz` | MIG 内部 `ui_clk` |
| DDR3 PHY IO | `400 MHz` | `800 MT/s` |
| OpenSBI/Linux timer | `200 kHz` | 运行时日志：`aclint-mtimer @ 200000Hz` |

运行时证据：

- OpenSBI：`Platform Timer Device : aclint-mtimer @ 200000Hz`
- Linux：`Calibrating delay loop ... 0.40 BogoMIPS`

结论：

- 当前 `rocket64z2m` 的 **SoC 主域不是 100MHz，而是 10MHz**
- `clock_100MHz` 只覆盖 `UART/SD` 与部分 SmartConnect 外设侧
- 当前生成链仍存在“软件声明 20MHz / 硬件实际 10MHz”的频率口径不一致

### §06.7.6 频率口径分裂的根因（069x 调研确认）

三层频率口径拆解（§12.2.8）：

| 层次 | 值 | 来源 |
|------|-----|------|
| Declared frequency | 20.0 MHz | `system-dualv7.tcl:4` 和 `board/rocket-freq` 默认匹配 |
| Effective hardware clock | **10 MHz** | `board/dualv7/riscv-2025.1.tcl:737` |
| Software-visible timer | 200 kHz | OpenSBI + Linux BogoMIPS |

**根因**：`vivado.tcl:94-95` 对 dualv7 有显式 guard ——
`if { $vivado_board_name ne "dualv7" }` 跳过 `riscv_clock_frequency` 对 `clk_wiz_0` 的覆盖。
因此无论 `system-*.tcl` 或 `rocket-freq` 声明多少 MHz，最终 `clk_out1` 始终由
板级 TCL 硬编码的 `10.000 MHz` 决定。板级 TCL 也**未**引用 `$riscv_clock_frequency` 变量。

### §06.7.7 Genesys2 时钟对照

| 维度 | Genesys2 | DualV7 z2m |
|------|----------|------------|
| 板载晶振 | 200 MHz | 100 MHz |
| FPGA speed grade | -2 | -1 |
| SoC 主频 | 100 MHz | 10 MHz |
| CPU 类型 | Rocket64b2 (1核) | 2 x MegaBoom Z1 |
| 总线宽度 | 64-bit | 256-bit (MEM/IO/DMA) |
| NUM_OUT_CLKS | 4 (含 125MHz RGMII) | 3 |
| DDR 速率 | 800 MT/s | 400 MT/s |
| Timing 状态 | clean | WNS=-0.755ns (10MHz 违例) |

Genesys2 能跑 100 MHz 的原因：200MHz 板载晶振、-2 speed grade、
单核 Rocket 无宽总线、标准 Cache。

### §06.7.8 z2m 提频阻塞分析

按严重度排序：
1. 时序 WNS=-0.755ns（10 MHz 已有违例，提频必定恶化）
2. 生成链口径不一致（vivado.tcl guard + 板级 TCL 硬编码）
3. 2 x MegaBoom + 256-bit 宽总线 + InclusiveCache 架构复杂度
4. FPGA speed grade -1 限制
5. 板级 MIG/MII 时序历史问题

**提频上限评估**：不建议在 DualV7 + 2 x MegaBoom Z1 上追求 >40 MHz。

详见 `doc/DualV7-z2m频率提升调研报告.md`。
