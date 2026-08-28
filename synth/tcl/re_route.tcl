# =============================================================================
# re_route.tcl —— 从 post_place.dcp 重新 route（省去 synth+place，只花 route 时间）
# 用法:
#   vivado -mode batch -source re_route.tcl \
#       -tclargs <work_dir> <directive>
#   directive: Explore / AggressiveExplore / ...（7 系列可用集）
# 产出: post_route_<directive>.dcp + timing_<directive>.rpt + top_coralnpu_<directive>.bit
# 前置: 需 build_top.tcl 已生成 post_place.dcp（route 失败也有）
# =============================================================================
set work_dir  [lindex $argv 0]
set directive [lindex $argv 1]
if {$directive eq ""} { set directive "Default" }

puts "==> re-route: work=$work_dir directive=$directive"
open_checkpoint $work_dir/post_place.dcp
if {$directive eq "Default"} {
    route_design
} else {
    route_design -directive $directive
}
write_checkpoint -force $work_dir/post_route_${directive}.dcp
report_timing_summary -file $work_dir/timing_${directive}.rpt
write_bitstream -force -bin_file $work_dir/top_coralnpu_${directive}.bit
puts "==> re-route DONE: $work_dir/top_coralnpu_${directive}.bit"
close_project
