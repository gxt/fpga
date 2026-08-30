# =============================================================================
# re_route_opt.tcl —— 从 post_place.dcp 加 route 后 phys_opt（真实时序）+ route
# 针对: 8K/1M 时序 WNS -20.7ns（LSU slot 门控时钟 fo=63951 高扇出）
#       place 后 phys_opt 用估计时序（乐观 WNS +8.47）跳过优化——必须 route 后
#       phys_opt 用真实布线时序才会做 setup/hold 优化
# 用法:
#   vivado -mode batch -source re_route_opt.tcl \
#       -tclargs <work_dir> <route_directive>
#   route_directive: Default | Explore | AggressiveExplore
# 产出: post_route_opt.dcp + timing_opt.rpt + top_coralnpu_opt.bit
# 前置: post_place.dcp（8K/1M 轮）
# =============================================================================
set work_dir        [lindex $argv 0]
set route_directive [lindex $argv 1]
if {$route_directive eq ""} { set route_directive "Default" }

puts "==> re-route+phys_opt(route后): work=$work_dir route=$route_directive"
open_checkpoint $work_dir/post_place.dcp
puts "==> 验证: 时钟数=[llength [get_clocks -quiet]] 顶层=[get_property TOP [current_design]]"
phys_opt_design -hold_fix
if {$route_directive eq "Default"} {
    route_design
} else {
    route_design -directive $route_directive
}
# --- route 后 phys_opt：真实布线时序，修 setup + hold + 高扇出复制 ---
phys_opt_design
phys_opt_design -hold_fix
write_checkpoint -force $work_dir/post_route_opt.dcp
report_timing_summary -file $work_dir/timing_opt.rpt
write_bitstream -force -bin_file $work_dir/top_coralnpu_opt.bit
puts "==> re-route+phys_opt DONE: $work_dir/top_coralnpu_opt.bit"
