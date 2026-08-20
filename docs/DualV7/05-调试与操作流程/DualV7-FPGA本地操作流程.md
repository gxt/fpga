# DualV7 FPGA 本地操作流程

**版本**：`z2m-20mhz-experimental`
**日期**：`2026-05-19`
**适用范围**：DualV7 本地 JTAG Boot、Linux bring-up、U-Boot 网络引导验证

这份流程只覆盖**本地上板与日志验证**。
不覆盖远端 RTL 修改或 Vivado 综合。

当前推荐基线分三条：

1. `release-r1`：JTAG 下载 bit + boot.elf + Image + ramdisk 的 Linux smoke 基线
2. `release-r2-hotfix`：JTAG 仅下载 bit + boot.elf，U-Boot 通过 TFTP 取内核，
   Linux 通过 NFS 挂根文件系统，`REALCHECK` 常驻到 `hold`
3. **`z2m-20mhz-experimental`（新增）**：`rocket64z2m` 双核 MegaBoom @ 20MHz，
   BusyBox NFS root + telnetd 远程登录

不要再直接按 `051x` 的原始试错过程执行。

---

## 1. 固定设备与路径

| 项目 | 固定值 |
|---|---|
| UART | `/dev/serial/by-id/usb-1a86_5523-if00-port0` |
| JTAG server | `hw_server` on `localhost:3121` |
| 主机网卡 | `enp1s0` |
| 主机 IPv4 | `192.168.200.201/24` |
| release 工件目录 | `/home/data/vivado-risc-v/workspace/release-r1` |
| netboot 工件目录 | `/home/data/vivado-risc-v/workspace/release-r2-hotfix` |

快速检查：

```bash
ls -l /dev/serial/by-id/usb-1a86_5523-if00-port0
ip -br addr show enp1s0
ss -tlnp | grep 3121 || true
```

---

## 2. 固定产物组合

### 2.1 `release-r1` 本地缓存产物

| 产物 | 路径 | sha256 |
|---|---|---|
| bit | `/home/data/vivado-risc-v/workspace/release-r1/rocket64b2-r1.bit` | `90cd6654e07aeef8107d714f5b9934172d37f83faf9a01b2b0f125df78b2ab47` |
| boot.elf | `/home/data/vivado-risc-v/workspace/release-r1/boot-r1.elf` | `91c898cfc9d9d019755d7807632ff19950feb13455b990d559a3b1cd05ca3d73` |
| Image | `/home/data/vivado-risc-v/linux-stable/arch/riscv/boot/Image` | `e228bb35d02c84fc5878b45ac1d5f3ffbdfee7c13af07432b21a1e3797a0f553` |
| ramdisk | `/home/data/vivado-risc-v/ramdisk-realcheck-src/out/ramdisk-realcheck` | `efd0217b56a93a3765e64a1e93270d074cc1b1cad9e25d559cd8058fa70a5d19` |

校验命令：

```bash
sha256sum \
  /home/data/vivado-risc-v/workspace/release-r1/rocket64b2-r1.bit \
  /home/data/vivado-risc-v/workspace/release-r1/boot-r1.elf \
  /home/data/vivado-risc-v/linux-stable/arch/riscv/boot/Image \
  /home/data/vivado-risc-v/ramdisk-realcheck-src/out/ramdisk-realcheck
```

### 2.2 `release-r2-hotfix` 本地缓存产物

| 产物 | 路径 | sha256 |
|---|---|---|
| bit | `/home/data/vivado-risc-v/workspace/release-r2-hotfix/rocket64b2-r2.bit` | `90cd6654e07aeef8107d714f5b9934172d37f83faf9a01b2b0f125df78b2ab47` |
| boot.elf | `/home/data/vivado-risc-v/workspace/release-r2-hotfix/boot-r2.elf` | `bef224570468ce4c4f0486ca0c4f58c302970ffcff5e1d8b30be53feb39081e9` |
| TFTP/NFS root | `/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot` | `init 已更新为 commit 8ecf400，对应 hash 8e001f86...` |

辅助文件：

