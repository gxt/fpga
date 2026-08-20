#!/usr/bin/env bash
set -euo pipefail

ROOT=/home/data/vivado-risc-v
REMOTE_HOST=${REMOTE_HOST:-zzx@192.168.200.202}
REMOTE_SRC=${REMOTE_SRC:-/home/zzx/vivado-risc-v}
REMOTE_DST=${REMOTE_DST:-/home/zzx/dualv7-from-scratch-r1}
BASE_COMMIT=${BASE_COMMIT:-137a01660c63948368aafd31fdabaf742314acd1}
FORCE=${FORCE:-1}

ssh -o BatchMode=yes "$REMOTE_HOST" \
    "bash -s" -- "$REMOTE_SRC" "$REMOTE_DST" "$BASE_COMMIT" "$FORCE" <<'EOF'
set -euo pipefail

src_repo=$1
dst_repo=$2
base_commit=$3
force=$4
tmp_repo="${dst_repo}.tmp"

clone_gitlink() {
    local parent_repo=$1
    local parent_commit=$2
    local subpath=$3
    local src_path=$4
    local dst_path=$5
    local sub_commit

    sub_commit=$(
        git -C "$parent_repo" ls-tree "$parent_commit" "$subpath" \
        | awk '{print $3}'
    )

    mkdir -p "$(dirname "$dst_path")"
    git clone --shared "$src_path" "$dst_path" >/dev/null 2>&1
    git -C "$dst_path" checkout --detach "$sub_commit" >/dev/null 2>&1
    printf '%s %s\n' "$subpath" "$sub_commit" >>"$tmp_repo/SUBMODULE_COMMITS.txt"
}

copy_if_exists() {
    local src_path=$1
    local dst_path=$2
    if [[ -e "$src_path" ]]; then
        mkdir -p "$(dirname "$dst_path")"
        rsync -a --delete "$src_path"/ "$dst_path"/
    fi
}

if [[ -e "$dst_repo" ]]; then
    if [[ "$force" != "1" ]]; then
        echo "remote sandbox exists: $dst_repo" >&2
        exit 1
    fi
    rm -rf "$dst_repo"
fi

rm -rf "$tmp_repo"
mkdir -p "$tmp_repo"

git -C "$src_repo" archive "$base_commit" | tar -x -C "$tmp_repo"

mkdir -p "$tmp_repo/workspace"
ln -s "$src_repo/workspace/gcc" "$tmp_repo/workspace/gcc"

: >"$tmp_repo/SUBMODULE_COMMITS.txt"

clone_gitlink \
    "$src_repo" "$base_commit" \
    "ethernet/verilog-ethernet" \
    "$src_repo/ethernet/verilog-ethernet" \
    "$tmp_repo/ethernet/verilog-ethernet"

clone_gitlink \
    "$src_repo" "$base_commit" \
    "generators/gemmini" \
    "$src_repo/generators/gemmini" \
    "$tmp_repo/generators/gemmini"

clone_gitlink \
    "$src_repo" "$base_commit" \
    "generators/riscv-boom" \
    "$src_repo/generators/riscv-boom" \
    "$tmp_repo/generators/riscv-boom"

clone_gitlink \
    "$src_repo" "$base_commit" \
    "generators/sifive-cache" \
    "$src_repo/generators/sifive-cache" \
    "$tmp_repo/generators/sifive-cache"

clone_gitlink \
    "$src_repo" "$base_commit" \
    "generators/testchipip" \
    "$src_repo/generators/testchipip" \
    "$tmp_repo/generators/testchipip"

clone_gitlink \
    "$src_repo" "$base_commit" \
    "opensbi" \
    "$src_repo/opensbi" \
    "$tmp_repo/opensbi"

clone_gitlink \
    "$src_repo" "$base_commit" \
    "rocket-chip" \
    "$src_repo/rocket-chip" \
    "$tmp_repo/rocket-chip"

rocket_commit=$(
    git -C "$src_repo" ls-tree "$base_commit" "rocket-chip" | awk '{print $3}'
)

