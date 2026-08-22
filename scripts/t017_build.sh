#!/bin/bash
# =============================================================================
# t017_build.sh —— T017 RVV 核综合（202 执行，预处理 RvvCoreMiniAxi 加宏头）
# 解决 Vivado read_verilog 编译单元独立、`define 不跨文件/不生效问题：
#   生成 RvvCoreMiniAxi_def.sv（头部注入 `define VLEN_128/RVVI_ON/ZVE32F_ON）
# 用法: bash ~/fpga/scripts/t017_build.sh <task>
# =============================================================================
set -e
TASK="$1"
export PATH=/tools/Xilinx/2025.1/Vivado/bin:$PATH
export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic

cd ~/fpga
mkdir -p work/$TASK
# 预处理：文件头注入 RVV 宏（Vivado 编译单元内生效）
{
    echo '`define VLEN_128'
    echo '`define RVVI_ON'
    echo '`define ZVE32F_ON'
    cat rtl_out/rvv_core_mini_axi/RvvCoreMiniAxi.sv
} > work/$TASK/RvvCoreMiniAxi_def.sv
echo "==> RvvCoreMiniAxi_def.sv 生成（含 VLEN 宏）"

vivado -mode batch -source scripts/build_top.tcl \
    -tclargs work/$TASK work/$TASK synth/rtl synth/xdc proj RvvCoreMiniAxi_def.sv top_coralnpu_rvv
