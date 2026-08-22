#!/bin/bash
# =============================================================================
# t017_xsim.sh —— T017 RVV 核 xsim 仿真（加载 t007_rvv ELF，机器202 执行）
# 用法: bash ~/fpga/scripts/t017_xsim.sh
# 编译 rtl_out/rvv_core_mini_axi + synth/rtl + synth/sim/T017-tb_rvv_elf.sv
# 命令文件: work/T017-rvv-core/t007_rvv.wcmd（gen_wcmd.py 生成）
# =============================================================================
set -e
export PATH=/tools/Xilinx/2025.1/Vivado/bin:$PATH
export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic
cd ~/fpga/work/T017-rvv-core
rm -rf src && mkdir -p src
for f in ../../rtl_out/rvv_core_mini_axi/RvvCoreMiniAxi.sv ../../synth/rtl/top_coralnpu_rvv.sv ../../synth/rtl/uart_rx.sv ../../synth/rtl/uart_tx.sv ../../synth/rtl/host_cmd_fsm.sv ../../synth/rtl/axi_master_stub.sv ../../synth/sim/T017-tb_rvv_elf.sv; do
  base=$(basename "$f")
  { echo '`timescale 1ns/1ps'; cat "$f"; } > "src/$base"
done
GLBL=/tools/Xilinx/2025.1/Vivado/data/verilog/src/glbl.v
xvlog --sv --define XSIM --define VLEN_128 --define ZVE32F_ON --define "WCMD_FILE=\"/home/gxt/fpga/work/T017-rvv-core/t007_rvv.wcmd\"" "$GLBL" src/RvvCoreMiniAxi.sv src/top_coralnpu_rvv.sv src/uart_rx.sv src/uart_tx.sv src/host_cmd_fsm.sv src/axi_master_stub.sv src/T017-tb_rvv_elf.sv
xelab --debug typical -L unisim -L unisims_ver tb_rvv_elf -s tb_rvv_sim
xsim tb_rvv_sim -R
