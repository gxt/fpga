# =============================================================================
# wrapper_synth.tcl —— core_mini_axi_wrapper IP 封装综合验证
# 用法（机器202）：vivado -mode batch -source <this>.tcl \
#       -tclargs <work_dir> <rtl_dir> <top_rtl_dir>
#   work_dir   输出目录
#   rtl_dir    CoreMiniAxi.sv 目录（如 ~/fpga/rtl_out/core_mini_axi/）
#   top_rtl_dir wrapper 目录（如 ~/fpga/synth/rtl/）
# 验证：可综合 + FPGA 端口仅 aclk/aresetn
# =============================================================================
set work_dir    [lindex $argv 0]
set rtl_dir     [lindex $argv 1]
set top_rtl_dir [lindex $argv 2]
set part        "xc7v2000tflg1925-1"
set top         "core_mini_axi_wrapper"

if {$work_dir eq ""} { error "缺少 work_dir" }
file mkdir $work_dir
puts "==> wrapper synth: top=$top part=$part"

read_verilog -sv $rtl_dir/CoreMiniAxi.sv
read_verilog -sv $top_rtl_dir/core_mini_axi_wrapper.sv
synth_design -top $top -part $part

report_io -file $work_dir/io_report.txt
report_utilization -file $work_dir/utilization_synth.rpt
write_checkpoint -force $work_dir/post_synth.dcp

puts "==> wrapper synth DONE"
puts "==> IO 端口:"
