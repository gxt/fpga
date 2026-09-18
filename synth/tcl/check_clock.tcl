# =============================================================================
# check_clock.tcl —— create_clock 覆盖 MMCM 输出（实例名 g_mmcm.u_mmcm）
# 用法: vivado -mode batch -source check_clock.tcl <work_dir>
# =============================================================================
set work_dir [lindex $argv 0]
open_checkpoint $work_dir/post_synth.dcp
puts "==> 修改前: clk_mmcm_out period=[get_property PERIOD [get_clocks clk_mmcm_out]]"
puts "==> 尝试 create_clock 覆盖 CLKOUT0..."
create_clock -period 50.000 -name clk_mmcm_out [get_pins {g_mmcm.u_mmcm/CLKOUT0}]
puts "==> 修改后全部时钟:"
foreach clk [get_clocks -quiet] {
    puts "    [get_property NAME $clk] period=[get_property PERIOD $clk]"
}
