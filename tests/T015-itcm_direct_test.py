#!/usr/bin/env python3
# =============================================================================
# itcm_direct_test.py —— 复位后直接测 host_tcm 直写 ITCM（不碰 CSR）
# 验证方案 A：直写绕过 AXI，连续写 ITCM 是否全过 + R 读回
# =============================================================================
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"
BAUD = 115200
N = int(sys.argv[2]) if len(sys.argv) > 2 else 16
INTERVAL = float(sys.argv[3]) if len(sys.argv) > 3 else 0.05

def send_cmd(s, cmd, timeout=2.0):
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

def r_word(s, addr):
    buf = send_cmd(s, f"R{addr:08X}01\n")
    if buf and len(buf) >= 16:
        try:
            return int(buf[8:16], 16)
        except ValueError:
            return None
    return None

def main():
    s = serial.Serial(PORT, BAUD, timeout=1)
    time.sleep(2.0)
    s.reset_input_buffer()

    ok_uart = False
    for attempt in range(5):
        r = send_cmd(s, "?\n")
        if b"HELP" in r:
            ok_uart = True
            break
        time.sleep(1.0)
    if not ok_uart:
        print("FAIL: UART 通路不稳定")
        return 1
    print("UART 通路 OK")

    print(f"--- 直写 ITCM 连续 {N} 字（间隔 {INTERVAL}s）---")
    ok = 0
    fail_at = -1
    for i in range(N):
        addr = i * 4
        data = 0xA0000000 | i
        r = w_cmd(s, addr, data)
        if b"OK" in r:
            ok += 1
        else:
            fail_at = i
            print(f"W ITCM 0x{addr:08X} FAIL: {r!r}")
            break
        time.sleep(INTERVAL)
    print(f"直写 ITCM 成功: {ok}/{N}" + ("" if ok == N else f"（第 {fail_at+1} 字失败）"))

    print("--- R 读回验证（走 AXI 读）---")
    ok_read = 0
    for i in range(min(ok, N)):
        addr = i * 4
        v = r_word(s, addr)
        if v is not None:
            match = "OK" if v == (0xA0000000 | i) else f"MISMATCH(0x{v:08X})"
            ok_read += 1 if v == (0xA0000000 | i) else 0
            print(f"R ITCM[0x{addr:02X}] = 0x{v:08X} {match}")
        else:
            print(f"R ITCM[0x{addr:02X}] 失败")
        time.sleep(INTERVAL)
    print(f"读回一致: {ok_read}/{min(ok, N)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