clone_gitlink \
    "$src_repo/rocket-chip" "$rocket_commit" \
    "cde" \
    "$src_repo/rocket-chip/cde" \
    "$tmp_repo/rocket-chip/cde"

clone_gitlink \
    "$src_repo/rocket-chip" "$rocket_commit" \
    "hardfloat" \
    "$src_repo/rocket-chip/hardfloat" \
    "$tmp_repo/rocket-chip/hardfloat"

hardfloat_commit=$(
    git -C "$src_repo/rocket-chip" ls-tree "$rocket_commit" "hardfloat" \
    | awk '{print $3}'
)

clone_gitlink \
    "$src_repo/rocket-chip/hardfloat" "$hardfloat_commit" \
    "berkeley-softfloat-3" \
    "$src_repo/rocket-chip/hardfloat/berkeley-softfloat-3" \
    "$tmp_repo/rocket-chip/hardfloat/berkeley-softfloat-3"

clone_gitlink \
    "$src_repo/rocket-chip/hardfloat" "$hardfloat_commit" \
    "berkeley-testfloat-3" \
    "$src_repo/rocket-chip/hardfloat/berkeley-testfloat-3" \
    "$tmp_repo/rocket-chip/hardfloat/berkeley-testfloat-3"

clone_gitlink \
    "$src_repo" "$base_commit" \
    "u-boot" \
    "$src_repo/u-boot" \
    "$tmp_repo/u-boot"

cat >"$tmp_repo/SANDBOX_PROVENANCE.txt" <<TXT
source_repo: $src_repo
base_commit: $base_commit
created_at: $(date -Iseconds)
gcc_link: $src_repo/workspace/gcc
TXT

cp "$tmp_repo/project/plugins.sbt" "$tmp_repo/project/plugins.sbt.orig"
cp "$tmp_repo/build.sbt" "$tmp_repo/build.sbt.orig"

python3 - <<'PY' "$tmp_repo/project/plugins.sbt" "$tmp_repo/build.sbt"
from pathlib import Path
import sys

plugins = Path(sys.argv[1])
build = Path(sys.argv[2])

keep = []
for line in plugins.read_text(encoding="utf-8").splitlines():
    if "sbt-assembly" in line:
        keep.append(line)
plugins.write_text("\n".join(keep) + "\n", encoding="utf-8")

text = build.read_text(encoding="utf-8")
old = """  .settings( // Settings for scalafix
    semanticdbEnabled := true,
    semanticdbVersion := scalafixSemanticdb.revision,
    scalacOptions += "-Ywarn-unused"
  )
"""
text = text.replace(old, "")
build.write_text(text, encoding="utf-8")
PY

copy_if_exists "$src_repo/target" "$tmp_repo/target"
copy_if_exists "$src_repo/project/target" "$tmp_repo/project/target"
copy_if_exists "$src_repo/rocket-chip/target" "$tmp_repo/rocket-chip/target"
copy_if_exists "$src_repo/rocket-chip/hardfloat/target" \
    "$tmp_repo/rocket-chip/hardfloat/target"
copy_if_exists "$src_repo/rocket-chip/macros/target" \
    "$tmp_repo/rocket-chip/macros/target"
copy_if_exists "$src_repo/generators/testchipip/target" \
    "$tmp_repo/generators/testchipip/target"
copy_if_exists "$src_repo/generators/sifive-cache/target" \
    "$tmp_repo/generators/sifive-cache/target"
copy_if_exists "$src_repo/generators/gemmini/target" \
    "$tmp_repo/generators/gemmini/target"
copy_if_exists "$src_repo/generators/targetutils/target" \
    "$tmp_repo/generators/targetutils/target"
copy_if_exists "$src_repo/generators/riscv-boom/src/target" \
    "$tmp_repo/generators/riscv-boom/src/target"

mv "$tmp_repo" "$dst_repo"
printf 'prepared %s at %s\n' "$dst_repo" "$(date -Iseconds)"
EOF
