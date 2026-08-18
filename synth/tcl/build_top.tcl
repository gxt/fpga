# =============================================================================
# build_top.tcl —— T010: core_mini_axi + AXI 桥接（top_coralnpu）上板 bitstream
#
# 用法（服务器，见 synth/README.md 与 .tao/knowledge/synth-server.md）：
#   export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic   # 关键！
#   export PATH=/tools/Xilinx/2025.1/Vivado/bin:$PATH
#   vivado -mode batch -source <this>/build_top.tcl \
#       -tclargs <work_dir> <rtl_dir> <top_rtl_dir> <xdc_dir> \
#       > <work_dir>/T010-impl.log 2>&1
#
# 参数：
#   work_dir     输出目录（报告/bitstream/dcp）
#   rtl_dir      远端 core_mini_axi SV 目录（如 ~/fpga/rtl_out/core_mini_axi/）
#   top_rtl_dir  本工程顶层/桥接 SV 目录（如 ~/fpga/synth/rtl/）
#   xdc_dir      引脚约束目录（如 ~/fpga/synth/xdc/）
# =============================================================================
set work_dir    [lindex $argv 0]
set rtl_dir     [lindex $argv 1]
set top_rtl_dir [lindex $argv 2]
set xdc_dir     [lindex $argv 3]
set part        "xc7v2000tflg1925-1"
set top         "top_coralnpu"

if {$work_dir eq ""} { error "缺少 work_dir 参数" }
if {$rtl_dir eq ""} { error "缺少 rtl_dir 参数" }
if {$top_rtl_dir eq ""} { error "缺少 top_rtl_dir 参数" }
if {$xdc_dir eq ""} { error "缺少 xdc_dir 参数" }

file mkdir $work_dir
puts "==> T010 build: part=$part top=$top work=$work_dir"
puts "==> rtl_dir=$rtl_dir"
puts "==> top_rtl_dir=$top_rtl_dir"
puts "==> xdc_dir=$xdc_dir"

# ---- 读源（core_mini_axi 为 bazel 生成，不改动） ----
read_verilog -sv $rtl_dir/CoreMiniAxi.sv
read_verilog -sv $top_rtl_dir/top_coralnpu.sv
read_verilog -sv $top_rtl_dir/uart_rx.sv
read_verilog -sv $top_rtl_dir/uart_tx.sv
read_verilog -sv $top_rtl_dir/host_cmd_fsm.sv
read_verilog -sv $top_rtl_dir/axi_master_stub.sv
read_xdc $xdc_dir/top_coralnpu.xdc

# ---- 综合 ----
synth_design -top $top -part $part

report_utilization    -file $work_dir/utilization_synth.rpt
report_timing_summary -file $work_dir/timing_synth.rpt
write_checkpoint -force $work_dir/post_synth.dcp

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

puts "==> T010 build DONE"
puts "==> bitstream: $work_dir/top_coralnpu.bit / $work_dir/top_coralnpu.bin"
puts "==> reports: $work_dir"
