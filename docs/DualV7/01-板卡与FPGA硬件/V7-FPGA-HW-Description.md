# V7 FPGA 硬件描述文档

> 维护者：Claude
> 最后更新：2026-03-16
> 用途：FPGA 外设接口 review 参考，供 Scala/Verilog/XDC 集成时核查引脚、地址、时序

---

## 1. FPGA 芯片

| 参数 | 值 |
|------|-----|
| 型号 | Xilinx Virtex-7 XC7V2000T |
| Package | FLG1925 |
| Speed Grade | -1L |
| ISE/Vivado 格式 | `xc7v2000t-flg1925/-1` |
| 平台 | S2C DualV7 J9 原型验证板 |

---

## 2. 时钟

### 2.1 主差分时钟（s2cclk_1）

| 参数 | 值 |
|------|-----|
| 频率 | 100 MHz |
| 标准 | LVDS |
| FPGA 正端引脚 | L4 |
| FPGA 负端引脚 | L3 |
| XDC 约束 | `create_clock -period 10.000 [get_ports s2cclk_1_p]` |

> **注意**：早期错误配置曾使用 W4/W3 (OSC1, 48MHz)，已废弃。L4/L3 是正确的 100MHz 差分时钟。

### 2.2 MMCM 输出（SmallBoomDDRRomConfig）

| 输出 | 频率 | 用途 |
|------|------|------|
| CLKOUT0 | 10 MHz | SoC 主时钟（CPU、外设、UART） |
| CLKOUT1 | 200 MHz | MIG 参考时钟 (ref_clk) / sys_clk |
| CLKOUT2（如需） | 50 MHz | 备用（以太网 RMII REF_CLK，目前未用） |

> SoC 时钟 10 MHz：rdcycle 1 cycle = 100ns；UART 115200 分频寄存器 = 86

---

## 3. DDR3 内存

| 参数 | 值 |
|------|-----|
| 型号 | Samsung M471B5773（4GB SO-DIMM，参见 V7_FPGA_DDR3内存条.pdf） |
| 接口 | DDR3-800，16-bit bus |
| IP | Xilinx MIG 7-series v4.2 |
| SoC 基地址 | `0x80000000` |
| ui_clk | ≈100 MHz（DDR3-800，MIG 输出） |
| MIG TargetFPGA | `xc7v2000t-flg1925/-1`（ISE 格式，必须精确匹配） |
| SoC↔MIG 时钟域 | AsynchronousCrossing(8)（10MHz SoC ↔ 100MHz ui_clk） |
| init_calib_complete | 连接至 GPIO[3]（pin 10012000 bit3），用于固件等待 DDR3 就绪 |

### 3.1 时序违例说明

| 路径 | 违例值 | 影响 |
|------|--------|------|
| Setup (WNS) | +0.068 ns | margin 偏小，功能正常 |
| Hold (WHS) | -0.054 ns | 异步跨时钟域小违例，功能正常（已验证） |

---

## 4. SPI Flash

| 参数 | 值 |
|------|-----|
| 型号 | Winbond W25Q32FV（参见 w25q32fv_3v3.pdf） |
| 容量 | 4 MB |
| 电压 | 1.8V |
| 接口 | SPI（XIP 模式，CPU 复位向量 0x20000000） |
| SPI 控制器基地址 | `0x64004000` |
| sckdiv 典型值 | 3（f_spi = soc_clk / 2(sckdiv+1) = 10MHz/8 = 1.25MHz） |
| Flash 镜像大小 | 4MB（内容在 offset 0，其余填 0xFF） |

> **XIP 执行速度**：每条指令取指约 72 SPI CLK = 576 SoC cycles（10MHz 下约 57μs/指令）。rdcycle CSR 计时精确，不受 XIP 取指延迟影响。

---

## 5. UART

| 参数 | 值 |
|------|-----|
| 控制器 | SiFive UART v1 |
| 基地址 | `0x64000000` |
| TX 引脚 | AU42 |
| RX 引脚 | AV42 |
| 配置 | 115200 8N1 |
| 分频寄存器 | 86（115200 baud @ 10MHz SoC 时钟） |

寄存器映射：

| 偏移 | 寄存器 | 描述 |
|------|--------|------|
| +0x00 | UART_TXDATA | bit[7:0]=数据，bit31=满标志 |
| +0x04 | UART_RXDATA | bit[7:0]=数据，bit31=空标志 |
| +0x08 | UART_TXCTRL | bit0=txen |
| +0x18 | UART_DIV | 分频值 |

---

## 6. GPIO / LED

| 参数 | 值 |
|------|-----|
| 控制器 | SiFive GPIO |
| 基地址 | `0x10012000` |

寄存器（常用）：

