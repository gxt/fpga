#!/usr/bin/env bash
# T007 运行脚本：用 Verilator C++ sim 运行两个自定义测试 ELF
#
# 用法：./run_t007.sh
#
# 依赖：
#   - sim/build/ 下已有 ELF（先跑 ./build_t007.sh）
#   - coralnpu bazel 已构建 core_mini_axi_sim 与 rvv_core_mini_axi_sim
#       cd coralnpu && bazel build //tests/verilator_sim:core_mini_axi_sim --linkopt=-latomic
#       cd coralnpu && bazel build //tests/verilator_sim:rvv_core_mini_axi_sim --linkopt=-latomic
#
# 退出码：两个测试全部 exit 0 返回 0，否则非 0。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORALNPU="$(dirname "${SCRIPT_DIR}")/coralnpu"
LOGS="$(dirname "${SCRIPT_DIR}")/.tao/logs"

SIM_BIN="$CORALNPU/bazel-out/k8-fastbuild/bin/tests/verilator_sim"
SCALAR_SIM="$SIM_BIN/core_mini_axi_sim"
RVV_SIM="$SIM_BIN/rvv_core_mini_axi_sim"
ELF_SCALAR="$SCRIPT_DIR/build/t007_scalar_fp_test.elf"
ELF_RVV="$SCRIPT_DIR/build/t007_rvv_add_test.elf"

[ -x "$SCALAR_SIM" ] || { echo "ERROR: 缺 $SCALAR_SIM，先构建"; exit 1; }
[ -x "$RVV_SIM" ] || { echo "ERROR: 缺 $RVV_SIM，先构建"; exit 1; }
[ -f "$ELF_SCALAR" ] || { echo "ERROR: 缺 $ELF_SCALAR，先跑 ./build_t007.sh"; exit 1; }
[ -f "$ELF_RVV" ] || { echo "ERROR: 缺 $ELF_RVV，先跑 ./build_t007.sh"; exit 1; }

echo "=== [1/2] 标量浮点+整数测试（core_mini_axi_sim）==="
if "$SCALAR_SIM" --binary "$ELF_SCALAR" --instr_trace --debug_axi \
  > "$LOGS/T007-run-scalar.log" 2>&1; then
  scalar_rc=0
else
  scalar_rc=$?
fi
echo "scalar exit: $scalar_rc"

echo "=== [2/2] RVV 向量加法测试（rvv_core_mini_axi_sim）==="
if "$RVV_SIM" --binary "$ELF_RVV" --instr_trace --debug_axi \
  > "$LOGS/T007-run-rvv.log" 2>&1; then
  rvv_rc=0
else
  rvv_rc=$?
fi
echo "rvv exit: $rvv_rc"

echo ""
echo "scalar exit = $scalar_rc, rvv exit = $rvv_rc"
[ "$scalar_rc" -eq 0 ] && [ "$rvv_rc" -eq 0 ]
