# 板卡信息

## 硬件配置

- **板卡型号**：S2C Dual Virtex-7 TAI Logic Module（TAI LM）
- **厂商**：S2C（思尔芯）
- **文档**：`docs/board/Dual V7 Hardware Reference Manual.pdf`（v1.08）

## 器件（来源：Hardware Reference Manual §4.1 Table 4-1）

| 项 | 值 |
| --- | --- |
| FPGA 器件 | XC7V2000TFLG1925 ×2（Virtex-7 2000T，双片共 40M ASIC gates） |
| 封装 | FLG1925 |
| 速度等级 | -1（用户提供；Vivado 2025.1 已验证 `xc7v2000tflg1925-1` 有效。封装全部可用等级：-1/-2/-2G/-2L） |
| 参考时钟 | 14 全局时钟：2×OSC 插座 + 6 对可编程差分 + 6 对 SMB 差分 + 6 对反馈差分。**关键（2026-08-20 实测/资料核实）**：**100MHz 差分 = L4(P)/L3(N)**（JG1/JG2 · s2cclk_1，XDC `create_clock -period 10.000`）；**OSC1 = W4(P)/W3(N)（LVDS 晶振座）实为 48MHz，vivado-risc-v 实测已废弃**（DualV7 资料 `V7-FPGA-HW-Description.md`） |
| UART | **FPGA 子板 UART（硬件工程师 2026-08-20）**：`uart_rxd=AV42`、`uart_txd=AU42`，**1.8V**（对应 J8-46/48 → CH341 `/dev/ttyUSB2`，DualV7 实测）。~~J26 RS232（TX=E20/RX=F20）~~ **非正确通路，改用子板 UART** |
| JTAG | J24，标准 Xilinx 14-pin（VREF/TMS/TCK/TDO/TDI，2×7 GND），Xilinx Download cable |
| 配置方式 | JTAG / USB（TAI Player）/ SD card / Ethernet；由 Spartan-6 控制器管理电源、时钟与配置 |
| 状态指示 | LED1（F1_DONE）、LED11（F2_DONE） |
| 内存 | DDR3 SO-DIMM、DDR2 SO-DIMM 各一 |
| 高速串行 | 32× Gigabit Transceiver（每 FPGA 16，≤6Gbps，可跑 PCIe/SATA/XAUI） |
| I/O | 720 Dedicated（每 FPGA 360，1.2~1.8V）+ 480 Shared（1.8V）+ 50 Inter-FPGA（1.8V，推荐 LVDS） |
| 供电 | 12V@16A / 5V@16A 开关电源 |

## 待确认

- 无（器件 part 已确定：`xc7v2000tflg1925-1`）
- 若日后在芯片丝印上发现实际速度等级不同（如 -2），以丝印为准更新此表

## 来源

- S2C Dual Virtex-7 TAI Logic Module Hardware Reference Manual v1.08（`docs/board/Dual V7 Hardware Reference Manual.pdf`）
- 板卡型号由用户提供：S2C Dual Virtex-7 TAI Logic Module (TAI LM)