- [jtag-boot-r2.tcl](/home/data/vivado-risc-v/workspace/release-r2-hotfix/jtag-boot-r2.tcl)
- [uboot-tftp-nfs-commands.txt](/home/data/vivado-risc-v/workspace/release-r2-hotfix/uboot-tftp-nfs-commands.txt)
- [artifacts.txt](/home/data/vivado-risc-v/workspace/release-r2-hotfix/artifacts.txt)

### 2.3 重要说明

- `boot.elf` 与 bit 必须成对使用。
- 早期 UART 仍可能短暂出现 `PHYPROBE 041x`，这是板上旧 BootROM
  噪音；只要后续 JTAG Boot 正常进入 `OpenSBI/U-Boot/Linux`，不算阻塞。
- 当前 release `Image` 是**本地** `linux-stable` 构建物，不是 202 上
  `/home/zzx/vivado/sw/linux` 那份内核。
- 只做 Linux smoke 时用 `boot-r1.elf`；
  **做网络引导时改用**
  `workspace/release-r2-hotfix/boot-r2.elf`。

---

## 3. 最小 JTAG Boot 流程

### 3.1 启动 `hw_server`

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
pgrep -f hw_server >/dev/null || hw_server -d >/tmp/release-r1-hw-server.log 2>&1 &
sleep 2
```

### 3.2 xsdb TCL

固定 TCL：

```tcl
connect -url tcp:localhost:3121
targets 1
fpga -file /home/data/vivado-risc-v/workspace/release-r1/rocket64b2-r1.bit
targets -set -filter {name =~ "Hart #0*"}
stop
targets -set -filter {name =~ "RISC-V*"}
dow -data /home/data/vivado-risc-v/linux-stable/arch/riscv/boot/Image 0x81000000
dow -data /home/data/vivado-risc-v/ramdisk-realcheck-src/out/ramdisk-realcheck 0x85000000
targets -set -filter {name =~ "Hart #0*"}
dow -clear /home/data/vivado-risc-v/workspace/release-r1/boot-r1.elf
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000
con
exit
```

本地文件：

- [jtag-boot-r1.tcl](/home/data/vivado-risc-v/workspace/release-r1/jtag-boot-r1.tcl)

### 3.3 执行

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
xsdb -eval "source /home/data/vivado-risc-v/workspace/release-r1/jtag-boot-r1.tcl"
```

---

## 4. UART 与 U-Boot 交互

### 4.1 串口配置

```bash
stty -F /dev/serial/by-id/usb-1a86_5523-if00-port0 \
  115200 raw -echo -echoe -echok
```

### 4.2 抓日志

```bash
timeout 120 cat /dev/serial/by-id/usb-1a86_5523-if00-port0 \
  | tee /home/data/vivado-risc-v/workspace/release-r1/uart-r1.log
```

### 4.3 停 autoboot

看到：

```text
Hit any key to stop autoboot:
```

向串口发送回车，进入 `=>` 提示符后执行：

```text
booti 0x81000000 0x85000000 0x10080
```

自动化脚本已经固化这一步：

- [run_release_check.py](/home/data/vivado-risc-v/workspace/release-r1/run_release_check.py)

---

## 5. 成功判据

### 5.1 U-Boot 阶段

串口中应出现：

```text
U-Boot 2022.01-dirty
Net:   vivado_mii: ...
eth0: eth0@60020000
```

### 5.2 Linux 阶段

串口中应出现：

```text
Starting kernel ...
Run /init as init process
riscv-axi-eth 60020000.eth0: 044x: probed as eth0, irq=4
REALCHECK: READY
```

### 5.3 IPv4 网络阶段

主机执行：

```bash
ping -c 3 -W 1 192.168.200.250
```

期望：

- `3/3` 成功
- `tcpdump` 能看到 ARP 与 ICMP request/reply

当前已验证日志：

- [uart-r1.log](/home/data/vivado-risc-v/workspace/release-r1/uart-r1.log)
- [host-ping4.log](/home/data/vivado-risc-v/workspace/release-r1/host-ping4.log)
- [tcpdump-r1.log](/home/data/vivado-risc-v/workspace/release-r1/tcpdump-r1.log)

