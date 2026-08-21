#!/bin/bash
# =============================================================================
# run202_wait.sh —— 阻塞等待 202 远程任务结束（单条命令，本地零轮询）
#
# 用法: run202_wait.sh <task> [pid_pattern]
#   默认 pid_pattern: [b]uild_top.tcl.*work/<task>（[b] 正则字符类排除 ssh 自身命令行）
#
# 行为: 远端 while pgrep; do sleep 15; done → 进程消失即返回 → 显示日志尾部
# =============================================================================
set -e
TASK="$1"
PAT="${2:-[b]uild_top.tcl.*work/$TASK}"
if [ -z "$TASK" ]; then
    echo "用法: run202_wait.sh <task> [pid_pattern]"
    exit 1
fi

echo "==> 等待 202 任务 $TASK 完成（远端阻塞，Ctrl-C 可中断查询）"
ssh -o BatchMode=yes gxt@192.168.200.202 \
    "while pgrep -f '$PAT' >/dev/null 2>&1; do sleep 15; done; echo '==> $TASK 结束'; grep -E '^ERROR|DONE|build_exit' ~/fpga/work/$TASK/build.log | tail -8"