| 偏移 | 寄存器 |
|------|--------|
| +0x04 | GPIO_INPUT_VAL |
| +0x08 | GPIO_OUTPUT_EN |
| +0x0C | GPIO_OUTPUT_VAL |

引脚分配：

| GPIO 位 | 用途 | 方向 |
|---------|------|------|
| [0] | LED0 | Output |
| [1] | LED1 | Output |
| [2] | LED2 | Output |
| [3] | DDR3 init_calib_complete | Input（MIG → GPIO） |

> LED 全亮对应 GPIO_OUTPUT_VAL[2:0] = 0x7；LED0 单亮 = 0x1

---

## 7. 以太网 PHY（KSZ8081MNX — MII 接口）

### 7.1 芯片概述

| 参数 | 值 |
|------|-----|
| 型号 | Micrel KSZ8081MNX |
| 接口 | MII（4-bit，10/100Base-TX） |
| Package | 32-pin QFN |
| PHY ID | OUI=0010A1h，Reg2h=0x0022，Reg3h=0x1560 |
| 数据手册 | KSZ8081MNX-RNB Data Sheet v1.0.pdf |

> 区分：KSZ8081**MNX** = MII（4-bit 数据），KSZ8081**RNB** = RMII（2-bit 数据）。本板使用 MNX（MII）。

### 7.2 MII 接口信号 — FPGA 引脚映射（J9 BIOS 插座）

#### 发送路径（MAC→PHY）

| 信号名 | 方向 | J9 管脚 | FPGA 引脚 | 描述 |
|--------|------|---------|-----------|------|
| MACTXEN | MAC→PHY | 62 | AU27 | 发送使能（TXEN） |
| MACTXD0 | MAC→PHY | 74 | BA25 | 发送数据位0 |
| MACTXD1 | MAC→PHY | 76 | AY25 | 发送数据位1 |
| MACTXD2 | MAC→PHY | 78 | BB27 | 发送数据位2 |
| MACTXD3 | MAC→PHY | 80 | BB26 | 发送数据位3 |
| MACTXCLKI | PHY→MAC | 100 | AR26 | TXC：PHY 提供发送时钟（100Mbps=25MHz，10Mbps=2.5MHz） |

#### 接收路径（PHY→MAC）

| 信号名 | 方向 | J9 管脚 | FPGA 引脚 | 描述 |
|--------|------|---------|-----------|------|
| MACRXDV | PHY→MAC | 82 | AU25 | 接收数据有效（RXDV） |
| MACRXD0 | PHY→MAC | 77 | AT25 | 接收数据位0 |
| MACRXD1 | PHY→MAC | 79 | AR25 | 接收数据位1 |
| MACRXD2 | PHY→MAC | 81 | AY27 | 接收数据位2 |
| MACRXD3 | PHY→MAC | 83 | AY26 | 接收数据位3 |
| MACRXCLKI | PHY→MAC | 63 | AT23 | RXC：PHY 提供接收时钟（与TXC同频） |
| MACRXER | PHY→MAC | 66 | BC28 | 接收错误（RXER） |
| MACCRS | PHY→MAC | 72 | BA24 | 载波侦听（CRS） |
| MACCOL | PHY→MAC | 70 | BB25 | 冲突检测（COL，半双工） |

#### 管理接口（MDIO/MDC）

| 信号名 | 方向 | J9 管脚 | FPGA 引脚 | 描述 |
|--------|------|---------|-----------|------|
| MACMDIO | 双向 | 71 | AP23 | 管理数据（需板上 1kΩ 上拉至 VDDIO） |
| MACMDC | MAC→PHY | 73 | AL23 | 管理时钟（max 2.5MHz，typ 400ns period） |

#### PHY LED 输出

| 信号名 | J9 管脚 | FPGA 引脚 | 描述 |
|--------|---------|-----------|------|
| FLED1 | 61 | AT24 | PHY LED1（速度/活动指示） |
| FLED2 | 67 | AJ23 | PHY LED2 |
| FLED3 | 65 | AJ24 | PHY LED3 |

### 7.3 KSZ8081MNX 配置 Strap

| Strap 引脚 | 功能 | 默认值/本板配置 |
|-----------|------|----------------|
| CONFIG[2:0] | 接口模式 | 000 = MII（默认） |
| PHYAD[2:0] | PHY 地址 | **001 = 地址1**（原理图 Sheet 13 实测） |
| B-CAST_OFF | 关闭广播 | 0（默认，允许广播） |
| LED1/SPEED | 速度指示 | 4.7kΩ 上拉 = 1 |
| LED0/NWAYEN | Auto-Neg 使能 | float = 1（使能） |

### 7.4 KSZ8081MNX 时序参数（MII，100Base-TX）