---

## 6. 常见误区

1. 不要先怀疑 BootROM  
   当前主验证路径是 **JTAG Boot**，软件入口已经绕开 SD Boot。

2. 不要混用 `boot.elf`  
   Linux smoke 用 `boot-r1.elf`；
   网络引导用 `boot-r2.elf`。

3. 不要混淆两条入口  
   - `release-r1`：JTAG 下载 kernel/ramdisk 的 Linux smoke
   - `release-r2-hotfix`：U-Boot `ping`/`tftpboot` + Linux NFS root

4. 不要按 051x 的试错过程自由发挥  
   051x 只保留为历史记录；复现以本流程和 release 清单为准。

---

## 7. 远端构建与本地验证的分工

### 7.1 远端 202

- 主工程：`zzx@192.168.200.202:~/vivado-risc-v`
- 用途：构建 bit、构建 `boot.elf`

### 7.2 本地

- 内核仓：`/home/data/vivado-risc-v/linux-stable`
- ramdisk 仓：`/home/data/vivado-risc-v/ramdisk-realcheck-src`
- 用途：构建 `Image`、构建 `ramdisk`、执行 JTAG Boot 与实机验证

---

## 8. 网络引导：U-Boot TFTP 取内核 + Linux NFS Root

该路径**已验证可工作**（063x 打通链路，065x 修正常驻 init）：

1. JTAG **只**下载：
   - bit
   - `boot-r2.elf`
2. U-Boot 通过 `tftpboot` 获取内核
3. Linux 通过 `root=/dev/nfs` 挂载根文件系统

这条路径满足：
**不要从 JTAG 下载内核和 ramdisk。**

### 8.1 前提条件

- 本机已安装 `nfs-kernel-server`
- 本机已安装 `dnsmasq`
- UFW 防火墙已放行 FPGA → 本机的 NFS 相关端口：
  `2049/tcp`、`111/tcp`、`30000:65535/tcp+udp`
- UFW 已放行 FPGA → 本机 `69/udp`
- 本机 IP `192.168.200.201/24`，FPGA IP `192.168.200.250`

### 8.2 准备 NFS/TFTP 根目录

```bash
mkdir -p /home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/{dev,proc,sys,tmp,run,etc,sbin}
cp /home/data/vivado-risc-v/ramdisk-realcheck-src/out/init \
  /home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/init
cp /home/data/vivado-risc-v/linux-stable/arch/riscv/boot/Image \
  /home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/Image
ln -sf ../init /home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/sbin/init
chmod +x /home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/init
```

注意：内核按 `/sbin/init → /etc/init → /bin/init → /bin/sh`
顺序查找 init，**不直接查 `/init`**，所以必须创建
`sbin/init` symlink。

### 8.3 NFS export 配置

```bash
EXPORT_DIR=/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot
sudo mkdir -p /etc/exports.d
printf '%s *(rw,sync,no_subtree_check,no_root_squash,insecure)\n' \
  "$EXPORT_DIR" | sudo tee /etc/exports.d/dualv7-r2-hotfix.exports
sudo exportfs -ra
sudo systemctl restart nfs-server
```

### 8.4 TFTP 服务

```bash
sudo dnsmasq --port=0 --interface=enp1s0 --bind-interfaces \
  --enable-tftp \
  --tftp-root=/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot \
  --tftp-no-fail \
  --user=data --group=data \
  --pid-file=/tmp/r2-hotfix-dnsmasq.pid \
  --log-facility=/home/data/vivado-risc-v/workspace/release-r2-hotfix/dnsmasq-tftp.log

sudo ufw allow proto udp from 192.168.200.250 to any port 69 \
  comment 'TFTP from FPGA'
```

### 8.5 JTAG 仅下载 bit + boot.elf

固定 TCL：

```tcl
connect -url tcp:localhost:3121
targets 1
fpga -file /home/data/vivado-risc-v/workspace/release-r2-hotfix/rocket64b2-r2.bit
targets -set -filter {name =~ "Hart #0*"}
stop
dow -clear /home/data/vivado-risc-v/workspace/release-r2-hotfix/boot-r2.elf
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000
con
exit
```

