#!/bin/bash
# =============================================================================
# build.sh —— 一键生成汇报 PPT：Markdown → py 脚本 → PPTX
#
# 用法（仓库根目录）:
#     bash scripts/gen-ppt/build.sh
#
# 结构:
#     内容源:  docs/reports/coralnpu-fpga-report-<YYYYMM>.md
#     转换器:  scripts/gen-ppt/md2ppt.py
#     产物:    .work/ppt/<内容源同名>.pptx + gen.py（自动生成）
#     依赖:    python-pptx（venv: ~/.local/venv/ppt-env，见 docs/reports/README.md）
#
# 用法: bash scripts/gen-ppt/build.sh [内容源.md]   （默认 202609）
# =============================================================================
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DECK_NAME="${1:-coralnpu-fpga-report-202609.md}"
DECK="$REPO_DIR/docs/reports/$DECK_NAME"
OUT_DIR="$REPO_DIR/.work/ppt"
OUT_PPTX="$OUT_DIR/${DECK_NAME%.md}.pptx"
PY="$HOME/.local/venv/ppt-env/bin/python"

if [ ! -f "$DECK" ]; then
    echo "内容源不存在: $DECK"
    echo "可用: $(ls "$REPO_DIR/docs/reports/"*.md 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
    exit 1
fi

if [ ! -x "$PY" ]; then
    echo "缺少 python-pptx 环境: $PY"
    echo "请先运行:"
    echo "  python3 -m venv ~/.local/venv/ppt-env"
    echo "  ~/.local/venv/ppt-env/bin/pip install python-pptx"
    exit 1
fi

mkdir -p "$OUT_DIR"
echo "① Markdown → py 脚本 ..."
$PY "$SCRIPT_DIR/md2ppt.py" "$DECK" "$OUT_PPTX"
echo "② py 脚本 → PPTX ..."
$PY "$OUT_DIR/gen.py"
echo "完成: $OUT_PPTX"
