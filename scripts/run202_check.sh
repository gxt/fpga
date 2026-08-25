#!/bin/bash
# =============================================================================
# run202_check.sh —— 非阻塞查询 202 远程任务状态（立即返回，不等待）
#
# 用法: run202_check.sh <task> [pid_pattern]
#   判定方式: 优先 PID 文件（run202.sh 启动时写入 workspace/<task>/pid，kill -0 判存活）；
#             无 pid 文件时用 pid_pattern 兜底（默认 [b]uild_top.tcl.*workspace/<task>）
#
# 输出: 状态（进行中/已完成）+ 进度线索（最近阶段/ERROR 数）+ 日志尾部
# =============================================================================
set -e
TASK="$1"
PAT="${2:-[b]uild_top.tcl.*workspace/$TASK}"
if [ -z "$TASK" ]; then
    echo "用法: run202_check.sh <task> [pid_pattern]"
    exit 1
fi

ssh -o BatchMode=yes gxt@192.168.200.202 "
PIDFILE=~/fpga/workspace/$TASK/pid
if [ -f \$PIDFILE ] && kill -0 \$(cat \$PIDFILE) 2>/dev/null; then
    echo '==> 状态: 进行中 (PID ' \$(cat \$PIDFILE) ')'
elif [ -f \$PIDFILE ]; then
    echo '==> 状态: 已完成'
elif pgrep -f '$PAT' >/dev/null 2>&1; then
    echo '==> 状态: 进行中 (pgrep)'
else
    echo '==> 状态: 已完成/未启动'
fi
LOG=~/fpga/workspace/$TASK/build.log
if [ -f \$LOG ]; then
    echo '--- 最近进度 ---'
    grep -E 'synth_design: Time|place_design: Time|route_design: Time|write_bitstream|T010 build DONE|ERROR:' \$LOG | tail -4
    echo \"--- ERROR 数: \$(grep -cE '^ERROR' \$LOG) ---\"
    tail -3 \$LOG
else
    echo '（无 build.log，任务可能未启动）'
fi"
