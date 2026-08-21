#!/usr/bin/env python3
# t007_result_check.py —— 回读 T007 结果数组验证
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"

def send_cmd(s, cmd, timeout=2.0):
    s.reset_input_buffer()
    s.write(cmd.encode()); s.flush()
    buf = b""; t0 = time.time()
    while time.time() - t0 < timeout:
        c = s.read(256)
        if c:
            buf += c
            if b"OK" in buf or b"ERR" in buf or b"HELP" in buf:
                return buf
        else:
            time.sleep(0.02)
    return buf

def main():
    s = serial.Serial(PORT, 115200, timeout=1)
    time.sleep(1.5)
    s.reset_input_buffer()
    r = send_cmd(s, "?\n")
    if b"HELP" not in r:
        print(f"UART 无响应 {r!r}"); return 1
    print("UART OK")

    checks = {
        0x10030: [0x2BC, 0x640, 0xA8C, 0xFA0],        # out_mul = {700,1600,2700,4000}
        0x10000: [0x40000000, 0x40400000, 0x40A00000, 0x40E00000],  # fout = {2.0,3.0,5.0,7.0}
    }
    all_ok = True
    for base, exp in checks.items():
        r = send_cmd(s, f"R{base:08X}04\n")
        lines = r.split(b"\n")
        got = []
        for ln in lines:
            if len(ln) == 16:
                try:
                    got.append(int(ln[8:16], 16))
                except ValueError:
                    pass
        ok = got == exp
        all_ok &= ok
        print(f"{'PASS' if ok else 'FAIL'}: 0x{base:08X} 预期={[hex(x) for x in exp]} 实测={[hex(x) for x in got]}")
    s.close()
    print("T007 结果:", "ALL PASS" if all_ok else "有 FAIL")
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())
