#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
md2ppt.py —— Markdown → python-pptx 脚本 → PPTX

用法:
    python md2ppt.py deck.md [out_prefix]
流程:
    deck.md ──(本脚本)──> <out_prefix>_gen.py ──(执行)──> <out_prefix>.pptx

Markdown 约定:
    ---           YAML 元数据（title/subtitle/date）→ 封面
    # 标题        新幻灯片
    [图:name]     插入预定义矢量图（紧凑版，占上半页；见 FIGURES）
    - 要点        列表（缩进 2 空格 = 二级）
    | a | b |     Markdown 表格
    > 文本        脚注（小字）
"""
import re
import sys
import os

# =====================================================================
# 图函数库（紧凑版：图占 y 1.25~3.6，为下方内容留空间）
# =====================================================================
FIGURES = {}

FIGURES['roadmap'] = '''
def draw_roadmap(s):
    ms = [('M1', '上板闭环', 'UART 加载→执行→回读', GREEN),
          ('M2', 'EDA 流程', '20MHz 时序收敛', GREEN),
          ('M3', '完整 SoC + 评测', '606 用例 100% 通过', GREEN),
          ('M4', '内存系统扩展', 'TCM 扩容 / SPI / DDR', ORANGE)]
    for i, (tag, name, desc, col) in enumerate(ms):
        x = 0.7 + i * 3.15
        box(s, tag + '  ' + name, x, 1.6, 2.5, 0.75, fill=col, tc=WHITE, fs=12, bold=True)
        box(s, desc, x, 2.45, 2.5, 0.6, fs=10.5)
        if i < 3:
            arrow(s, x + 2.55, 1.85, 0.55)
'''

FIGURES['position'] = '''
def draw_position(s):
    box(s, 'Coral NPU（开源 IP）', 4.4, 1.4, 4.5, 0.6, fill=DARK, tc=WHITE, fs=13, bold=True)
    for t, x in [('Scalar\\nrv32im', 1.3), ('Vector (SIMD)\\n128-bit', 4.4), ('Matrix\\n(future)', 7.5)]:
        box(s, t, x, 2.2, 2.3, 0.8, fs=11)
    box(s, 'AXI4（manager + subordinate）', 4.0, 3.15, 5.3, 0.5, fill=LIGHT, fs=11)
'''

FIGURES['framework'] = '''
def draw_framework(s):
    layers = [('软件层', 'litert-micro（conv/dwconv/fc）· examples · tests', LIGHT),
              ('核层', 'SCore(rv32im) + RvvCore(RVV) + FloatCore + LSU + L1 Cache + TCM', RGBColor(0xD6,0xE4,0xF5)),
              ('总线层', 'TileLink-UL：Xbar · Router · Socket · Arbiter · FifoAsync', RGBColor(0xBF,0xD7,0xEE)),
              ('桥/外设', 'Axi2TLUL · TLUL2Axi ‖ clint · plic · gpio · sram · spi · dma', RGBColor(0xA8,0xCB,0xE8))]
    for i, (name, desc, col) in enumerate(layers):
        y = 1.35 + i * 0.58
        box(s, name, 0.6, y, 1.5, 0.5, fill=DARK, tc=WHITE, fs=11, bold=True)
        box(s, desc, 2.25, y, 10.45, 0.5, fill=col, fs=10)
'''

FIGURES['storage'] = '''
def draw_storage(s):
    box(s, 'L1I Cache 8KB（4-way）', 0.7, 1.4, 3.7, 0.6, fs=11)
    box(s, 'L1D Cache 16KB（4-way，双 bank）', 4.6, 1.4, 4.4, 0.6, fs=11)
    box(s, 'L0 I-Cache 1KB（fetch）', 9.2, 1.4, 3.4, 0.6, fs=11)
    box(s, 'ITCM（可配 8K~1M）', 0.7, 2.2, 5.6, 0.6, fill=RGBColor(0xD6,0xE4,0xF5), fs=11)
    box(s, 'DTCM（可配 32K~1M）', 6.6, 2.2, 6.0, 0.6, fill=RGBColor(0xD6,0xE4,0xF5), fs=11)
    box(s, 'FabricArbiter（TCM 与外部访问仲裁）', 2.5, 3.0, 8.3, 0.55, fs=11)
'''

FIGURES['bus'] = '''
def draw_bus(s):
    hosts = ['coralnpu_core', 'uart_host', 'spi2tlul（规划）', 'dma（规划）']
    for i, h in enumerate(hosts):
        box(s, h, 0.7 + i * 3.15, 1.4, 2.6, 0.55, fs=10.5)
    box(s, 'CoralNPUXbar —— TileLink-UL 交叉开关', 0.7, 2.15, 11.9, 0.6, fill=DARK, tc=WHITE, fs=12, bold=True)
    devs = ['coralnpu_device', 'sram 256K', 'clint / plic', 'gpio', 'rom', 'spi / dma']
    for i, d in enumerate(devs):
        box(s, d, 0.7 + i * 2.05, 2.95, 1.8, 0.55, fs=10)
'''

FIGURES['swstack'] = '''
def draw_swstack(s):
    sw = [('工具链', 'RISC-V clang（host_clang）· crt0 · TCM 链接脚本'),
          ('运行库', 'litert-micro（conv / depthwise_conv / fully_connected）· rvv_opt.h'),
          ('示例', 'hello_world · rvv_add_intrinsic · MobileNet V1'),
          ('验证', 'cocotb · npusim · systemc · uvm · vcs_sim · verilator_sim')]
    for i, (name, desc) in enumerate(sw):
        y = 1.35 + i * 0.58
        box(s, name, 0.6, y, 1.5, 0.5, fill=DARK, tc=WHITE, fs=11, bold=True)
        box(s, desc, 2.25, y, 10.45, 0.5, fs=10)
'''

FIGURES['trim'] = '''
def draw_trim(s):
    box(s, '上游 chip_nexus（完整，但 DDR/ISP 未完成）：核 + Xbar + ISP + DDR + SPI + DMA + 外设',
        0.6, 1.4, 12.1, 0.55, fill=GRAY, tc=WHITE, fs=10.5, bold=True)
    arrow(s, 6.6, 2.05, 0.0, 0.35, shape=MSO_SHAPE.DOWN_ARROW, color=RED)
    box(s, '裁剪后（我们，M3）：CoreTlul + CoralNPUXbar + clint/plic/gpio/sram(256K) + uart_host',
        0.6, 2.5, 12.1, 0.55, fill=GREEN, tc=WHITE, fs=10.5, bold=True)
    box(s, '删除：ISP / DDR / spi2tlul / dma / spi_master(_flash)', 3.5, 3.2, 6.3, 0.5, fs=10.5)
'''

FIGURES['loadpath'] = '''
def draw_loadpath(s):
    chain = [('PC 串口', 0.7), ('UART\\n收发', 2.75), ('host_cmd_fsm\\n命令解析', 4.8),
             ('Axi2TLUL\\n桥', 6.85), ('Xbar\\nuart_host', 8.9), ('核 TCM/CSR\\n· SRAM · 外设', 10.95)]
    for t, x in chain:
        box(s, t, x, 1.75, 1.7, 1.0, fs=10)
        if x < 10.9:
            arrow(s, x + 1.78, 2.1, 0.1)
'''

FIGURES['flow'] = '''
def draw_flow(s):
    box(s, '100MHz 差分', 0.7, 1.4, 2.6, 0.6, fs=11)
    arrow(s, 3.35, 1.6, 0.4)
    box(s, 'MMCM ×12/60', 3.85, 1.4, 2.6, 0.6, fill=RGBColor(0xD6,0xE4,0xF5), fs=11)
    arrow(s, 6.5, 1.6, 0.4)
    box(s, '20MHz 核时钟（单时钟域）', 7.0, 1.4, 5.6, 0.6, fill=RGBColor(0xD5,0xEF,0xDC), fs=11)
    flow = [('Chisel RTL', 0.7), ('bazel 生成 SV', 3.3), ('Vivado 综合', 5.9),
            ('bitstream', 8.5), ('上板（201）', 10.9)]
    for i, (t, x) in enumerate(flow):
        box(s, t, x, 2.3, 2.4, 0.8, fs=10.5)
        if i < 4:
            arrow(s, x + 2.35, 2.65, 0.15)
'''

FIGURES['nextsteps'] = '''
def draw_nextsteps(s):
    nxt = [('T026', 'SPI 加载（秒级）', 0.7), ('T027', 'DDR 通路（完整产品形态）', 4.6),
           ('T028', '8 个 DDR 用例 + 全量 621 评测', 8.5)]
    for tag, desc, x in nxt:
        box(s, tag + '\\n' + desc, x, 1.7, 3.7, 1.0, fill=LIGHT, fs=11.5)
'''

FIGURES['soc_arch'] = '''
def draw_soc_arch(s):
    box(s, 'PC 串口', 0.6, 2.0, 1.4, 0.7, fs=11)
    arrow(s, 2.05, 2.2, 0.3)
    box(s, 'host_cmd_fsm\\n+ Axi2TLUL', 2.4, 2.0, 1.9, 0.7, fs=10)
    arrow(s, 4.35, 2.2, 0.3)
    box(s, 'CoralNPUXbar\\n(TileLink-UL)', 4.7, 1.9, 2.3, 0.9, fill=DARK, tc=WHITE, fs=11, bold=True)
    arrow(s, 7.05, 2.2, 0.3)
    box(s, 'rvv_core (CoreTlul)', 7.4, 1.3, 2.6, 0.55, fs=10)
    box(s, 'sram 256K', 7.4, 1.95, 2.6, 0.5, fs=10)
    box(s, 'clint / plic', 7.4, 2.55, 2.6, 0.5, fs=10)
    box(s, 'gpio / rom', 7.4, 3.15, 2.6, 0.5, fs=10)
    box(s, 'coralnpu_device\\n(ITCM/DTCM/CSR)', 10.2, 1.3, 2.5, 2.35, fill=RGBColor(0xD6,0xE4,0xF5), fs=10)
'''

# =====================================================================
# 各图底部 y 坐标（图下方内容从此开始）
# =====================================================================
FIG_BOTTOM = {
    'roadmap': 3.05, 'position': 3.65, 'framework': 3.7, 'storage': 3.55, 'bus': 3.5,
    'swstack': 3.7, 'trim': 3.7, 'loadpath': 2.7, 'flow': 3.2, 'nextsteps': 2.7,
    'soc_arch': 3.65,
}

# =====================================================================
# 生成脚本的头（imports + 主题 + helpers）
# =====================================================================
HEADER = '''#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""由 md2ppt.py 从 Markdown 自动生成 —— 请勿手工修改，改 Markdown 后重跑 md2ppt.py"""
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
import os

