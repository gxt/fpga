# =============================================================================
# top_coralnpu.xdc —— S2C Dual Virtex-7 TAI Logic Module F1 片引脚/时钟约束
# 目标器件：xc7v2000tflg1925-1
# 引脚来源：Dual V7 Hardware Reference Manual v1.08 Table 8-1（全局时钟）、
#           Table 8-7（SW1）、Table 8-9（RS232 J26）、Table 8-10（测试区 F1）
# 注意：时钟源用 s2cclk_1（L4/L3，JG1/JG2，100MHz 差分）——2026-08-20 资料核实：
#       OSC1(W4/W3)=48MHz 已废弃（vivado-risc-v 实测），正确 100MHz 差分时钟为 L4/L3。
# =============================================================================

# -----------------------------------------------------------------------------
# 时钟：s2cclk_1 —— L4(P)/L3(N)，I/O 标准 LVDS（差分），JG1(P)/JG2(N) 连接器，100MHz
# （来源：DualV7 资料 V7-FPGA-HW-Description.md + S2C 手册 Table 8-1）
# -----------------------------------------------------------------------------
create_clock -period 10.000 -name clk_osc -waveform {0 5.000} [get_ports {clk_p}]
set_property -dict {PACKAGE_PIN L4 IOSTANDARD LVDS} [get_ports {clk_p}]
set_property -dict {PACKAGE_PIN L3 IOSTANDARD LVDS} [get_ports {clk_n}]

# T025: 约束比硬件严——MMCM 硬件 10MHz（DIVIDE 120），约束覆盖为 20MHz：
#   place 按 20MHz 时序驱动 → 布局紧凑（20MHz 布局 0 拥塞已验证）
#   硬件实际 10MHz → 路径 67ns < 100ns → 上板收敛
#   注意：综合后 MMCME2_BASE 优化为 MMCME2_ADV（pin 路径用 ADV）
create_clock -period 50.000 -name clk_mmcm_out [get_pins {g_mmcm/MMCME2_ADV/CLKOUT0}]

# -----------------------------------------------------------------------------
# 复位按钮 SW1 —— AP31，1.8V；默认高，按下为低
# （板卡已有外部上拉，内部上拉仅为冗余保险）
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN AP31 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {rst_btn_n}]

# -----------------------------------------------------------------------------
# FPGA 子板 UART —— 硬件工程师提供（2026-08-20）：uart_rxd=AV42、uart_txd=AU42，1.8V
#   uart_rx（FPGA 接收，PC→FPGA）= AV42；uart_tx（FPGA 发送，FPGA→PC）= AU42
#   （注：J26 RS232 F20/E20 非正确通路，改用子板 UART）
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN AU42 IOSTANDARD LVCMOS18} [get_ports {uart_tx}]
set_property -dict {PACKAGE_PIN AV42 IOSTANDARD LVCMOS18} [get_ports {uart_rx}]

# -----------------------------------------------------------------------------
# 测试区 LED（输出 H 点亮）—— F1_TEST7=LED40=K25、F1_TEST8=LED41=K28、
# F1_TEST9=LED42=J28，I/O 电压 1.5V
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN K25 IOSTANDARD LVCMOS15} [get_ports {led_halted}]
set_property -dict {PACKAGE_PIN K28 IOSTANDARD LVCMOS15} [get_ports {led_fault}]
set_property -dict {PACKAGE_PIN J28 IOSTANDARD LVCMOS15} [get_ports {led_locked}]

# -----------------------------------------------------------------------------
# GPIO LED（小板 J8-101/103/105）—— LED0=AH44、LED1=AH43、LED2=AL40，
# active-high，LVCMOS18（docs/DualV7 03-board-dualv7 §03.9 / Chipyard 管脚表）
# T020：L 命令控制
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN AH44 IOSTANDARD LVCMOS18} [get_ports {gpio_led[0]}]
set_property -dict {PACKAGE_PIN AH43 IOSTANDARD LVCMOS18} [get_ports {gpio_led[1]}]
set_property -dict {PACKAGE_PIN AL40 IOSTANDARD LVCMOS18} [get_ports {gpio_led[2]}]
