#!/usr/bin/env python3
# T024 评测框架 —— 批量加载 RVV ELF + HALTED + 周期回读（201 上板）
# 用法: python3 bench_rvv.py <elf列表文件> [cycle_addr]
#   cycle_addr: 有 csr_cycle_count 的 ELF 的周期地址（hex），无则不回读
# 输出: 每 ELF 一行 <名> <PASS/FAIL> <加载耗时s> <执行ms> <cycles(若有)>
import sys; sys.path.insert(0, '/home/gxt/fpga/tests')
from load_elf_uart import parse_elf_loads
import serial, time, struct, os, subprocess

serial_port = '/dev/ttyUSB0'
s = serial.Serial(serial_port, 115200, timeout=0.5)
time.sleep(0.3); s.reset_input_buffer()

def send_cmd(cmd, expect=b"OK", timeout=2.0):
    s.reset_input_buffer(); s.write(cmd.encode()); s.flush()
    buf=b""; t0=time.time()
    while time.time()-t0<timeout:
        n=s.in_waiting
        if n:
            buf+=s.read(n)
            if expect in buf: return buf
        else: time.sleep(0.002)
    return buf

def r_word(addr):
    r=send_cmd(f"R{addr:08X}01\n")
    try: return int(r[8:16],16)
    except: return None

def w_word(addr, data):
    return send_cmd(f"W{addr:08X}{data:08X}\n")

# CLINT 定时器（wfi 唤醒用）
CLINT_MTIME_LO, CLINT_MTIME_HI = 0x0200BFF8, 0x0200BFFC
CLINT_MTIMECMP_LO = 0x02004000

def reset_core():
    # 1) wfi 唤醒：写 CLINT MTIMECMP 触发定时器中断 → 核退出时钟门控（否则 wfi 后 host 写卡）
    # 2) 复位并保持核复位（CTRL=1 不释放）：加载时核不运行（不占用 TCM 仲裁），
    #    加载完由 S 命令释放启动。
    s.reset_input_buffer()
    mt = r_word(CLINT_MTIME_LO)
    mth = r_word(CLINT_MTIME_HI)
    if mt is not None:
        w_word(CLINT_MTIMECMP_LO, (mt + 1000) & 0xFFFFFFFF)
        w_word(CLINT_MTIMECMP_LO + 4, mth)
    time.sleep(0.2)
    send_cmd("W0003000000000001\n")  # CTRL=1 保持复位
    time.sleep(0.2)
    while s.in_waiting: s.read(s.in_waiting)

def try_load(elf):
    try:
        loads = parse_elf_loads(elf)
    except Exception as e:
        return f"{os.path.basename(elf)} LOAD_ERR"
    total=0
    for vaddr, blob in loads:
        if not (0 <= vaddr < 0x2000 or 0x10000 <= vaddr < 0x18000):
            return None  # 非 TCM 段，跳过
        for i in range(0, len(blob), 4):
            w=struct.unpack("<I", blob[i:i+4].ljust(4,b'\x00'))[0]
            addr=vaddr+i
            ok=False
            for _ in range(3):
                r=send_cmd(f"W{addr:08X}{w:08X}\n")
                if b"OK" in r:
                    ok=True; break
                time.sleep(0.05)
            if not ok:
                return f"W_FAIL@0x{addr:08X}"   # 返回失败原因
            total+=1; time.sleep(0.002)
    return total

def load_and_run(elf, cycle_addr=None):
    name=os.path.basename(elf)
    for attempt in range(3):   # 失败自动重试（reset + reload）
        ld = try_load(elf)
        if ld is None:  # 非 TCM 段
            return None
        if isinstance(ld, str):
            print(f"  [{ld}] {name} 第{attempt+1}次重试...", flush=True)
            reset_core()
            continue
        t_send=time.time()
        r=send_cmd("S\n")
        halted=False; cycles=None
        for _ in range(200):   # 20s 轮询（长运行程序预留）
            st=r_word(0x30008)
            if st is not None and st&1:
                halted=True; break
            time.sleep(0.1)
        exec_ms=(time.time()-t_send)*1000
        if not halted:
            print(f"  [未HALTED] {name} 第{attempt+1}次...", flush=True)
            continue   # 重试
        if cycle_addr is not None:
            cycles=r_word(cycle_addr)
        status="PASS"
        return f"{name} {status} 加载{time.time()-t_send:.2f}s 执行{exec_ms:.0f}ms" + (f" cycles={cycles}" if cycles is not None else "")
    return f"{name} FAIL(3次重试)"

def load_and_smoke(elf):
    """smoke 模式：wfi 类用例——加载成功 + S 启动即通过（不轮询 HALTED，程序用 wfi 结束）"""
    name=os.path.basename(elf)
    for attempt in range(3):
        ld = try_load(elf)
        if ld is None:
            return None
        if isinstance(ld, str):
            print(f"  [{ld}] {name} 第{attempt+1}次重试...", flush=True)
            reset_core()
            continue
        t0=time.time()
        r=send_cmd("S\n")
        time.sleep(0.3)   # 让程序跑一小段（确认核启动无 fault）
        st=r_word(0x30008)
        # 核应处于运行/完成状态：STATUS bit0=0（未 halted）或 wfi；bit1=1 是 fault
        fault = (st is not None and (st & 2))
        if not fault:
            return f"{name} PASS 加载{time.time()-t0:.2f}s (smoke)"
        print(f"  [FAULT] {name} 第{attempt+1}次...", flush=True)
        reset_core()
    return f"{name} FAIL(smoke 3次)"

def get_cycle_addr(elf):
    """用 readelf 查 csr_cycle_count 符号地址（有则性能模式，无则 smoke）"""
    try:
        out = subprocess.check_output(['readelf','-s',elf], stderr=subprocess.DEVNULL).decode()
        for line in out.split('\n'):
            if 'csr_cycle_count' in line:
                parts = line.split()
                if len(parts) > 1:
                    return int(parts[1], 16)
    except Exception:
        pass
    return None

def main():
    elflist=sys.argv[1]
    with open(elflist) as f:
        elfs=[l.strip() for l in f if l.strip()]
    for elf in elfs:
        ca = get_cycle_addr(elf)
        if ca is not None:
            res = load_and_run(elf, ca)   # 性能模式（matmul/gemma 有周期计数）
        else:
            res = load_and_smoke(elf)     # smoke 模式（wfi 类）
        if res: print(res, flush=True)
    print("==> 评测完成")

if __name__=="__main__":
    main()
