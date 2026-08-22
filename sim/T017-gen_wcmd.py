#!/usr/bin/env python3
# =============================================================================
# gen_wcmd.py —— 解析 RISC-V ELF 生成 UART W 命令文件（供 xsim tb 加载）
# 用法: python3 gen_wcmd.py <elf> <out_wcmd>
# 输出: 每行 "W<8hex addr><8hex data>\n"（ITCM/DTCM 段，跳过 .bss 零填充）
# =============================================================================
import struct, sys

def parse_elf_loads(path):
    with open(path, "rb") as f:
        data = f.read()
    e_phoff   = struct.unpack_from("<I", data, 28)[0]
    e_phentsz = struct.unpack_from("<H", data, 42)[0]
    e_phnum   = struct.unpack_from("<H", data, 44)[0]
    loads = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsz
        p_type, p_off, p_vaddr, _, p_filesz, p_memsz = struct.unpack_from("<IIIIII", data, off)
        if p_type == 1 and p_filesz > 0:
            loads.append((p_vaddr, p_filesz, p_memsz, data[p_off:p_off + p_filesz]))
    return loads

def main():
    elf, out = sys.argv[1], sys.argv[2]
    loads = parse_elf_loads(elf)
    print(f"LOAD 段: {[(hex(v), hex(f), hex(m)) for v, f, m, _ in loads]}")
    cmds = []
    for vaddr, filesz, memsz, blob in loads:
        for i in range(0, filesz, 4):
            word = blob[i:i + 4]
            wdata = struct.unpack("<I", word.ljust(4, b"\x00"))[0]
            cmds.append(f"W{vaddr + i:08X}{wdata:08X}\n")
        # .bss 段（filesz..memsz）跳过：上电默认 0，无需写
        print(f"  段 0x{vaddr:08X}: filesz=0x{filesz:X} → {filesz//4} 字, bss=0x{memsz - filesz:X}")
    with open(out, "w") as f:
        f.writelines(cmds)
    print(f"命令文件已生成: {out}（{len(cmds)} 条 W 命令）")

if __name__ == "__main__":
    main()
