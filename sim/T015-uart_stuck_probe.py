#!/usr/bin/env python3
# =============================================================================
# uart_stuck_probe.py —— 区分直写卡死是 FSM 卡死还是 UART RX 挂死
# 连续 W 直写 ITCM 直到无响应，然后发 '?' 探测 FSM 是否存活
# =============================================================================
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"
BAUD = 115200

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
    s = serial.Serial(PORT, BAUD, timeout=1)
    time.sleep(2.0)
    s.reset_input_buffer()

    # UART 通路
    ok = False
    for _ in range(5):
        r = send_cmd(s, "?\n")
        if b"HELP" in r: ok = True; break
        time.sleep(1.0)
    print("UART OK" if ok else "UART FAIL")
    if not ok: return 1

    # 连续 W 直写直到卡
    print("--- 连续 W 直写 ITCM（0.05s）---")
    for i in range(32):
        addr = i * 4
        data = 0xA0000000 | i
        r = send_cmd(s, f"W{addr:08X}{data:08X}\n")
        if b"OK" in r:
            continue
        else:
            print(f"第 {i+1} 字 0x{addr:08X} 无响应: {r!r}")
            break
        time.sleep(0.05)
    else:
        print("32/32 全过")
        return 0

    # 卡后探测：发 '?'
    print("--- 卡死探测：发 '?' ---")
    r = send_cmd(s, "?\n", timeout=2.0)
    print(f"'?' 响应: {r!r}")
    if b"HELP" in r:
        print("==> FSM 存活！说明是连续 W 处理/特定路径卡，非全局卡死")
    else:
        print("==> '?' 也无响应 —— FSM 或 UART RX 全局挂死")

    # 再探测：直接发 W 简单命令
    r = send_cmd(s, "W0000000000000001\n", timeout=2.0)
    print(f"W 简单命令响应: {r!r}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
