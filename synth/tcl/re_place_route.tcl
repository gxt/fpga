# =============================================================================
# re_place_route.tcl —— 从 post_synth.dcp 重 place + route
# 针对: T025 拥塞（place 密度根因；subdirective ReduceCongestion 不支持 7 系列）
# 用法:
#   vivado -mode batch -source re_place_route.tcl \
#       -tclargs <work_dir> <place_directive> <route_directive>
#   place_directive: Default | Explore | AggressiveExplore（7 系列可用集）
#   route_directive: Default | Explore | AggressiveExplore
# 产出: post_route_rsc.dcp + utilization/timing rpt + top_coralnpu_rsc.bit
# 前置: post_synth.dcp（build_top 已生成）
# =============================================================================
set work_dir        [lindex $argv 0]
set place_directive [lindex $argv 1]
set route_directive [lindex $argv 2]
if {$place_directive eq ""} { set place_directive "Explore" }
if {$route_directive eq ""} { set route_directive "Default" }

puts "==> re-place+route: work=$work_dir place=$place_directive route=$route_directive"
open_checkpoint $work_dir/post_synth.dcp
# --- 验证 open_checkpoint 后约束完整性（时钟/时序） ---
puts "==> 验证: 时钟数=[llength [get_clocks -quiet]] 顶层=[get_property TOP [current_design]]"
set wns_before [get_property SLACK [report_timing_summary -no_display -quiet] 2>/dev/null]
puts "==> 验证: 综合后 WNS=$wns_before"
if {$place_directive eq "Default"} {
    place_design
} else {
    place_design -directive $place_directive
}
phys_opt_design -hold_fix
if {$route_directive eq "Default"} {
    route_design
} else {
    route_design -directive $route_directive
}
write_checkpoint -force $work_dir/post_route_rsc.dcp
report_utilization    -file $work_dir/utilization_rsc.rpt
report_timing_summary -file $work_dir/timing_rsc.rpt
write_bitstream -force -bin_file $work_dir/top_coralnpu_rsc.bit
puts "==> re-place+route DONE: $work_dir/top_coralnpu_rsc.bit"