DARK   = RGBColor(0x1F, 0x3A, 0x5F)
ACCENT = RGBColor(0x2E, 0x75, 0xB6)
LIGHT  = RGBColor(0xE8, 0xF0, 0xF8)
GRAY   = RGBColor(0x59, 0x59, 0x59)
RED    = RGBColor(0xC0, 0x39, 0x2B)
GREEN  = RGBColor(0x27, 0x8A, 0x4A)
ORANGE = RGBColor(0xD9, 0x7A, 0x06)
WHITE  = RGBColor(0xFF, 0xFF, 0xFF)
FONT   = 'Microsoft YaHei'

prs = Presentation()
prs.slide_width  = Inches(13.333)
prs.slide_height = Inches(7.5)
BLANK = prs.slide_layouts[6]
PAGE = [0]

def slide(title=None):
    s = prs.slides.add_slide(BLANK)
    if title:
        tb = s.shapes.add_textbox(Inches(0.5), Inches(0.28), Inches(12.3), Inches(0.75))
        p = tb.text_frame.paragraphs[0]
        r = p.add_run(); r.text = title
        r.font.size = Pt(25); r.font.bold = True; r.font.color.rgb = DARK; r.font.name = FONT
        ln = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.5), Inches(1.02), Inches(12.3), Pt(2.2))
        ln.fill.solid(); ln.fill.fore_color.rgb = ACCENT; ln.line.fill.background()
    return s