| 参数 | 描述 | Min | Typ | Max | 单位 |
|------|------|-----|-----|-----|------|
| t_P | TXC/RXC 周期 | — | 40 | — | ns |
| t_SU1 | TXD[3:0] setup to TXC↑ | 10 | — | — | ns |
| t_HD1 | TXD[3:0] hold from TXC↑ | 0 | — | — | ns |
| t_OD | (RXDV, RXD[3:0]) output delay from RXC↑ | — | 25 | — | ns |
| t_RLAT | CRS to RXDV latency | — | 170 | — | ns |
| MDC period | — | — | 400 | — | ns |
| MDIO setup | to MDC↑ | 10 | — | — | ns |
| MDIO hold | from MDC↑ | 4 | — | — | ns |

### 7.5 PHY 复位时序

- RST# 低电平保持：最小 **500μs**（warm reset）
- 上电后 supply 稳定到 RST# 释放：最小 **10ms**
- RST# 释放后到可使用 MDC/MDIO：最小 **100μs**
- **实际电路（原理图 Sheet 13）**：FPGA BA18（ERST_N）→ R432（0Ω）→ ASYSRSTN → KSZ8081 RST#。直接驱动，无 RC、无二极管。FPGA 输出 HIGH → PHY 释放；FPGA 输出 LOW → PHY 复位。

### 7.6 PHY 电源

| 电源 | 电压 | 来源 | 备注 |
|------|------|------|------|
| VDDA_3.3 | 3.3V | 板供电 | 需铁氧体磁珠隔离 + 22μF + 0.1μF 去耦 |
| VDD_1.2 | 1.2V | 芯片内部 LDO | 由 VDDA_3.3 生成 |
| VDDIO | **1.8V（本板）** | AVCC1V8_MAC（原理图 Sheet 13） | IO 电平：VIH≥1.26V（=0.7×1.8V），FPGA LVCMOS18 输出 ✓ |
| 工作电流 | 47 mA | @ 100Base-TX full-duplex | |

### 7.7 关键寄存器（MAC 驱动配置参考）

| 地址 | 名称 | 关键位 |
|------|------|--------|
| 0x00 | Basic Control | [15]=软复位，[12]=AN使能，[8]=全双工 |
| 0x01 | Basic Status | [2]=Link Status，[5]=AN Complete |
| 0x04 | AN Advertisement | [8]=100FD，[7]=100HD，[6]=10FD，[5]=10HD |
| 0x1B | Interrupt Control/Status | [8]=Link Up IRQ，[10]=Link Down IRQ |
| 0x1E | PHY Control 1 | [8]=Link Status（实时），[2:0]=Operation Mode |
| 0x1F | PHY Control 2 | [15]=HP_MDIX，[7]=RMII 50MHz select（RNB only） |

> MDIO PHY 地址：**1**（PHYAD[2:0]=001，原理图 Sheet 13 实测）

---

## 8. JTAG 调试

| 参数 | 值 |
|------|-----|
| 适配器 | Xilinx Platform Cable USB（USB ID 03fd:0008） |
| 调试工具 | `xsdb`（`/tools/Xilinx/2025.1/Vivado/bin/xsdb`） |
| hw_server | `/tools/Xilinx/2025.1/Vivado/bin/hw_server -d &`（端口 3121） |
| FPGA 远程重配置 | `xsdb fpga -file <bit>`（约 2 分钟） |
| RISC-V 调试 | xsdb 不暴露 RISC-V DM，需 OpenOCD + BSCANE2 tunnel（Phase 6） |

---

## 9. SoC 地址空间（SmallBoomDDRRomConfig / SmallBoomDDRFlashConfig）

| 外设 | 基地址 | 备注 |
|------|--------|------|
| DDR3 DRAM | `0x80000000` | 4GB（实际 SO-DIMM 容量） |
| SPI Flash XIP | `0x20000000` | CPU 复位向量（Flash 版） |
| UART | `0x64000000` | SiFive UART v1 |
| SPI 控制器 | `0x64004000` | SPI Flash 控制器 |
| GPIO | `0x10012000` | SiFive GPIO |
| BootROM | `0x10000` | CPU 复位向量（ROM 版） |

---

## 10. 待集成外设（Linux Boot 路线图）

| 外设 | 状态 | 说明 |
|------|------|------|
| 以太网 MAC（AXI Ethernet Lite） | 计划中 | TileLink→AXI bridge + PHY MII 接口 |
| 以太网 PHY（KSZ8081MNX） | 引脚已确认 | J9 插座 MII 信号，见第7节 |
| TFTP/网络引导 | 依赖以太网 | U-Boot `dualv7_defconfig` |
| USB（USB3318） | 文档存在，未集成 | USB3318 PHY，待评估 |

---

*文档基于：KSZ8081MNX-RNB Data Sheet v1.0、S2C-V7-J9-BIOS插座管脚对应表20201012.xlsx、Dual V7 Hardware Reference Manual.pdf（待读），以及项目历史 MANIFEST 记录。*
