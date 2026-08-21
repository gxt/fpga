#!/usr/bin/env python3
# uart_raw_probe.py —— UART 原始稳定性测试（不发 TCM 命令）
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"

def cmd(s, c, t=1.5):
    s.reset_input_buffer()
    s.write(c.encode()); s.flush()
    buf = b""; t0 = time.time()
    while time.time() - t0 < t:
        cc = s.read(256)
        if cc:
            buf += cc
            if b"OK" in buf or b"ERR" in buf or b"HELP" in buf:
                return buf
        else:
            time.sleep(0.02)
    return buf

def main():
    s = serial.Serial(PORT, 115200, timeout=1)
    time.sleep(2.0)
    s.reset_input_buffer()

    print("=== 20x '?' 命令 ===")
    ok = 0
    for i in range(20):
        r = cmd(s, "?\n")
        tag = "HELP" if b"HELP" in r else ("ERR" if b"ERR" in r else ("NONE" if not r else "RAW:%r" % r[:20]))
        if tag == "HELP": ok += 1
        print(f"{i+1}: {tag}")
    print(f"? HELP 率: {ok}/20")

    print("=== 20x 'W0000000000000001' 简单写 ===")
    ok = 0
    for i in range(20):
        r = cmd(s, "W0000000000000001\n")
        tag = "OK" if b"OK" in r else ("ERR" if b"ERR" in r else ("NONE" if not r else "RAW:%r" % r[:20]))
        if tag == "OK": ok += 1
        print(f"{i+1}: {tag}")
    print(f"W 写 OK 率: {ok}/20")
    s.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())
