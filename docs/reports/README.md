# coralnpu 汇报材料（PPT）

coralnpu RISC-V NPU 上板验证与性能评估汇报材料（25 页）。

**内容源为 Markdown**，经转换器生成 python-pptx 脚本，再生成 PPTX——日常只需编辑 `deck.md`。

## 工作流

```bash
# 1. 编辑内容（Markdown）
vim docs/reports/deck.md

# 2. 一键生成 PPTX（仓库根目录执行）
bash scripts/gen-ppt/build.sh
```

产物：**`.work/ppt/coralnpu-report.pptx`**（`.work/` 不入 git）

生成流程（两步）：
```
docs/reports/deck.md
    │  scripts/gen-ppt/md2ppt.py
    ▼
scripts/gen-ppt/gen.py（自动生成，勿改）
    │  执行
    ▼
.work/ppt/coralnpu-report.pptx
```

## 环境准备（一次性）

系统 Python **没有** python-pptx（PEP 668 限制 `pip install`；apt 源也无 `python3-pptx` 包），故用 venv 隔离：

```bash
python3 -m venv ~/.local/venv/ppt-env
~/.local/venv/ppt-env/bin/pip install python-pptx
```

`build.sh` 会自动使用该 venv（无需手动激活）。

## 文件说明

| 文件 | 用途 | 是否常改 |
| --- | --- | --- |
| **`docs/reports/deck.md`** | **内容源**（Markdown：YAML 封面/图标注/表格/要点） | ✅ 日常改这个 |
| `scripts/gen-ppt/md2ppt.py` | 转换器（含 11 张图库、字号/布局逻辑） | 改样式/图时 |
| `scripts/gen-ppt/build.sh` | 一键生成脚本 | 否 |
| `scripts/gen-ppt/gen.py` | 自动生成的 py 脚本（勿改，已 gitignore） | 否（产物） |
| **`.work/ppt/coralnpu-report.pptx`** | **最终 PPT（25 页）** | 产物 |

## Markdown 语法约定（md2ppt.py 支持）

| 语法 | 效果 |
| --- | --- |
| YAML 头（`title`/`core`/`platform`/`date`） | 封面（核/平台/时间三行） |
| `# 标题` | 新幻灯片 |
| `[图:name]` | 插入预定义矢量图（见下） |
| `- 要点` | 列表（缩进 2 空格 = 二级） |
| `\| a \| b \|` | 表格 |
| `> 文本` | 脚注（佐证，小字） |

## 预定义图库（11 张，原生矢量形状）

`roadmap`（里程碑路线）、`position`（NPU 定位）、`framework`（代码框架分层）、
`storage`（存储层次）、`bus`（总线拓扑）、`swstack`（软件栈分层）、
`trim`（SoC 裁剪对比）、`loadpath`（加载通路）、`flow`（时钟/综合流程）、
`nextsteps`（下一步）、`soc_arch`（SoC 整体架构）

图定义在 `md2ppt.py` 的 `FIGURES` 字典（python-pptx 原生形状：矩形/箭头/文字，矢量可编辑）。
新增图：在 `FIGURES` 加函数 + `FIG_BOTTOM` 加底部坐标，Markdown 用 `[图:name]` 引用。

## 备注

- 字体：Microsoft YaHei（Windows/WPS 打开正常）
- PPTX 体积小（~78KB，全矢量无位图）
- 样式调整（字号/配色）改 `scripts/gen-ppt/md2ppt.py`；内容调整改 `docs/reports/deck.md`
- 布局校验：生成后可用脚本检查形状是否越界（页面高 7.5"，内容需 < 7.45"）
