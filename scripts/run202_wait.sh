#!/bin/bash
# =============================================================================
# run202_wait.sh —— 阻塞等待 202 远程任务结束（单条命令，本地零轮询）
#
# 用法: run202_wait.sh <task> [pid_pattern]
#   判定方式: 优先 PID 文件（kill -0 判存活）；无 pid 文件用 pid_pattern 兜底
#   （默认 [b]uild_top.tcl.*workspace/<task>，[b] 正则字符类排除 ssh 自身）
#
# 行为: 远端 while kill -0; do sleep 15; done → 进程消失即返回 → 显示日志尾部
# =============================================================================
set -e
TASK="$1"
PAT="${2:-[b]uild_top.tcl.*workspace/$TASK}"
if [ -z "$TASK" ]; then
    echo "用法: run202_wait.sh <task> [pid_pattern]"
    exit 1
fi

echo "==> 等待 202 任务 $TASK 完成（远端阻塞，Ctrl-C 可中断查询）"
ssh -o BatchMode=yes gxt@192.168.200.202 \
    "PIDFILE=~/fpga/workspace/$TASK/pid; while { [ -f \$PIDFILE ] && kill -0 \$(cat \$PIDFILE) 2>/dev/null; } || { [ ! -f \$PIDFILE ] && pgrep -f '$PAT' >/dev/null 2>&1; }; do sleep 15; done; echo '==> $TASK 结束'; grep -E '^ERROR|DONE|build_exit' ~/fpga/workspace/$TASK/build.log | tail -8"