def bullets(s, items, left=0.6, top=1.25, width=12.1, height=None, size=15):
    if height is None:
        height = 0.55 * len(items) + 0.30
    tb = s.shapes.add_textbox(Inches(left), Inches(top), Inches(width), Inches(height))
    tf = tb.text_frame; tf.word_wrap = True
    for i, it in enumerate(items):
        text, lvl = (it if isinstance(it, tuple) else (it, 0))
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.level = lvl; p.space_after = Pt(4)
        r = p.add_run(); r.text = text
        r.font.size = Pt(size - lvl * 1.5); r.font.name = FONT
        r.font.color.rgb = DARK if lvl == 0 else GRAY
    return tb

def table(s, headers, rows, left=0.6, top=1.25, width=12.1, height=5.0, fs=12):
    shp = s.shapes.add_table(len(rows) + 1, len(headers), Inches(left), Inches(top),
                             Inches(width), Inches(height))
    tbl = shp.table
    for j, h in enumerate(headers):
        c = tbl.cell(0, j); c.text = h
        for p in c.text_frame.paragraphs:
            for r in p.runs:
                r.font.size = Pt(fs); r.font.bold = True; r.font.color.rgb = WHITE; r.font.name = FONT
        c.fill.solid(); c.fill.fore_color.rgb = ACCENT
        c.vertical_anchor = MSO_ANCHOR.MIDDLE
    for i, row in enumerate(rows):
        for j, v in enumerate(row):
            c = tbl.cell(i + 1, j); c.text = str(v)
            for p in c.text_frame.paragraphs:
                for r in p.runs:
                    r.font.size = Pt(fs); r.font.name = FONT; r.font.color.rgb = DARK
            c.fill.solid(); c.fill.fore_color.rgb = LIGHT if i % 2 == 0 else WHITE
            c.vertical_anchor = MSO_ANCHOR.MIDDLE
    return tbl

