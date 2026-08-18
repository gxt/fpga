#!/usr/bin/env bash
# T007 自定义测试程序构建脚本
#
# 用法：./build_t007.sh
#
# 功能：用 coralnpu_v2 工具链（riscv64-unknown-elf-gcc，直接调用，不改 coralnpu/ 内任何文件）
#       交叉编译 sim/ 下的两个测试程序 ELF：
#         - build/t007_scalar_fp_test.elf   标量浮点+整数+ZBB（跑 core_mini_axi_sim）
#         - build/t007_rvv_add_test.elf     RVV 向量加法（跑 rvv_core_mini_axi_sim）
#
# 依赖：
#   - coralnpu/ 的 bazel 缓存已含 @toolchain_coralnpu_v2（~/.cache/bazel/_bazel_*/external/）
#   - coralnpu/toolchain/crt/ 的 crt 源文件（只读复用，不修改）
#
# 退出码：全部成功返回 0。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
CORALNPU="${REPO_ROOT}/coralnpu"

MARCH="rv32imf_zve32f_zicsr_zifencei_zbb_zfbfmin_zvfbfmin_zvfbfwma"
MABI="ilp32"
MC="medany"

# ---- 定位工具链 ----
TOOLCHAIN_BIN=""
for d in "$HOME"/.cache/bazel/_bazel_*/*/external/toolchain_coralnpu_v2/bin; do
  if [ -x "$d/riscv64-unknown-elf-gcc" ]; then
    TOOLCHAIN_BIN="$d"
    break
  fi
done
if [ -z "$TOOLCHAIN_BIN" ]; then
  echo "ERROR: 未找到 toolchain_coralnpu_v2。先运行: cd coralnpu && bazel build //examples:coralnpu_v2_hello_world_add_floats" >&2
  exit 1
fi
GCC="$TOOLCHAIN_BIN/riscv64-unknown-elf-gcc"
echo "[build] 工具链: $GCC"

# ---- 工作目录 ----
OUT="$SCRIPT_DIR/build"
rm -rf "$OUT"
mkdir -p "$OUT"

# ---- 编译 crt（只读复用 coralnpu/toolchain/crt/ 源码，不改原文件）----
CRT_SRC="$CORALNPU/toolchain/crt"
for src in crt.S coralnpu_start.S coralnpu_exceptions.cc coralnpu_gloss.cc cxx_guards.cc; do
  cp "$CRT_SRC/$src" "$OUT/"
done
COMMON_FLAGS=(-march="$MARCH" -mabi="$MABI" -mcmodel="$MC" -nostdlib -O1 -g3 -ffunction-sections -fdata-sections)

"$GCC" "${COMMON_FLAGS[@]}" -c "$OUT/crt.S" -o "$OUT/crt.o"
"$GCC" "${COMMON_FLAGS[@]}" -c "$OUT/coralnpu_start.S" -o "$OUT/coralnpu_start.o"
"$GCC" "${COMMON_FLAGS[@]}" -c "$OUT/coralnpu_exceptions.cc" -o "$OUT/coralnpu_exceptions.o"
"$GCC" "${COMMON_FLAGS[@]}" -c -DSKIP_HTIF_SYMBOLS "$OUT/coralnpu_gloss.cc" -o "$OUT/coralnpu_gloss.o"
"$GCC" "${COMMON_FLAGS[@]}" -c "$OUT/cxx_guards.cc" -o "$OUT/cxx_guards.o"

CRT_OBJS=(crt.o coralnpu_start.o coralnpu_exceptions.o coralnpu_gloss.o cxx_guards.o)

# ---- 编译测试程序并链接 ----
link_test() {
  local name="$1"
  local src="$2"
  "$GCC" "${COMMON_FLAGS[@]}" -c "$SCRIPT_DIR/$src" -o "$OUT/$name.o"
  "$GCC" "${COMMON_FLAGS[@]}" \
    -Wl,-T,"$SCRIPT_DIR/t007_tcm.ld" \
    --specs=nano.specs \
    -Wl,--start-group -lstdc++ -lm -lc -lgcc -Wl,--end-group \
    -nostartfiles \
    -Wl,--gc-sections \
    "${CRT_OBJS[@]/#/$OUT/}" \
    "$OUT/$name.o" \
    -o "$OUT/$name.elf"
  echo "[build] 生成 $name.elf"
}

link_test t007_scalar_fp_test t007_scalar_fp_test.c
link_test t007_rvv_add_test t007_rvv_add_test.c

echo "[build] 完成。ELF 位于 $OUT/"
ls -la "$OUT"/*.elf
