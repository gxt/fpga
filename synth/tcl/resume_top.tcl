# =============================================================================
# resume_top.tcl —— T010 从 post_synth.dcp 续跑实现 + bitstream
# 用法（服务器）：与 build_top.tcl 相同参数，但跳过 synth_design
# =============================================================================
set work_dir    [lindex $argv 0]
set rtl_dir     [lindex $argv 1]
set top_rtl_dir [lindex $argv 2]
set xdc_dir     [lindex $argv 3]

if {$work_dir eq ""} { error "缺少 work_dir 参数" }

puts "==> T010 resume: open post_synth.dcp in $work_dir"
open_checkpoint $work_dir/post_synth.dcp

# ---- 实现 ----
opt_design
place_design
report_utilization    -file $work_dir/utilization_place.rpt
report_timing_summary -file $work_dir/timing_place.rpt
phys_opt_design
route_design
report_utilization    -file $work_dir/utilization_route.rpt
report_timing_summary -file $work_dir/timing_route.rpt
report_route_status   -file $work_dir/route_status.rpt
report_clock_utilization -file $work_dir/clock_utilization.rpt
report_drc            -file $work_dir/drc_route.rpt
write_checkpoint -force $work_dir/post_route.dcp

# ---- bitstream（.bit + .bin） ----
write_bitstream -force -bin_file $work_dir/top_coralnpu.bit

puts "==> T010 resume DONE"
puts "==> bitstream: $work_dir/top_coralnpu.bit / $work_dir/top_coralnpu.bin"
