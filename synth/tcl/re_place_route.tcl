# =============================================================================
# re_place_route.tcl —— 从 post_synth.dcp 重 place（ReduceCongestion）+ route
# 针对: T025 拥塞（place 密度是根因，AggressiveExplore route 无效 1410 信号）
# 用法:
#   vivado -mode batch -source re_place_route.tcl \
#       -tclargs <work_dir> <place_subdirective> <route_directive>
#   place_subdirective: Gplace.ReduceCongestion.low|med|high
#   route_directive: Default | Explore | AggressiveExplore
# 产出: post_route_rsc.dcp + utilization/timing rpt + top_coralnpu_rsc.bit
# 前置: post_synth.dcp（build_top 已生成）
# =============================================================================
set work_dir      [lindex $argv 0]
set place_subdir  [lindex $argv 1]
set route_directive [lindex $argv 2]
if {$place_subdir eq ""} { set place_subdir "Gplace.ReduceCongestion.med" }
if {$route_directive eq ""} { set route_directive "Default" }

puts "==> re-place+route: work=$work_dir place_subdir=$place_subdir route=$route_directive"
open_checkpoint $work_dir/post_synth.dcp
place_design -directive Explore -subdirective $place_subdir
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
close_project
