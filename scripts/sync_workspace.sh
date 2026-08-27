#!/bin/bash
# =============================================================================
# sync_workspace.sh —— workspace 双向同步（201 ↔ 202）
#
# 用法（201 上运行）:
#   bash sync_workspace.sh push <task-subtask>   # 201→202：working.sh + SV（输入）
#   bash sync_workspace.sh pull <task-subtask>   # 202→201：log/rpt/bit/dcp（输出 + 镜像）
#
# 同步原则:
#   - 201 = 维护/bazel/上板；202 = Vivado 综合/仿真（权威）
#   - push: 输入（脚本 + bazel SV）→ 202
#   - pull: 输出（working.log + rpt + bit/dcp）→ 201 镜像，供分析
#   - 排除 Vivado/xsim 中间件（.cache/.hw/.ip_user_files/.Xil/xpr/xsim.dir）
#     —— 中间件不入镜像（见 AGENTS.md 清理表）
# =============================================================================
HOST=gxt@192.168.200.202
EXCLUDE_MID=(
  --exclude '.cache'
  --exclude '.hw'
  --exclude '.ip_user_files'
  --exclude '.Xil'
  --exclude '*.xpr'
  --exclude '__pycache__'
  --exclude 'xsim.dir'
)

case "$1" in
  push)
    T="$2"; [ -z "$T" ] && { echo "用法: $0 push <task-subtask>"; exit 1; }
    echo "==> push 201→202: $T（working.sh + SV 输入）"
    rsync -av --delete "${EXCLUDE_MID[@]}" \
      --exclude 'working.log' --exclude '*.rpt' --exclude '*.bit' --exclude '*.bin' --exclude '*.dcp' \
      ~/fpga/workspace/$T/ $HOST:~/fpga/workspace/$T/
    ;;
  pull)
    T="$2"; [ -z "$T" ] && { echo "用法: $0 pull <task-subtask>"; exit 1; }
    echo "==> pull 202→201: $T（log + 报告 + bit 镜像）"
    mkdir -p ~/fpga/workspace/$T
    rsync -av "${EXCLUDE_MID[@]}" \
      $HOST:~/fpga/workspace/$T/ ~/fpga/workspace/$T/
    ;;
  *)
    echo "用法: bash sync_workspace.sh push|pull <task-subtask>"
    exit 1;;
esac
echo "==> 完成"
