#!/usr/bin/env python3
# =============================================================================
# load_elf_uart.py —— T015: 经 UART host 通路加载 ELF 到 TCM 并运行、回读验证
#
# 用法: python3 load_elf_uart.py <elf> [port]
#   elf   待加载的 RISC-V ELF（如 sim/build/t007_scalar_fp_test.elf）
#   port  串口设备（默认 /dev/ttyUSB0）
#
# 流程: 解析 ELF LOAD 段 → W 命令逐 32 位字写 TCM（ITCM/DTCM）→ S 启动
#       → Q 轮询 CSR_STATUS(0x30008) bit0=HALTED=1 → R 回读结果数组比对
# =============================================================================
import serial, struct, sys, time

DEFAULT_PORT = "/dev/ttyUSB0"
CSR_STATUS   = 0x30008  # bit0=HALTED

def parse_elf_loads(path):
    with open(path, "rb") as f:
        data = f.read()
    e_phoff   = struct.unpack_from("<I", data, 28)[0]
    e_phentsz = struct.unpack_from("<H", data, 42)[0]
    e_phnum   = struct.unpack_from("<H", data, 44)[0]
    loads = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsz
        p_type, p_off, p_vaddr, _, p_filesz, _ = struct.unpack_from("<IIIIII", data, off)
        if p_type == 1 and p_filesz > 0:  # PT_LOAD
            loads.append((p_vaddr, data[p_off:p_off + p_filesz]))
    return loads

def send_cmd(s, cmd, expect=b"OK", timeout=2.0):
    s.reset_input_buffer()
    s.write(cmd.encode())
    s.flush()
    buf = b""
    t0 = time.time()
    while time.time() - t0 < timeout:
        chunk = s.read(256)
        if chunk:
            buf += chunk
            if expect and expect in buf:
                return buf
        else:
            time.sleep(0.02)
    return buf

def main():
    elf = sys.argv[1] if len(sys.argv) > 1 else "sim/build/t007_scalar_fp_test.elf"
    port = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_PORT
    loads = parse_elf_loads(elf)
    print(f"ELF LOAD 段: {[(hex(v), hex(len(b))) for v, b in loads]}")

    s = serial.Serial(port, 115200, timeout=0.5)
    time.sleep(0.3)
    s.reset_input_buffer()

    # 0) 确认 UART 通路
    r = send_cmd(s, "?\n")
    if b"HELP" not in r:
        print(f"FAIL: UART 无响应 {r}")
        return 1
    print("UART 通路 OK (?)")

    # 1) 加载 ELF LOAD 段（逐 32 位字 W 命令；失败重试 + 写入间隔）
    total_words = 0
    for vaddr, blob in loads:
        for i in range(0, len(blob), 4):
            word = blob[i:i + 4]
            wdata = struct.unpack("<I", word.ljust(4, b"\x00"))[0]
            addr = vaddr + i
            ok = False
            for attempt in range(3):
                r = send_cmd(s, f"W{addr:08X}{wdata:08X}\n", timeout=3.0)
                if b"OK" in r:
                    ok = True
                    break
                time.sleep(0.05)
            if not ok:
                print(f"FAIL: W 写 0x{addr:08X} 响应 {r!r}（3 次重试失败）")
                return 1
            total_words += 1
            time.sleep(0.015)  # 15ms 间隔防 host 处理不过来
    print(f"加载完成: {total_words} 字")

    # 2) S 启动
    r = send_cmd(s, "S\n")
    print(f"S 启动响应: {r!r}")

    # 3) Q 轮询 HALTED（最多 100 次 / 10s）
    halted = False
    for _ in range(100):
        r = send_cmd(s, "Q\n")
        if len(r) >= 9 and r[:8].lower() == f"{CSR_STATUS:08x}".lower():
            status = int(r[8:16], 16)
            if status & 1:
                halted = True
                print(f"HALTED 确认: {r!r}")
                break
        time.sleep(0.1)
    if not halted:
        print("FAIL: 核未进入 HALTED")
        return 1

    # 4) 回读结果数组（R 命令）比对（T007 scalar 预期）
    checks = {
        0x10030: [0x2BC, 0x640, 0xA8C, 0xFA0],        # out_mul = {700,1600,2700,4000}
        0x10000: [0x40000000, 0x40400000, 0x40A00000, 0x40E00000],  # fout = {2.0,3.0,5.0,7.0}
    }
    all_ok = True
    for base, exp in checks.items():
        r = send_cmd(s, f"R{base:08X}04\n")
        # 响应格式: 每字一行 "<addr><data>\n"，结尾 OK
        lines = r.split(b"\n")
        got = []
        for ln in lines:
            if len(ln) == 16:
                try:
                    got.append(int(ln[8:16], 16))
                except ValueError:
                    pass
        status = "PASS" if got == exp else "FAIL"
        if got != exp:
            all_ok = False
        print(f"{status}: 0x{base:08X} 预期={[hex(x) for x in exp]} 实测={[hex(x) for x in got]}")
    s.close()
    print("T015 验证完成:", "ALL PASS" if all_ok else "有 FAIL")
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())
