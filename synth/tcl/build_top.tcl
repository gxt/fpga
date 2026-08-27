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
#   rtl_dir      远端 core_mini_axi SV 目录（如 ~/fpga/workspace/rtl_out/core_mini_axi/）
#   top_rtl_dir  本工程顶层/桥接 SV 目录（如 ~/fpga/synth/rtl/）
#   xdc_dir      引脚约束目录（如 ~/fpga/synth/xdc/）
#   mode         可选：proj（建 xpr 工程，默认）| batch（非工程，快速迭代）
# =============================================================================
set work_dir    [lindex $argv 0]
set rtl_dir     [lindex $argv 1]
set top_rtl_dir [lindex $argv 2]
set xdc_dir     [lindex $argv 3]
set mode        [lindex $argv 4]
set top         [lindex $argv 5]
set part        "xc7v2000tflg1925-1"
if {$top eq ""} { set top "top_coralnpu" }

if {$work_dir eq ""} { error "缺少 work_dir 参数" }
if {$rtl_dir eq ""} { error "缺少 rtl_dir 参数" }
if {$top_rtl_dir eq ""} { error "缺少 top_rtl_dir 参数" }
if {$xdc_dir eq ""} { error "缺少 xdc_dir 参数" }
if {$mode eq ""} { set mode "proj" }

file mkdir $work_dir
puts "==> T010 build: part=$part top=$top work=$work_dir mode=$mode"
puts "==> rtl_dir=$rtl_dir"
puts "==> top_rtl_dir=$top_rtl_dir"
puts "==> xdc_dir=$xdc_dir"

# ---- 读源（core_mini_axi 为 bazel 生成，不改动） ----
# ---- 读源（按 top 分支：top_coralnpu_soc 用裁剪 SoC，否则 M1/M2 的 CoreMiniAxi） ----
if {$top eq "top_coralnpu_soc"} {
    set src_files [list \
        $rtl_dir/CoralNPUChiselSubsystem_ITCM64KB_DTCM1024KB.sv \
        $top_rtl_dir/top_coralnpu_soc.sv \
        $top_rtl_dir/uart_rx.sv \
        $top_rtl_dir/uart_tx.sv \
        $top_rtl_dir/host_cmd_fsm.sv]
} else {
    set src_files [list \
        $rtl_dir/CoreMiniAxi.sv \
        $top_rtl_dir/top_coralnpu.sv \
        $top_rtl_dir/uart_rx.sv \
        $top_rtl_dir/uart_tx.sv \
        $top_rtl_dir/host_cmd_fsm.sv \
        $top_rtl_dir/axi_master_stub.sv]
}

if {$mode eq "proj"} {
    # 工程模式：建 .xpr 工程
    set proj_name [file tail [file normalize $work_dir]]
    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $src_files
    add_files -fileset constrs_1 -norecurse $xdc_dir/top_coralnpu.xdc
    set_property top $top [get_filesets sources_1]
    update_compile_order -fileset sources_1
    puts "==> 工程已创建: $work_dir/$proj_name.xpr"
} else {
    foreach f $src_files {
        read_verilog -sv $f
    }
    read_xdc $xdc_dir/top_coralnpu.xdc
}

# ---- 综合 ----
# RVV 宏与 chip_nexus.core 保持一致（VLEN_128/ZVE32F_ON/TB_SUPPORT 均为 default true）。
# RVVI_ON 不加（T017 教训：激活 rvviTrace 超综合限制；CoreTlul 无 RVVI 端口）。
# `define 不跨文件，须 synth_design 注入（T017 经验）。
if {$top eq "top_coralnpu_soc"} {
    synth_design -top $top -part $part -verilog_define {VLEN_128 ZVE32F_ON TB_SUPPORT}
} else {
    synth_design -top $top -part $part
}

# ---- 实现（中间阶段报告/checkpoint 默认不产出，需要时从 post_route.dcp 重生成） ----
opt_design
place_design
phys_opt_design -hold_fix
route_design
report_utilization    -file $work_dir/utilization_route.rpt
report_timing_summary -file $work_dir/timing_route.rpt
write_checkpoint -force $work_dir/post_route.dcp

# ---- bitstream（.bit + .bin） ----
write_bitstream -force -bin_file $work_dir/top_coralnpu.bit

puts "==> T010 build DONE"
puts "==> bitstream: $work_dir/top_coralnpu.bit / $work_dir/top_coralnpu.bin"
puts "==> reports: $work_dir"
if {$mode eq "proj"} { close_project }
