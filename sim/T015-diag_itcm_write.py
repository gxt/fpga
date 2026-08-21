#!/usr/bin/env python3
# =============================================================================
# diag_itcm_write.py —— 排查上板 host W 写 ITCM SLVERR 根因
# 诊断：复位后核状态 + CSR_CTRL 保持核复位后写 ITCM 是否稳定
# =============================================================================
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"
BAUD = 115200

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

def r_word(s, addr):
    buf = send_cmd(s, f"R{addr:08X}01\n")
    try:
        if len(buf) >= 16:
            return int(buf[8:16], 16)
    except ValueError:
        pass
    return None

def main():
    s = serial.Serial(PORT, BAUD, timeout=1)
    time.sleep(2.0)   # 复位后等待稳定
    s.reset_input_buffer()

    # 0) UART 通路（重试直到稳定）
    ok_uart = False
    for attempt in range(5):
        r = send_cmd(s, "?\n")
        if b"HELP" in r:
            ok_uart = True
            print("UART 通路 OK")
            break
        print(f"UART 未稳定，重试 {attempt+1}/5: {r!r}")
        time.sleep(1.0)
    if not ok_uart:
        print("FAIL: UART 持续不稳定（检查复位/接线）")
        return 1

    # 2) 读复位后核状态
    ctrl = r_word(s, 0x30000)
    status = r_word(s, 0x30008)
    pc = r_word(s, 0x30004)
    print(f"复位后 CSR: CTRL=0x{ctrl:08X} STATUS=0x{status:08X} PC_START=0x{pc:08X}"
          if ctrl is not None else "CSR 读失败（需复位）")

    # 3) 写 CSR_CTRL=1（bit0=1 保持核复位 + bit1=0 关时钟门控 = 时钟开、核不取指）
    #    （复位后 resetReg=3：bit0 reset + bit1 cg on，时钟被门控；写 1 关门控开时钟）
    r = w_cmd(s, 0x30000, 1)
    print(f"写 CTRL=1（时钟开、核复位保持）: {r!r}")
    time.sleep(0.5)

    # 4a) 连续 W 写 DTCM（对照）
    ok = 0
    for i in range(16):
        addr = 0x10000 + i * 4
        r = w_cmd(s, addr, 0xA0000000 | i)
        if b"OK" in r:
            ok += 1
        else:
            print(f"W DTCM 0x{addr:08X} FAIL: {r!r}")
            break
        time.sleep(0.05)
    print(f"CTRL=1 后连续 W 写 DTCM 成功: {ok}/16")
    time.sleep(0.5)

    # 4b) 连续 W 写 ITCM（CTRL=1 时钟开、核复位 → 应稳定）
    ok = 0
    for i in range(16):
        addr = i * 4
        r = w_cmd(s, addr, i + 1)
        if b"OK" in r:
            ok += 1
        else:
            print(f"W ITCM 0x{addr:08X} FAIL: {r!r}")
            break
        time.sleep(0.05)
    print(f"CTRL=1 后连续 W 写 ITCM 成功: {ok}/16")

    # 5) R 读回 ITCM 前 4 字
    for i in range(4):
        v = r_word(s, i * 4)
        print(f"R ITCM[0x{i*4:02X}] = 0x{v:08X}" if v is not None else f"R ITCM[0x{i*4:02X}] 失败")
    s.close()
    print("诊断完成")
    return 0

if __name__ == "__main__":
    sys.exit(main())
