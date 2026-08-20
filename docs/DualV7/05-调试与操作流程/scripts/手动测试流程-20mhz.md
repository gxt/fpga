# DualV7 `rocket64z2m` 20MHz Bit 手动测试流程

**日期**：2026-05-18
**bit**：`workspace/070x/rocket64z2m-20mhz.bit`（55.9MB）
**SHA256**：`4581d346dd1ffcbdfb04f5e3ff2b23c010876b209d5d5e95ad509f7be40e87bb`

---

## 前置检查

```bash
# 1. UART
ls /dev/serial/by-id/usb-1a86_5523-if00-port0

# 2. hw_server
source /tools/Xilinx/2025.1/Vivado/settings64.sh
pgrep hw_server || hw_server -d &

# 3. NFS
sudo exportfs -v | grep busybox
# 预期: /home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot

# 4. TFTP
ss -ulnp | grep ':69'
# 预期: 0.0.0.0:69
ls -la /srv/tftp/Image
```

---

## Step 1：JTAG 下载 bit + boot.elf

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
xsdb workspace/070x/jtag-boot-20mhz.tcl
```

TCL 内容（`jtag-boot-20mhz.tcl`）：
```tcl
connect -url tcp:localhost:3121
targets 1
fpga -file /home/data/vivado-risc-v/workspace/070x/rocket64z2m-20mhz.bit
targets -set -filter {name =~ "Hart #0*"}
stop
dow -clear /home/data/vivado-risc-v/workspace/release-r2-hotfix/boot-r2.elf
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000
con
after 2000
exit
```

---

## Step 2：U-Boot 交互（手动）

### 2.1 打开串口

```bash
UART=/dev/serial/by-id/usb-1a86_5523-if00-port0
stty -F "$UART" 115200 raw -echo -echoe -echok
```

### 2.2 中断 autoboot

用 `picocom` 或 `cat` + `printf` 发送若干回车：

```bash
# 持续发送回车直到看到 => 提示符
for i in $(seq 1 10); do printf '\r' > "$UART"; sleep 0.3; done
```

或使用 `picocom` 交互式：
```bash
picocom -b 115200 "$UART"
# 在 3 秒倒计时内按回车
```

### 2.3 U-Boot 命令序列

```bash
# 设置网络
printf 'setenv ipaddr 192.168.200.250\r' > "$UART"; sleep 2
printf 'setenv serverip 192.168.200.201\r' > "$UART"; sleep 2

# 测试连通
printf 'ping 192.168.200.201\r' > "$UART"
# 等待输出 "host 192.168.200.201 is alive"（约5秒）

# TFTP 加载内核
printf 'tftpboot 0x81000000 Image\r' > "$UART"
# 等待输出 "Bytes transferred = 19769344"（约10秒）

# 设置 bootargs
printf "setenv bootargs 'earlycon console=ttyAU0,115200 root=/dev/nfs nfsroot=192.168.200.201:/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot,vers=3,tcp,rw ip=192.168.200.250:192.168.200.201::255.255.255.0:dualv7:eth0:off'\r" > "$UART"; sleep 2

# 启动内核
printf 'booti 0x81000000 - 0x10080\r' > "$UART"
```

### 2.4 抓取完整日志

```bash
LOG=workspace/dualv7-test/070x/uart-20mhz-manual.log
timeout 90 cat "$UART" > "$LOG" 2>&1 &
# 然后执行上述 U-Boot 命令
```

---

## Step 3：成功判据

| # | 判据 | 日志关键字 |
|---|------|----------|
| 1 | OpenSBI 启动 | `OpenSBI v1.7` |
| 2 | U-Boot 中断 | `=>` 提示符 |
| 3 | Ping 成功 | `host 192.168.200.201 is alive` |
| 4 | TFTP 完成 | `Bytes transferred = 19769344` |
| 5 | 内核启动 | `Starting kernel ...` |
| 6 | NFS root 挂载 | `VFS: Mounted root (nfs filesystem)` |
| 7 | BusyBox banner | `BusyBox v1.36.1` |
| 8 | Shell 交互 | `[~] #` 或 `#` 提示符 |
| 9 | 双核正常 | `Brought up 1 node, 2 CPUs` |

### 进入 BusyBox 后验证命令

```bash
printf 'mount\r' > "$UART"; sleep 1
printf 'ifconfig\r' > "$UART"; sleep 1
printf 'hostname\r' > "$UART"; sleep 1
printf 'cat /proc/net/dev\r' > "$UART"; sleep 1
```

---

## 一键脚本

本地一键 smoke 脚本：

```bash
bash workspace/070x/smoke-20mhz.sh
```

脚本内容：JTAG 下载 → 串口中断 → U-Boot 网络配置 → TFTP → booti → 等待 BusyBox → 发送验证命令 → 保存日志到 `workspace/dualv7-test/070x/uart-20mhz.log`

---

## 自动测试 Python 脚本参考

### 最相关：z2m BusyBox netboot（068x）

**文件**：`workspace/dualv7-test/068x/z2m_busybox_netboot.py`

**运行方法**：
```bash
cd /home/data/vivado-risc-v
python3 workspace/dualv7-test/068x/z2m_busybox_netboot.py
```

**特点**：纯 Python，无外部依赖。`os.open` + `select` 监控串口，按 stage 自动推进：
- Stage 0：自动发送 `\r` 打断 autoboot
- Stage 1：检测 `=>` 后发送 setenv + ping
- Stage 2：检测 ping 成功后发送 tftpboot
- Stage 3：检测 TFTP 完成后发送 bootargs + booti
- Stage 4：检测 BusyBox shell 后发送 mount/ifconfig 等验证命令

**注意**：此脚本假设 bit 已通过 xsdb 提前下载（不包含 JTAG 步骤）。

### 含 JTAG 的参考（20260516-jtag-boot-check）

**文件**：`workspace/dualv7-test/20260516-jtag-boot-check/uart_jtag_boot.py`

**运行方法**：
```bash
cd /home/data/vivado-risc-v
python3 workspace/dualv7-test/20260516-jtag-boot-check/uart_jtag_boot.py
```

**特点**：通过 `subprocess.Popen` 调用 `xsdb` 下载 bit+elf+Image+ramdisk，同时监控串口。

### 其他参考脚本

| 脚本 | 用途 |
|------|------|
| `063x/uart_attach_tftp_nfs_boot.py` | U-Boot TFTP → NFS root 自动化 |
| `063x/uart_uboot_tftp_nfs_boot.py` | 同上，含完整 U-Boot 命令 |
| `058x/run_nfs_check.py` | NFS mount 检查 |
| `20260516-ping-check/uboot_ping_check.py` | 仅 ping 检查 |

### 适配到 20MHz 测试

要复用 068x 脚本测试 20MHz bit，只需修改：
```python
# 改 LOG 路径
LOG = "/home/data/vivado-risc-v/workspace/dualv7-test/070x/uart-20mhz-auto.log"
```

其余代码无需改动 —— bit 替换在 JTAG TCL 层面完成（`fpga -file` 指向 20MHz bit）。
