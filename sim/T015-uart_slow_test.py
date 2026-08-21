#!/usr/bin/env python3
# =============================================================================
# uart_slow_test.py —— 区分"速度/缓冲" vs "B 响应逻辑"的连续写实验
# 复位后以 100ms 间隔连续写 DTCM/ITCM，观察是否全 OK
# =============================================================================
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"
BAUD = 115200
INTERVAL = 0.1   # 100ms 命令间隔

def send_cmd(s, cmd, timeout=3.0):
    s.reset_input_buffer()
    s.write(cmd.encode()); s.flush()
    buf = b""; t0 = time.time()
    while time.time() - t0 < timeout:
        c = s.read(256)
        if c:
            buf += c
            if b"OK" in buf or b"ERR" in buf:
                return buf
        else:
            time.sleep(0.02)
    return buf

def w_cmd(s, addr, data):
    return send_cmd(s, f"W{addr:08X}{data:08X}\n")

def main():
    s = serial.Serial(PORT, BAUD, timeout=1)
    time.sleep(2.0)
    s.reset_input_buffer()
    # UART 稳定
    ok = False
    for _ in range(5):
        if b"HELP" in send_cmd(s, "?\n"):
            ok = True; break
        time.sleep(1.0)
    if not ok:
        print("UART 不稳定"); return 1
    print(f"UART OK，实验：{INTERVAL*1000:.0f}ms 间隔连续写")

    # 连续写 DTCM 16 字（100ms 间隔）
    okd = 0
    for i in range(16):
        addr = 0x10000 + i * 4
        r = w_cmd(s, addr, 0xA0000000 | i)
        if b"OK" in r: okd += 1
        else: print(f"W DTCM 0x{addr:08X} FAIL: {r!r}"); break
        time.sleep(INTERVAL)
    print(f"100ms 间隔写 DTCM: {okd}/16")

    # 连续写 ITCM 16 字
    time.sleep(0.5)
    oki = 0
    for i in range(16):
        addr = i * 4
        r = w_cmd(s, addr, i + 1)
        if b"OK" in r: oki += 1
        else: print(f"W ITCM 0x{addr:08X} FAIL: {r!r}"); break
        time.sleep(INTERVAL)
    print(f"100ms 间隔写 ITCM: {oki}/16")
    s.close()
    print("实验完成")
    return 0

if __name__ == "__main__":
    sys.exit(main())