本地文件：

- [jtag-boot-r2.tcl](/home/data/vivado-risc-v/workspace/release-r2-hotfix/jtag-boot-r2.tcl)

执行：

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
xsdb -eval "source /home/data/vivado-risc-v/workspace/release-r2-hotfix/jtag-boot-r2.tcl"
```

### 8.6 U-Boot 手工命令

在 U-Boot `=>` 执行：

```text
setenv ethact eth0@60020000
setenv ipaddr 192.168.200.250
setenv serverip 192.168.200.201
setenv netmask 255.255.255.0
ping 192.168.200.201
tftpboot 0x81000000 Image
setenv bootargs 'earlycon console=ttyAU0,115200 root=/dev/nfs nfsroot=192.168.200.201:/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot,vers=3,tcp,rw ip=192.168.200.250:192.168.200.201::255.255.255.0:dualv7:eth0:off'
booti 0x81000000 - 0x10080
```

说明：

- **不再**执行 `dow -data Image ...`
- **不再**执行 `dow -data ramdisk ...`
- 当前主线是 **TFTP 取内核 + Linux NFS root**
- 不建议把 U-Boot `nfs` 文件抓取当作默认入口

### 8.7 成功判据

串口中应出现：

1. `host 192.168.200.201 is alive`
2. `Bytes transferred = ...`
3. `Starting kernel ...`
4. `VFS: Mounted root (nfs filesystem)`
5. `devtmpfs: mounted`
6. `REALCHECK: hold`

关键日志：

- [uart-netboot-r2.log](/home/data/vivado-risc-v/workspace/release-r2-hotfix/uart-netboot-r2.log)
- [uart-attach-tftp-nfsboot.log](/home/data/vivado-risc-v/workspace/dualv7-test/063x/uart-attach-tftp-nfsboot.log)

### 8.8 已知限制

- 当前 `init` 会在 `REALCHECK: done` 后进入常驻 `hold` 循环，
  不再因退出而触发 panic。
- 这仍是最小验证 rootfs，不是长期用户态；后续若要常规使用，
  仍应换成 BusyBox/systemd。

### 8.9 BusyBox NFS root（067x）

如需一个**可交互、可长期驻留**的最小用户态，不必继续停在
`REALCHECK: hold`，可切到：

- 工作目录：
  `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot`
- 本地 rootfs 仓：
  `/home/data/vivado-risc-v/busybox-nfsroot-src`

当前已验证：

1. `U-Boot ping`
2. `tftpboot 0x81000000 Image`
3. Linux `root=/dev/nfs`
4. BusyBox `init` 启动
5. `mount` / `ifconfig -a` / `cat /proc/net/dev` 可用

关键日志：

- [gpt-busybox-retest.log](/home/data/vivado-risc-v/workspace/dualv7-test/067x/gpt-busybox-retest.log)

### 8.10 z2m + BusyBox NFS root（068x / r3）

如果目标切到双核 `rocket64z2m`，当前固定入口是：

- bit：
  `/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/rocket64z2m-r3.bit`
- boot.elf：
  `/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/boot-r3.elf`
- U-Boot 命令：
  [uboot-tftp-nfs-commands.txt](/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/uboot-tftp-nfs-commands.txt)

JTAG 下载入口：

- [jtag-boot-r3-z2m.tcl](/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/jtag-boot-r3-z2m.tcl)

关键判据：

1. OpenSBI `Platform HART Count = 2`
2. Linux `smp: Brought up 1 node, 2 CPUs`
3. `VFS: Mounted root (nfs filesystem)`
4. BusyBox shell 出现 `[~] #`

关键日志：

- [uart-z2m-busybox.log](/home/data/vivado-risc-v/workspace/dualv7-test/068x/uart-z2m-busybox.log)
- [busybox-shell-proof.log](/home/data/vivado-risc-v/workspace/dualv7-test/068x/busybox-shell-proof.log)

---
## 9. U-Boot 网络入口现状

### 9.1 历史结论（059x）

059x 的**历史**结论是 `tx-on-wire-no-reply`：

