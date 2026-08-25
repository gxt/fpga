#!/bin/bash
# =============================================================================
# t016_xsim_cont.sh —— T016 复现实验仿真（40MHz 连续写 TCM，机器202 执行）
# 用法: bash ~/fpga/scripts/t016_xsim_cont.sh   （在 202 上，cwd 由脚本 cd 控制）
# 编译 synth/rtl + rtl_out/core_mini_axi + synth/tb/T016-tb_uart_cont.sv → xsim
# =============================================================================
set -e
export PATH=/tools/Xilinx/2025.1/Vivado/bin:$PATH
export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic
cd ~/fpga/workspace/T016-xsim
rm -rf src && mkdir -p src
for f in ../../rtl_out/core_mini_axi/CoreMiniAxi.sv ../../synth/rtl/top_coralnpu.sv ../../synth/rtl/uart_rx.sv ../../synth/rtl/uart_tx.sv ../../synth/rtl/host_cmd_fsm.sv ../../synth/rtl/axi_master_stub.sv ../../synth/tb/T016-tb_uart_cont.sv; do
  base=$(basename "$f")
  { echo '`timescale 1ns/1ps'; cat "$f"; } > "src/$base"
done
GLBL=/tools/Xilinx/2025.1/Vivado/data/verilog/src/glbl.v
xvlog --sv --define XSIM "$GLBL" src/CoreMiniAxi.sv src/top_coralnpu.sv src/uart_rx.sv src/uart_tx.sv src/host_cmd_fsm.sv src/axi_master_stub.sv src/T016-tb_uart_cont.sv
xelab --debug typical -L unisim -L unisims_ver tb_uart_cont -s tb_uart_cont_sim
xsim tb_uart_cont_sim -R
