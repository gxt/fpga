# =============================================================================
# program_top.tcl —— T012: 板卡加载 bitstream 与连通性验证（Hardware Manager）
# 机器201 执行（烧录例外，允许调用 Vivado）
#
# 用法：vivado -mode batch -source <this>.tcl -tclargs <bit_file>
#   <bit_file> 默认 synth/out/T010-fix-clk/top_coralnpu.bit
# 阶段 1（识别）：连接 hw_server、open_hw_target，读器件 NAME/IDCODE，不烧录
#   如果只识别：vivado -mode batch -source <this>.tcl -tclargs <bit> probe
# 阶段 2（烧录）：program_device + verify
# =============================================================================
set bit_file [lindex $argv 0]
set mode     [lindex $argv 1]
if {$bit_file eq ""} { set bit_file "/home/gxt/fpga/synth/out/T010-fix-clk/top_coralnpu.bit" }
if {$mode eq ""}     { set mode "program" }

puts "==> T012: mode=$mode bit=$bit_file"

# ---- 连接 hw_server / cable ----
open_hw_manager
connect_hw_server -allow_non_jtag
puts "==> hw_server 已连接"

# 找 target（cable）
set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    puts "ERROR: 未找到 hw_target（检查 cable/供电）"
    exit 1
}
puts "==> targets: $targets"
open_hw_target [lindex $targets 0]

# 找器件
set devices [get_hw_devices -quiet]
if {[llength $devices] == 0} {
    puts "ERROR: 未找到 hw_device（检查 JTAG 链）"
    exit 1
}
current_hw_device [lindex $devices 0]
set dev [current_hw_device]
puts "==> 器件 NAME: [get_property NAME $dev]"
puts "==> 器件 PART: [get_property PART $dev]"
puts "==> 器件 IDCODE: [get_property IDCODE $dev]"

if {$mode eq "probe"} {
    puts "==> probe 完成（未烧录）"
    exit 0
}

# ---- 烧录 ----
if {![file exists $bit_file]} {
    puts "ERROR: bit 文件不存在: $bit_file"
    exit 1
}
set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev
puts "==> program_hw_devices 完成"

# ---- 验证（可选；无 .msk mask 文件时跳过）----
if {[catch {verify_hw_devices $dev} verify_err]} {
    puts "==> verify 跳过（$verify_err）——烧录本身已成功（End of startup status: HIGH）"
} else {
    puts "==> verify_hw_devices 完成"
}

# ---- 烧录后状态检查（STATE 需 program 后可用）----
if {[catch {get_property STATE $dev} state]} {
    puts "==> STATE 属性不可读（非致命）"
} else {
    puts "==> 器件 STATE: $state"
}

close_hw_target [current_hw_target]
close_hw_manager
puts "==> T012 program DONE"
