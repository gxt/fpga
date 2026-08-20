#!/usr/bin/env bash
set -euo pipefail

ROOT=/home/data/vivado-risc-v
OUT_DIR=${OUT_DIR:-$ROOT/workspace/from-scratch-kit-r1/local-build}
LINUX_DIR=${LINUX_DIR:-$ROOT/linux-stable}
RAMDISK_DIR=${RAMDISK_DIR:-$ROOT/ramdisk-realcheck-src}
LINUX_CC=${LINUX_CC:-/usr/bin/riscv64-linux-gnu-}

mkdir -p "$OUT_DIR"

run_step() {
    local name=$1
    shift
    echo "[run] $name"
    bash -lc "set -euo pipefail; cd '$ROOT'; $* 2>&1 | tee '$OUT_DIR/$name.log'"
}

run_step 01_linux_oldconfig \
    "make -C '$LINUX_DIR' ARCH=riscv CROSS_COMPILE=$LINUX_CC oldconfig"

run_step 02_linux_image \
    "make -j\$(nproc) -C '$LINUX_DIR' ARCH=riscv CROSS_COMPILE=$LINUX_CC all"

run_step 03_ramdisk \
    "make -C '$RAMDISK_DIR' clean all"

sha256sum \
    "$LINUX_DIR/arch/riscv/boot/Image" \
    "$RAMDISK_DIR/out/ramdisk-realcheck" \
    >"$OUT_DIR/artifacts.sha256"

echo "local build complete"
