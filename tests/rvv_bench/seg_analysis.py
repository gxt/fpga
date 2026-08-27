#!/usr/bin/env python3
# T024 段统计 —— 分析 621 个 RVV ELF 的 ITCM/DTCM 占用，筛选默认 TCM（8K/32K）能跑的
import struct, glob, os, json

# 按 vaddr 分区（与 coralnpu 默认 TCM 一致）
ITCM_LO, ITCM_HI = 0x0, 0x2000      # 8KB
DTCM_LO, DTCM_HI = 0x10000, 0x18000 # 32KB

def parse_loads(path):
    with open(path, 'rb') as f:
        d = f.read()
    e_phoff = struct.unpack_from('<I', d, 28)[0]
    e_phentsz = struct.unpack_from('<H', d, 42)[0]
    e_phnum = struct.unpack_from('<H', d, 44)[0]
    loads = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsz
        p_type, p_off, p_vaddr, _, p_filesz, p_memsz = struct.unpack_from('<IIIIII', d, off)
        if p_type == 1 and p_memsz > 0:
            loads.append((p_vaddr, p_memsz, p_filesz))
    return loads

results = []
for elf in sorted(glob.glob('/home/gxt/fpga/coralnpu/bazel-bin/tests/cocotb/rvv/**/*.elf', recursive=True)):
    loads = parse_loads(elf)
    itcm = sum(m for v, m, f in loads if ITCM_LO <= v < ITCM_HI)
    dtcm = sum(m for v, m, f in loads if DTCM_LO <= v < DTCM_HI)
    other = [(hex(v), m) for v, m, f in loads if not (ITCM_LO <= v < ITCM_HI or DTCM_LO <= v < DTCM_HI)]
    name = elf.split('cocotb/rvv/')[-1].replace('.elf', '')
    results.append((name, itcm, dtcm, other))

# 统计
fit = [r for r in results if r[1] <= 0x2000 and r[2] <= 0x8000 and not r[3]]
over = [r for r in results if not (r[1] <= 0x2000 and r[2] <= 0x8000 and not r[3])]
print(f"总 ELF: {len(results)}，默认 TCM(8K/32K) 能跑: {len(fit)}，超限: {len(over)}")
print("\n=== 能跑（前 30）===")
for n, i, d, o in fit[:30]:
    print(f"  {n}: ITCM={i}B DTCM={d}B")
print(f"\n=== 超限原因分类（前 20）===")
for n, i, d, o in over[:20]:
    print(f"  {n}: ITCM={i}B DTCM={d}B 其他段={o}")
# 保存
json.dump({'fit': [{'name': n, 'itcm': i, 'dtcm': d} for n, i, d, o in fit],
           'over': [{'name': n, 'itcm': i, 'dtcm': d, 'other': o} for n, i, d, o in over]},
          open('/home/gxt/fpga/workspace/T024-first/elf_segments.json', 'w'), indent=1)
print("\n已保存 elf_segments.json")
