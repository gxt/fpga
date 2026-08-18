# =============================================================================
# top_coralnpu.xdc —— S2C Dual Virtex-7 TAI Logic Module F1 片引脚/时钟约束
# 目标器件：xc7v2000tflg1925-1
# 引脚来源：Dual V7 Hardware Reference Manual v1.08 Table 8-1（全局时钟）、
#           Table 8-7（SW1）、Table 8-9（RS232 J26）、Table 8-10（测试区 F1）
# 注意：OSC1 频率为假定值 100MHz（振荡器为用户安装件，实际频率待 T012 板上确认），
#       若实际不同，仅需改本文件 create_clock period 与 top_coralnpu.sv 的 MMCM 参数。
# =============================================================================

# -----------------------------------------------------------------------------
# 时钟：OSC1 —— W4(P)/W3(N)，默认 I/O 标准 LVDS（差分），MRCC 引脚
# 假定 100MHz（待确认）
# -----------------------------------------------------------------------------
create_clock -period 10.000 -name clk_osc -waveform {0 5.000} [get_ports {clk_p}]
set_property -dict {PACKAGE_PIN W4 IOSTANDARD LVDS} [get_ports {clk_p}]
set_property -dict {PACKAGE_PIN W3 IOSTANDARD LVDS} [get_ports {clk_n}]

# -----------------------------------------------------------------------------
# 复位按钮 SW1 —— AP31，1.8V；默认高，按下为低
# （板卡已有外部上拉，内部上拉仅为冗余保险）
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN AP31 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {rst_btn_n}]

# -----------------------------------------------------------------------------
# RS232 J26 —— F1.E20 = TX（FPGA→PC）、F1.F20 = RX（PC→FPGA），1.8V 逻辑
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN E20 IOSTANDARD LVCMOS18} [get_ports {uart_tx}]
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS18} [get_ports {uart_rx}]

# -----------------------------------------------------------------------------
# 测试区 LED（输出 H 点亮）—— F1_TEST7=LED40=K25、F1_TEST8=LED41=K28、
# F1_TEST9=LED42=J28，I/O 电压 1.5V
# -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN K25 IOSTANDARD LVCMOS15} [get_ports {led_halted}]
set_property -dict {PACKAGE_PIN K28 IOSTANDARD LVCMOS15} [get_ports {led_fault}]
set_property -dict {PACKAGE_PIN J28 IOSTANDARD LVCMOS15} [get_ports {led_locked}]
