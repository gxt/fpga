#!/usr/bin/env python3
# q_raw_probe.py —— 打印 Q 命令原始响应（诊断 load_elf Q 轮询判定）
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"

def main():
    s = serial.Serial(PORT, 115200, timeout=1)
    time.sleep(1.5)
    s.reset_input_buffer()

    def cmd(c, t=2.0):
        s.reset_input_buffer()
        s.write(c.encode()); s.flush()
        buf = b""; t0 = time.time()
        while time.time() - t0 < t:
            cc = s.read(256)
            if cc:
                buf += cc
                if b"OK" in buf or b"ERR" in buf:
                    return buf
            else:
                time.sleep(0.02)
        return buf

    for i in range(3):
        r = cmd("Q\n")
        print(f"Q[{i}] 原始: {r!r}")
        time.sleep(0.5)
    s.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())
