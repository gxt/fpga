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
| 参考时钟 | 14 全局时钟：2×OSC 插座 + 6 对可编程差分 + 6 对 SMB 差分 + 6 对反馈差分 |
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