def box(s, text, x, y, w, h, fill=LIGHT, tc=DARK, fs=11, bold=False,
        shape=MSO_SHAPE.ROUNDED_RECTANGLE, line=ACCENT):
    shp = s.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
    shp.fill.solid(); shp.fill.fore_color.rgb = fill
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line; shp.line.width = Pt(1)
    tf = shp.text_frame; tf.word_wrap = True; tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]; p.alignment = PP_ALIGN.CENTER
    r = p.add_run(); r.text = text
    r.font.size = Pt(fs); r.font.color.rgb = tc; r.font.name = FONT; r.font.bold = bold
    return shp

def arrow(s, x, y, w, h=0.16, color=ACCENT, shape=MSO_SHAPE.RIGHT_ARROW):
    shp = s.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
    shp.fill.solid(); shp.fill.fore_color.rgb = color; shp.line.fill.background()
    return shp

def footer(s, text):
    PAGE[0] += 1
    tb = s.shapes.add_textbox(Inches(0.5), Inches(7.02), Inches(12.3), Inches(0.35))
    p = tb.text_frame.paragraphs[0]; p.alignment = PP_ALIGN.RIGHT
    r = p.add_run(); r.text = text + '   |   ' + str(PAGE[0])
    r.font.size = Pt(9); r.font.color.rgb = GRAY; r.font.name = FONT

FOOT = 'coralnpu RISC-V NPU 上板验证与性能评估'
'''

FOOTER = '''
out = r"__OUT__"
prs.save(out)
print('已生成:', out, '页数:', len(prs.slides._sldIdLst))
'''


def parse_md(text):
    """解析 Markdown → (yaml, pages)；page blocks: (kind, ...) 按出现顺序"""
    m = re.match(r'^---\n(.*?)\n---\n', text, re.S)
    yaml = {}
    if m:
        for line in m.group(1).splitlines():
            if ':' in line:
                k, v = line.split(':', 1)
                yaml[k.strip()] = v.strip().strip('"')
        text = text[m.end():]
    pages = []
    cur = None
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.startswith('# '):
            if cur:
                pages.append(cur)
            cur = {'title': ln[2:].strip(), 'blocks': []}
            i += 1
            continue
        if cur is None:
            i += 1
            continue
        mf = re.match(r'^\[图:([a-z_]+)\]', ln.strip())
        if mf:
            cur['blocks'].append(('fig', mf.group(1)))
            i += 1
            continue
        if ln.strip().startswith('|'):
            rows = []
            while i < len(lines) and lines[i].strip().startswith('|'):
                if not re.match(r'^[\s\-:|]+$', lines[i].strip().strip('|')):
                    rows.append([c.strip() for c in lines[i].strip().strip('|').split('|')])
                i += 1
            if rows:
                cur['blocks'].append(('table', rows[0], rows[1:]))
            continue
        if re.match(r'^\s*-\s+', ln):
            items = []
            while i < len(lines) and re.match(r'^\s*-\s+', lines[i]):
                indent = len(lines[i]) - len(lines[i].lstrip())
                items.append((re.sub(r'^\s*-\s+', '', lines[i]).strip(), 1 if indent >= 2 else 0))
                i += 1
            cur['blocks'].append(('bullets', items))
            continue
        if ln.strip().startswith('>'):
            cur['blocks'].append(('quote', ln.strip().lstrip('>').strip()))
            i += 1
            continue
        i += 1
    if cur:
        pages.append(cur)
    return yaml, pages


def py_str(s):
    return repr(s)


def gen_py(yaml, pages, out_py, out_pptx_name):
    code = [HEADER]
    for name in sorted(set(b[1] for p in pages for b in p['blocks'] if b[0] == 'fig')):
        code.append(FIGURES.get(name, f'def draw_{name}(s):\n    pass\n'))
    code.append('\n# ===== 封面 =====')
    title = yaml.get('title', '')
    core = yaml.get('core', yaml.get('subtitle', ''))
    platform = yaml.get('platform', '')
    date = yaml.get('date', '')
    code.append(f'''
