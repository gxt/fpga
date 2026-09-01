# =============================================================================
# check_clock.tcl —— 验证 create_clock 覆盖 MMCM 输出是否被接受
# 用法: vivado -mode batch -source check_clock.tcl <work_dir>
# 预期: 输出时钟数/频率——确认 clk_mmcm_out 按 20MHz 生效
# =============================================================================
set work_dir [lindex $argv 0]
open_checkpoint $work_dir/post_synth.dcp
puts "==> 尝试 create_clock 覆盖（MMCME2_ADV）..."
create_clock -period 50.000 -name clk_mmcm_out [get_pins {g_mmcm/MMCME2_ADV/CLKOUT0}]
puts "==> 时钟列表（确认 clk_mmcm_out 频率）:"
foreach clk [get_clocks -quiet] {
    puts "    [get_property NAME $clk] period=[get_property PERIOD $clk]"
}
