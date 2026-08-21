#!/usr/bin/env python3
# uart_baud_probe.py —— 探测 FPGA 实际 TX 波特率（反推 clk_core）
# FPGA TX DIV_tx = 347（假定 40M）→ TX baud = clk_core/347
# 用不同波特率收 '?' 的 HELP，HELP 率最高的接近 FPGA TX 波特率
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"
BAUDS = [96000, 100000, 105000, 110000, 113636, 115200, 119048, 122000, 125000, 128000]

def main():
    for baud in BAUDS:
        try:
            s = serial.Serial(PORT, baud, timeout=1)
        except Exception as e:
            print(f"{baud}: open fail {e}")
            continue
        time.sleep(0.5)
        s.reset_input_buffer()
        ok = 0
        for _ in range(6):
            s.write(b"?\n"); s.flush()
            buf = b""; t0 = time.time()
            while time.time() - t0 < 0.8:
                c = s.read(256)
                if c:
                    buf += c
                    if b"HELP" in buf or b"ERR" in buf:
                        break
            if b"HELP" in buf:
                ok += 1
        s.close()
        print(f"波特率 {baud}: HELP {ok}/6  响应样本: {buf[:12]!r}")

if __name__ == "__main__":
    main()