s = prs.slides.add_slide(BLANK)
bg = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, prs.slide_width, prs.slide_height)
bg.fill.solid(); bg.fill.fore_color.rgb = DARK; bg.line.fill.background()
tb = s.shapes.add_textbox(Inches(1.0), Inches(2.3), Inches(11.3), Inches(1.6))
p = tb.text_frame.paragraphs[0]; p.alignment = PP_ALIGN.CENTER
r = p.add_run(); r.text = {py_str(title)}
r.font.size = Pt(40); r.font.bold = True; r.font.color.rgb = WHITE; r.font.name = FONT
tb2 = s.shapes.add_textbox(Inches(0.8), Inches(4.2), Inches(11.7), Inches(1.8))
tf2 = tb2.text_frame
for i, t in enumerate([{py_str(core)}, {py_str(platform)}, {py_str(date)}]):
    p = tf2.paragraphs[0] if i == 0 else tf2.add_paragraph()
    p.alignment = PP_ALIGN.CENTER; p.space_after = Pt(6)
    r = p.add_run(); r.text = t; r.font.size = Pt(16); r.font.color.rgb = RGBColor(0xC8,0xD8,0xE8); r.font.name = FONT
''')
    for p in pages:
        title = p['title']
        code.append(f'\n# ===== {title} =====')
        code.append(f's = slide({py_str(title)})')
        y = 1.25
        has_fig = any(b[0] == 'fig' for b in p['blocks'])
        for blk in p['blocks']:
            kind = blk[0]
            if kind == 'fig':
                code.append(f'draw_{blk[1]}(s)')
                y = FIG_BOTTOM.get(blk[1], 3.7) + 0.15
            elif kind == 'bullets':
                items = blk[1]
                n = len(items)
                if has_fig:
                    size = 16 if n <= 3 else 15 if n <= 5 else 14
                else:
                    size = 20 if n <= 3 else 18 if n <= 5 else 16 if n <= 7 else 14
                code.append('bullets(s, [')
                for t, lvl in items:
                    code.append(f'    ({py_str(t)}, {lvl}),')
                code.append(f'], top={y:.2f}, size={size})')
                y += 0.55 * n + 0.30
            elif kind == 'table':
                rows_n = len(blk[2])
                fs = 14 if rows_n <= 5 else 13 if rows_n <= 7 else 12
                h = min(0.52 * (rows_n + 1) + 0.2, 5.4)
                code.append(f'table(s, {py_str(blk[1])}, {py_str(blk[2])}, top={y:.2f}, height={h:.2f}, fs={fs})')
                y += h + 0.15
            elif kind == 'quote':
                code.append(f'bullets(s, [({py_str(blk[1])}, 1)], top={y:.2f}, size=13, height=0.42)')
                y += 0.42
        code.append(f'footer(s, FOOT)')
    code.append(FOOTER.replace('__OUT__', out_pptx_name))
    with open(out_py, 'w') as f:
        f.write('\n'.join(code))
    print('已生成脚本:', out_py)


def main():
    if len(sys.argv) < 2:
        print('用法: python md2ppt.py <deck.md> [out.pptx]')
        sys.exit(1)
    md = sys.argv[1]
    out_pptx = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.abspath('report.pptx')
    out_py = os.path.join(os.path.dirname(out_pptx), 'gen.py')   # 生成的脚本与 pptx 同目录（.work/ppt/）
    yaml, pages = parse_md(open(md, encoding='utf-8').read())
    gen_py(yaml, pages, out_py, out_pptx)


if __name__ == '__main__':
    main()
