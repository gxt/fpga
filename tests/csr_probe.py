#!/usr/bin/env python3
# csr_probe.py —— 读核状态 CSR：CTRL(0x30000)/PC(0x30004)/STATUS(0x30008)
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

def r_word(s, addr):
    buf = send_cmd(s, f"R{addr:08X}01\n")
    if buf and len(buf) >= 16:
        try:
            return int(buf[8:16], 16)
        except ValueError:
            return None
    return None

def main():
    s = serial.Serial(PORT, 115200, timeout=1)
    time.sleep(2.0)
    s.reset_input_buffer()

    ctrl = r_word(s, 0x30000)
    status = r_word(s, 0x30008)
    pc = r_word(s, 0x30004)
    print(f"当前: CTRL=0x{ctrl:08X} STATUS=0x{status:08X} PC=0x{pc:08X}"
          if ctrl is not None else "CSR 读失败")

    # 手动 S 启动序列（若未启动）
    print("--- 发 S ---")
    r = send_cmd(s, "S\n")
    print(f"S: {r!r}")
    time.sleep(0.5)

    ctrl = r_word(s, 0x30000)
    status = r_word(s, 0x30008)
    pc = r_word(s, 0x30004)
    print(f"S后: CTRL=0x{ctrl:08X} STATUS=0x{status:08X} PC=0x{pc:08X}"
          if ctrl is not None else "CSR 读失败")

    time.sleep(1.0)
    ctrl = r_word(s, 0x30000)
    status = r_word(s, 0x30008)
    pc = r_word(s, 0x30004)
    print(f"1s后: CTRL=0x{ctrl:08X} STATUS=0x{status:08X} PC=0x{pc:08X}"
          if ctrl is not None else "CSR 读失败")
    s.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())
