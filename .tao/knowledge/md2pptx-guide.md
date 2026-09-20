# Markdown → PPTX 工具链指南（python-pptx）

日期：2026-09-20
适用场景：**用 Markdown 写内容、脚本生成 PPTX**（技术汇报、评审材料、需要多轮迭代的演示）
实践来源：coralnpu 汇报 PPT（27 页，经 5+ 轮评审迭代）
工具位置：`scripts/gen-ppt/`（`md2ppt.py` 转换器 + `build.sh` 一键脚本）

---

## 1. 为什么选这条路线

| 方案 | 结论 |
| --- | --- |
| **手写 python-pptx 脚本** | 内容硬编码在脚本里，改内容=改代码，迭代成本高 |
| **pandoc（Markdown→PPTX）** | ❌ 实测差：无矢量图、内容多自动拆页（22→35 页）、默认模板朴素、排版不可控 |
| **Marp** | 导出 PPTX 每页是图片（文字不可编辑） |
| **✅ Markdown + python-pptx 转换器** | 内容与样式分离：**改内容只编辑 Markdown**，样式由转换器统一控制，产物是**原生可编辑 PPTX**（矢量、体积小 ~80KB） |

**核心思想**：`内容（Markdown）` / `转换器（md2ppt.py，样式+图库）` / `产物（.work 下 pptx）` 三层分离。

---

## 2. 工具链架构

```
docs/reports/<报告>.md            ← 内容源（日常编辑）
        │  ① python md2ppt.py <md> <out.pptx>
        ▼
.work/ppt/gen.py                  ← 自动生成的 py 脚本（勿改，产物）
        │  ② python gen.py
        ▼
.work/ppt/<报告>.pptx             ← 最终 PPTX
```

- **`md2ppt.py`**：转换器（Markdown 解析 + 图库 + 字号/布局逻辑）——**改样式/加图时编辑**
- **`gen.py`**：自动生成的脚本（含每页内容 + 图调用）——**勿手工改**，每次从 md 重新生成
- **`.work/`**：所有产物目录（不入 git，无需 .gitignore）

---

## 3. 环境准备（一次性）

系统 Python 通常**没有** python-pptx（Ubuntu 的 PEP 668 限制 `pip install`；apt 源也无 `python3-pptx` 包），用 venv 隔离：

```bash
python3 -m venv ~/.local/venv/ppt-env
~/.local/venv/ppt-env/bin/pip install python-pptx
```

`build.sh` 会自动使用该 venv（无需激活）。**不要**用 `--break-system-packages`（有风险）。

---

## 4. 工作流（日常）

```bash
# 1. 编辑内容
vim docs/reports/<报告>.md

# 2. 一键生成
bash scripts/gen-ppt/build.sh
# 或指定内容源：
bash scripts/gen-ppt/build.sh <报告>.md
```

**迭代循环**：改 md（或属性注释）→ 跑 build.sh → 检查产物 → 反馈调整。

---

## 5. Markdown 语法参考（md2ppt.py 支持）

| 语法 | 效果 |
| --- | --- |
| YAML 头（`title`/`core`/`platform`/`date`） | 封面（核/平台/空行/日期） |
| `# 标题` | **新幻灯片**（分页符） |
| `[图:name]` / `[图:name fs=16]` | 插入预定义矢量图（可指定字号） |
| `- 要点` | 列表；**缩进 2 空格 = 二级** |
| `\| a \| b \|` | 表格 |
| `> 文本` | 佐证/说明（**默认固定置底 6.45"**） |
| `> [24] 文本` | 大字强调（指定字号 + 加粗，**跟随内容流**） |
| 普通行（非以上语法） | **段落小标题**（粗体 20pt） |
| `**粗体**` / `*斜体*` | 行内格式（渲染为 pptx run，非字面星号） |
| `<!-- tbl size=16 colw=3,2,2 -->` | 表格属性：字号 / 列宽（英寸列表） |
| `<!-- bullets size=24 spacing=1.5 top=5.3 -->` | 列表属性：字号 / 行距 / 位置 |
| `<!-- quote size=18 top=6.15 -->` | 引用属性：字号 / 位置 |

**注意**：`#`（一级标题）= 幻灯片分页；`##` 章节格式的文档不能直接生成（会全挤在一页）。

---

## 6. 预定义图库（11 张，原生矢量形状）

`roadmap`（里程碑）· `position`（定位）· `framework`（代码框架分层）· `storage`（存储层次）·
`bus`（总线拓扑）· `swstack`（软件栈）· `trim`（裁剪对比）· `loadpath`（加载通路）·
`flow`（时钟/流程）· `soc_arch`（SoC 架构）· `official_block`（官方图，add_picture）

**图定义**在 `md2ppt.py` 的 `FIGURES` 字典（python-pptx 原生形状：矩形/箭头/文字，矢量可编辑、体积小）。

---

## 7. md2ppt.py 设计要点（改样式时参考）

| 机制 | 说明 |
| --- | --- |
| **流式布局** | 每页 y 游标：图 → 内容按顺序排布，自动累加 |
| **图底部坐标表** | `FIG_BOTTOM[图名]` = 图下内容起点（避免图文重叠） |
| **字号规范** | 页面标题 25pt；正文（列表）20/18pt；表格 14-16pt；图 14-18pt；佐证 14pt；强调 quote 24pt |
| **表格行高固定** | `row.height = height/(rows+1)`——**关键**：不设置时 PowerPoint 按内容自动扩展，会推挤后续元素出屏 |
| **佐证置底** | 普通 quote 固定 top=6.45"（`[N]` 大字 quote 跟随流） |
| **Markdown 行内格式** | `add_runs()` 解析 `**粗体**`/`*斜体*` 为多个 run |
| **页脚** | 每页右下（标题 + 页码），14pt |

