#!/usr/bin/env bash
set -euo pipefail

ROOT=/home/data/vivado-risc-v
KIT_DIR=$ROOT/doc/dualv7-from-scratch-kit
OUT_DIR=${OUT_DIR:-$ROOT/workspace/from-scratch-kit-r1}
REMOTE_HOST=${REMOTE_HOST:-zzx@192.168.200.202}
REMOTE_DST=${REMOTE_DST:-/home/zzx/dualv7-from-scratch-r1}
CONFIG=${CONFIG:-rocket64b2}
BOARD=${BOARD:-dualv7}

mkdir -p "$OUT_DIR"

"$KIT_DIR/scripts/01_prepare_remote_clean_sandbox.sh"
"$KIT_DIR/scripts/02_build_remote_rocket64b2.sh"
"$KIT_DIR/scripts/03_build_local_linux_ramdisk.sh"

scp -q "$REMOTE_HOST:$REMOTE_DST/workspace/$CONFIG/vivado-$BOARD-riscv/$BOARD-riscv.runs/impl_1/riscv_wrapper.bit" \
    "$OUT_DIR/$CONFIG.bit"
scp -q "$REMOTE_HOST:$REMOTE_DST/workspace/boot.elf" \
    "$OUT_DIR/boot.elf"
scp -q "$REMOTE_HOST:$REMOTE_DST/logs/artifacts.sha256" \
    "$OUT_DIR/remote-artifacts.sha256"

sha256sum "$OUT_DIR/$CONFIG.bit" "$OUT_DIR/boot.elf" >"$OUT_DIR/local-copy.sha256"

sudo -n python3 "$KIT_DIR/scripts/04_board_smoke_jtag_boot.py" \
    --bit "$OUT_DIR/$CONFIG.bit" \
    --bootelf "$OUT_DIR/boot.elf" \
    --image "$ROOT/linux-stable/arch/riscv/boot/Image" \
    --ramdisk "$ROOT/ramdisk-realcheck-src/out/ramdisk-realcheck" \
    --out-dir "$OUT_DIR/smoke"

echo "end-to-end flow completed"
