#!/usr/bin/env python3
# =============================================================================
# debug_write_tcm.py —— T016 阶段 B: 上板经 UART 发 Debug 命令写 ITCM 验证
#
# 用法: python3 debug_write_tcm.py [port]
#   port  串口（默认 /dev/ttyUSB0，115200）
#
# Dbg 协议（CoreAxiCSR）：
#   0x30800=DbgReqAddr（写 Debug 内部偏移） 0x30804=DbgReqData
#   0x30808=DbgReqOp（1=READ 2=WRITE 触发） 0x30810=DbgRspData 0x30814=DbgStatus(写清队列)
# Debug 内部偏移：Data0=0x4 Data1=0x5 Dmcontrol=0x10 Abstractcs=0x16 Command=0x17
# =============================================================================
import serial, sys, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB0"
BAUD = 115200

def send_cmd(s, cmd, timeout=3.0):
    s.reset_input_buffer()
    s.write(cmd.encode())
    s.flush()
    buf = b""
    t0 = time.time()
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
    # 解析 "<8hexaddr><8hexdata>\nOK\n"
    try:
        if len(buf) >= 16:
            return int(buf[8:16], 16)
    except ValueError:
        pass
    return None

def dbg_reg(s, reg_off, data, is_write):
    """经 Dbg 寄存器访问 Debug 内部寄存器"""
    r1 = w_cmd(s, 0x30800, reg_off)          # DbgReqAddr
    if is_write:
        r2 = w_cmd(s, 0x30804, data)          # DbgReqData
    r3 = w_cmd(s, 0x30808, 2 if is_write else 1)  # DbgReqOp WRITE/READ 触发
    rd = None
    if not is_write:
        rd = r_word(s, 0x30810)               # DbgRspData
    r4 = w_cmd(s, 0x30814, 0)                 # 写 DbgStatus 清响应队列
    return rd

def main():
    s = serial.Serial(PORT, BAUD, timeout=1)
    time.sleep(0.3)
    s.reset_input_buffer()

    # 0) UART 通路
    r = send_cmd(s, "?\n")
    if b"HELP" not in r:
        print("FAIL: UART 无响应", r)
        return 1
    print("UART 通路 OK")

    # 1) halt 核：Dmcontrol(0x10) = 0x80000001（haltreq+dmactive）
    dbg_reg(s, 0x10, 0x80000001, True)
    time.sleep(1.0)
    # 读 Dmstatus(0x11) 确认 halted（allhalted）
    dms = dbg_reg(s, 0x11, 0, False)
    print(f"halt: Dmcontrol 写入，Dmstatus=0x{dms:08X} (allhalted={1 if dms and dms & 0x80000000 else 0})" if dms is not None else "halt: Dmstatus 读回失败")

    # 2) Debug 写 ITCM[0x0] = 0xDEADBEEF（Access Memory write）
    for cmd in [(0x4, 0xDEADBEEF), (0x5, 0x00000000), (0x17, 0x02230000)]:
        dbg_reg(s, cmd[0], cmd[1], True)
        time.sleep(0.1)
    time.sleep(1.0)
    # 读 Abstractcs(0x16) cmderr 诊断
    acs = dbg_reg(s, 0x16, 0, False)
    print(f"Abstractcs=0x{acs:08X} (busy={1 if acs and acs&1 else 0} cmderr={((acs>>8)&7) if acs else -1})" if acs is not None else "Abstractcs 读回失败")
    print("Debug 写 ITCM[0x0] = DEADBEEF 完成")

    # 3) R 命令读回验证（重试）
    got = None
    for _ in range(3):
        got = r_word(s, 0x00000000)
        if got is not None:
            break
        time.sleep(0.5)
    print(f"R 读回 ITCM[0x0] = {got:08X}" if got is not None else "R 读回失败")
    ok = (got == 0xDEADBEEF)

    # 4) Debug 写 ITCM[0x4] = 0xCAFEBABE，R 读回
    for cmd in [(0x4, 0xCAFEBABE), (0x5, 0x00000004), (0x17, 0x02230000)]:
        dbg_reg(s, cmd[0], cmd[1], True)
        time.sleep(0.1)
    time.sleep(1.0)
    got4 = None
    for _ in range(3):
        got4 = r_word(s, 0x00000004)
        if got4 is not None:
            break
        time.sleep(0.5)
    print(f"R 读回 ITCM[0x4] = {got4:08X}" if got4 is not None else "R 读回失败")
    ok = ok and (got4 == 0xCAFEBABE)

    s.close()
    print("T016-B:", "ALL PASS" if ok else "FAIL")
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