**字号与越界**：页面高 7.5"（内容需 < 7.45"，页脚 7.02"）。字号大 → 易溢出 → 需**同时精简文本**。

---

## 8. 评审迭代模式（实战经验）

多轮评审中，反馈类型与实现方式：

| 反馈类型 | 实现方式 | 示例 |
| --- | --- | --- |
| **改文字/数据** | 直接编辑 md | 内容修正 |
| **改字号** | 属性注释 `size=` | `<!-- tbl size=16 -->` |
| **改位置** | 属性注释 `top=` | `<!-- quote top=6.15 -->` |
| **改列宽** | 属性注释 `colw=` | `<!-- tbl colw=3.4,1.5,2.25 -->` |
| **改行距** | 属性注释 `spacing=` | `<!-- bullets size=24 spacing=1.5 -->` |
| **删/加列** | 改 md 表格 | 删"佐证"列 |
| **删/加页** | 删/加 `# 标题` 段 | 新增器件对比页 |
| **换图/调图** | 改 `FIGURES`（fs 参数） | 图字号 16/18 |
| **图内容调整** | 改 `FIGURES` 的 box/文字 | rvv_core 为核心 |
| **顺序调整** | 调 md 中段落顺序 | 下一步/优化方向换序 |

**关键**：**内容调整改 md，样式调整优先用属性注释**（避免改转换器）。

---

## 9. 踩坑与解决（重要）

| # | 坑 | 现象 | 解决 |
| --- | --- | --- | --- |
| 1 | **段落标题被忽略** | `**结论：**` 等普通行不显示（parse 只处理特殊语法） | parse_md 增加**段落解析** + `para()` 渲染（粗体 20pt） |
| 2 | **表格实际高度不可控** | 设定 height 只是"建议"，PowerPoint 按内容扩展 → 后续元素被推出屏 | 显式设置 `row.height` |
| 3 | **佐证位置不一致** | 佐证跟随内容流，位置随机 | 佐证**统一固定置底**（top=6.45"） |
| 4 | **字号大导致溢出** | 提高字号后内容超出页面 | 动态字号 + **精简文本**（页面空间固定） |
| 5 | **图片放大受限** | 图放大后与文字/页脚重叠 | 计算可用空间（图底 + 文字 + 页脚 ≤ 7.02"） |
| 6 | **PEP 668** | `pip install` 被拒 | venv 隔离 |
| 7 | **pandoc 效果差** | 无图、自动分页、模板朴素 | 改用 python-pptx 原生形状 |
| 8 | **无 SVG 转换工具** | 无法把 SVG 转 PNG 插入 | 改用 python-pptx **原生形状**画图（更优：矢量、可编辑、小） |
| 9 | **生成脚本与模板混淆** | 改了 gen.py 被覆盖 | 明确：**改 md（内容）/ md2ppt.py（样式）**，gen.py 是产物 |
| 10 | **产物污染仓库** | pptx/gen.py 入 git | 产物统一输出 `.work/`（已忽略） |

---

## 10. 越界/重叠检测（建议每次生成后跑）

```bash
~/.local/venv/ppt-env/bin/python - << 'EOF'
from pptx import Presentation
prs = Presentation('.work/ppt/<报告>.pptx')
bad = 0
for i, s in enumerate(prs.slides, 1):
    mx = 0
    for sh in s.shapes:
        if sh.top is None: continue
        if (sh.height or 0) > 7*914400: continue      # 跳过全页背景
        b = (sh.top + (sh.height or 0)) / 914400.0
        if abs(b - 7.37) < 0.01: continue             # 跳过页脚
        mx = max(mx, b)
    if mx > 7.02:
        bad += 1; print(f'  P{i}: 底={mx:.2f}（与页脚重叠/超界）')
print('问题页数:', bad)
EOF
```

阈值：内容底 ≤ **7.02"**（页脚起点）；页面高 7.5"。

---

## 11. 新项目复用步骤

1. **复制工具**：`scripts/gen-ppt/{md2ppt.py, build.sh}`（可整体复制到新仓库）
2. **准备环境**：`python3 -m venv ~/.local/venv/ppt-env && .../pip install python-pptx`
3. **写内容**：新建 `deck.md`（YAML 封面 + `#` 分页 + 表格/列表/图标注）
4. **生成**：`bash build.sh`（或改 build.sh 的默认内容源）
5. **检测**：跑越界检测脚本
6. **迭代**：改 md / 属性注释 → 重跑

**图库适配**：新场景替换 `FIGURES`（保留通用图或新增），`FIG_BOTTOM` 同步更新。

---

## 12. 扩展方法

**新增一张图**：
```python
FIGURES['myfig'] = '''
def draw_myfig(s, fs=14):
    box(s, '文字', x, y, w, h, fs=fs)
    arrow(s, x, y, 0.5)
'''
FIG_BOTTOM['myfig'] = 3.6      # 图底部 y（内容从此 +0.15 开始）
```
Markdown 中用 `[图:myfig]` 或 `[图:myfig fs=16]`。

**新增属性**：在 `parse_md` 的注释解析加类型 + `gen_py` 对应处理。

**换主题**：改 `HEADER` 的颜色常量（DARK/ACCENT/LIGHT/GRAY/RED/GREEN/ORANGE/WHITE）与 `FONT`。

---

## 附：本项目的具体实例

- 内容源：`docs/reports/coralnpu-fpga-report-202609.md`（27 页）
- 工具：`scripts/gen-ppt/{md2ppt.py, build.sh}`
- 产物：`.work/ppt/coralnpu-fpga-report-202609.pptx`
- 详细说明：`docs/reports/README.md`
