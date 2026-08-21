#!/bin/bash
# =============================================================================
# run202.sh —— 201 编排 202 远程任务（nohup 后台启动，防网络中断）
#
# 用法: run202.sh <task> '<远程命令>'
#   例: run202.sh T010-sync 'XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic \
#              /tools/Xilinx/2025.1/Vivado/bin/vivado -mode batch \
#              -source synth/tcl/build_top.tcl \
#              -tclargs work/T010-sync rtl_out/core_mini_axi synth/rtl synth/xdc batch'
#
# 行为: ssh 202 → cd ~/fpga → mkdir work/<task> → nohup 后台执行 → 日志落
#       work/<task>/build.log → 立即返回（不等待）。
# 等待完成: run202_wait.sh <task>
# =============================================================================
set -e
TASK="$1"
shift
if [ -z "$TASK" ] || [ -z "$1" ]; then
    echo "用法: run202.sh <task> '<远程命令>'"
    exit 1
fi
CMD="$*"

echo "==> 安排任务 $TASK 到 202（nohup，不等待）"
echo "    命令: $CMD"
ssh -o BatchMode=yes gxt@192.168.200.202 \
    "mkdir -p ~/fpga/work/$TASK && cd ~/fpga && { nohup bash -c '$CMD' > ~/fpga/work/$TASK/build.log 2>&1 < /dev/null & } && echo \$! > ~/fpga/work/$TASK/pid && echo '==> 已启动 $TASK (PID '\$!')'"
echo "==> 完成安排。预计耗时请查 flow-guide.md；完成后用 run202_check.sh $TASK 查询状态"
