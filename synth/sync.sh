#!/usr/bin/env bash
# =============================================================================
# T008: 机器202文件同步工作流
#
# 用法:
#   ./sync.sh info                    显示解析出的机器202信息
#   ./sync.sh push src                推送 coralnpu 源码到机器202（rsync 增量）
#   ./sync.sh push rtl <name>...      推送 bazel RTL 产物到机器202 rtl_out/
#                                     name: core_mini_axi | rvv_core_mini_axi
#   ./sync.sh push synth              推送 synth/ 脚本目录本身到机器202
#   ./sync.sh push all                等价: push src + push rtl core_mini_axi
#   ./sync.sh pull [<subdir>]         从机器202 work/ 拉回结果到机器201 synth/out/
#   ./sync.sh exec "<机器202命令>"        在机器202执行命令（BatchMode 免密）
#
# 机器202信息从 ../.tao/knowledge/registry.md 自动解析（主机地址只登记在 registry），
# 不写入本脚本；可用环境变量覆盖:
#   SYNTH_SERVER=user@host      # 默认从 registry.md 解析
#   SYNTH_REMOTE_ROOT=~/fpga    # 机器202工作根目录
#
# 约束: 不写密码/密钥；依赖 ssh 密钥免密（ssh -o BatchMode=yes）。
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT/.tao/knowledge/registry.md"

SERVER="${SYNTH_SERVER:-$(grep -o 'gxt@[0-9.]*' "$REGISTRY" | head -1)}"
REMOTE_ROOT="${SYNTH_REMOTE_ROOT:-~/fpga}"
VIVADO="${SYNTH_VIVADO:-$(grep -o '/tools/Xilinx/[0-9.]*/Vivado/bin/vivado' "$REGISTRY" | head -1)}"
[[ -n "$VIVADO" ]] || VIVADO="/tools/Xilinx/2025.1/Vivado/bin/vivado"

# RTL 产物映射表（源 = 机器201 bazel-out 固定路径；目标 = 机器202 rtl_out/<key>/）
# key 对应 //hdl/chisel/src/coralnpu:<key>_emit_verilog 的产物（见 coralnpu-build-map.md）
RTL_OUT_SRC="$ROOT/coralnpu/bazel-out/k8-fastbuild/bin/hdl/chisel/src/coralnpu"
declare -A RTL_FILES=(
  [core_mini_axi]="CoreMiniAxi.sv VCoreMiniAxi_parameters.h CoreMiniAxi.zip"
  [rvv_core_mini_axi]="RvvCoreMiniAxi.sv"
)

die() { echo "错误: $*" >&2; exit 1; }
say() { echo "==> $*"; }

usage() {
  grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

ssh_run() { ssh -o BatchMode=yes "$SERVER" "$@"; }

cmd_info() {
  [[ -n "$SERVER" ]] || die "无法从 $REGISTRY 解析机器202地址（可设 SYNTH_SERVER 覆盖）"
  say "机器202: $SERVER"
  say "机器202工作根: $REMOTE_ROOT"
  say "机器202 Vivado: $VIVADO"
  say "registry: $REGISTRY"
  ssh_run "hostname && $VIVADO -version | head -1"
}

cmd_push_src() {
  say "推送 coralnpu 源码 -> $SERVER:$REMOTE_ROOT/coralnpu/ (排除 .git/bazel-*)"
  rsync -a --delete --stats \
    -e "ssh -o BatchMode=yes" \
    --exclude='.git/' \
    --exclude='bazel-*' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    "$ROOT/coralnpu/" \
    "$SERVER:$REMOTE_ROOT/coralnpu/"
}

cmd_push_rtl() {
  local name
  for name in "$@"; do
    [[ -v RTL_FILES[$name] ]] || die "未知 RTL 产物 key: $name（可用: ${!RTL_FILES[*]}）"
    local src_files=(${RTL_FILES[$name]})
    for f in "${src_files[@]}"; do
      [[ -f "$RTL_OUT_SRC/$f" ]] \
        || die "机器201产物缺失: $RTL_OUT_SRC/$f（先执行 bazel build //hdl/chisel/src/coralnpu:${name}_emit_verilog）"
    done
    say "推送 RTL 产物 [$name] -> $SERVER:$REMOTE_ROOT/rtl_out/$name/"
    ssh_run "mkdir -p $REMOTE_ROOT/rtl_out/$name"
    rsync -a -e "ssh -o BatchMode=yes" \
      "${src_files[@]/#/$RTL_OUT_SRC/}" \
      "$SERVER:$REMOTE_ROOT/rtl_out/$name/"
  done
}

cmd_push_synth() {
  say "推送 synth/ 脚本目录 -> $SERVER:$REMOTE_ROOT/synth/"
  rsync -a --delete \
    -e "ssh -o BatchMode=yes" \
    --exclude='out/' \
    "$ROOT/synth/" \
    "$SERVER:$REMOTE_ROOT/synth/"
}

cmd_push_all() {
  cmd_push_src
  cmd_push_rtl core_mini_axi
}

cmd_pull() {
  local sub="${1:-}"
  local remote_path="$REMOTE_ROOT/work"
  local out="$ROOT/synth/out"
  if [[ -n "$sub" ]]; then
    remote_path="$remote_path/$sub"
    out="$out/$sub"
  fi
  mkdir -p "$out"
  say "拉回 $SERVER:$remote_path/ -> $out/"
  rsync -a --stats \
    -e "ssh -o BatchMode=yes" \
    "$SERVER:$remote_path/" \
    "$out/"
}

cmd_exec() {
  [[ $# -gt 0 ]] || die "用法: ./sync.sh exec \"<机器202命令>\""
  say "机器202执行: $*"
  ssh_run "cd $REMOTE_ROOT && $*"
}

main() {
  local sub="${1:-}"; shift || true
  [[ -n "$SERVER" ]] || die "无法从 $REGISTRY 解析机器202地址（可设 SYNTH_SERVER 覆盖）"
  case "$sub" in
    info)   cmd_info ;;
    push)
      local what="${1:-}"; shift || true
      case "$what" in
        src)   cmd_push_src ;;
        rtl)   [[ $# -gt 0 ]] || die "push rtl 需要产物 key"; cmd_push_rtl "$@" ;;
        synth) cmd_push_synth ;;
        all)   cmd_push_all ;;
        *)     die "未知 push 目标: $what（src|rtl <key>...|synth|all）" ;;
      esac ;;
    pull) cmd_pull "${1:-}" ;;
    exec) cmd_exec "$@" ;;
    "") usage ;;
    *) usage 1 ;;
  esac
}

main "$@"