- FPGA 发出 ARP request
- 主机返回 ARP reply
- 但没有后续 ICMP

这对应的是**旧的** `boot-r1.elf` 行为，不再作为当前主线。

### 9.2 当前状态（061x + 063x）

在 `boot-r2.elf` 中，U-Boot `vivado_mii` 已通过两处软件修补恢复：

1. `start()` 不再把 RX ring 填满
2. `recv()` 消费后会回补 RX buffer

因此当前**已验证**：

- `ping 192.168.200.201`：✅
- `tftpboot 0x81000000 Image`：✅

后续如果继续做 U-Boot 网络调试，默认从
`workspace/release-r2-hotfix/boot-r2.elf`
起步，不要回到 `boot-r1.elf`。

---
## 10. 关联文档

- [DualV7-Release清单.md](/home/data/vivado-risc-v/doc/DualV7-Release清单.md)
- [vivado-risc-v-编译流程-简版.md](/home/data/vivado-risc-v/doc/vivado-risc-v-编译流程-简版.md)

---
## 11. `z2m-20mhz-experimental` 基线（070x）

**日期**：`2026-05-19`
**状态**：已验证
**用途**：`rocket64z2m`（2×MegaBoom Z1）@ 20MHz + BusyBox NFS root + telnetd

### 11.1 产物

| 产物 | 路径 | SHA256 |
|------|------|--------|
| bit (20MHz) | `workspace/070x/rocket64z2m-20mhz.bit` | `4581d346...e40e87bb` |
| boot.elf | `workspace/release-r2-hotfix/boot-r2.elf` | 复用 |
| kernel Image | `linux-stable/arch/riscv/boot/Image` | `e228bb35...a0f553` |
| NFS root | `workspace/release-r2-busybox/nfsroot` | BusyBox 1.36.1 |

### 11.2 硬件时钟

| 时钟域 | 频率 |
|--------|------|
| SoC 主域 (RocketChip) | **20 MHz** |
| UART/SD | 100 MHz |
| MIG sys_clk | 200 MHz |
| DDR3 PHY | 400 MHz (800 MT/s) |

### 11.3 Post-route Timing

| 指标 | 值 |
|------|-----|
| WNS | +7.891 ns |
| TNS | 0.000 ns |
| WHS | +0.131 ns |

### 11.4 JTAG 下载

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
xsdb workspace/070x/jtag-boot-20mhz.tcl
```

### 11.5 U-Boot 网络引导命令

```
setenv ipaddr 192.168.200.250
setenv serverip 192.168.200.201
ping 192.168.200.201
tftpboot 0x81000000 Image
setenv bootargs earlycon console=ttyAU0,115200 root=/dev/nfs nfsroot=192.168.200.201:/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot,vers=3,tcp,rw ip=192.168.200.250:192.168.200.201::255.255.255.0:dualv7:eth0:off
booti 0x81000000 - 0x10080
```

### 11.6 远程登录 FPGA

BusyBox 启动后自动开启 telnetd（端口 23）：

```bash
# 从主机登录
telnet 192.168.200.250
# 直接拿到 root shell
```

已验证命令：`hostname`、`mount`、`ifconfig`、`ps`、`uptime`、
`cat /proc/net/dev`、`ls /bin` 等均正常。

### 11.7 串口交互终端

```bash
bash workspace/070x/fpga-terminal.sh
# Ctrl+A Ctrl+X 退出
```

### 11.8 一键自动化

```bash
# 先 JTAG 下载
xsdb workspace/070x/jtag-boot-20mhz.tcl
# 再跑自动 smoke（JTAG 后执行）
python3 workspace/070x/auto_smoke_20mhz.py
```

### 11.9 验证日志

- `workspace/dualv7-test/070x/uart-20mhz.log`
- `workspace/dualv7-test/070x/uart-20mhz-auto.log`

### 11.10 参考

- 手动测试说明：`workspace/070x/手动测试流程-20mhz.md`
- 频率调研报告：`doc/DualV7-z2m频率提升调研报告.md`
- 构建任务：`code-agent/tasks/070x-dualv7-z2m-20mhz-experimental-bit.md`
