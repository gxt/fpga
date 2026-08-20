# DualV7 z2m 网络引导 + telnet 恢复手册

**日期**：`2026-06-24`  
**适用对象**：重新接回本地主机的 DualV7  
**目标**：恢复 `rocket64z2m` 的
`JTAG bit+boot.elf -> U-Boot TFTP -> Linux NFS root -> telnetd`
链路

---

## 1. 当前推荐基线

- bit：
  `/home/data/vivado-risc-v/workspace/070x/rocket64z2m-20mhz.bit`
- boot.elf：
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix/boot-r2.elf`
- 冻结内核 Image：
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/Image`
- BusyBox rootfs：
  `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot`
- 主机 IP：
  `192.168.200.201`
- FPGA IP：
  `192.168.200.250`
- UART：
  `/dev/serial/by-id/usb-1a86_5523-if00-port0`

**注意**：
当前恢复基线默认使用上面的冻结内核 Image。
不要直接把
`linux-stable/arch/riscv/boot/Image`
当作历史验证通过的内核工件；它现在是会漂移的构建输出。

---

## 2. 095x 入口脚本

- [prepare_host_netboot.sh](/home/data/vivado-risc-v/workspace/095x/prepare_host_netboot.sh)
  - 准备 TFTP/NFS
- [jtag-boot-z2m-20mhz.tcl](/home/data/vivado-risc-v/workspace/095x/jtag-boot-z2m-20mhz.tcl)
  - 下载 `bit + boot.elf`
- [restore_netboot_z2m_20mhz.sh](/home/data/vivado-risc-v/workspace/095x/restore_netboot_z2m_20mhz.sh)
  - 执行完整恢复 smoke
- [telnet_check.py](/home/data/vivado-risc-v/workspace/095x/telnet_check.py)
  - 验证 telnet 登录

---

## 3. 前置检查

### 3.1 硬件与工具

```bash
ls -l /dev/serial/by-id
ip -br addr show enp1s0
source /tools/Xilinx/2025.1/Vivado/settings64.sh
command -v xsdb
command -v hw_server
command -v telnet
command -v exportfs
```

### 3.2 串口权限

当前主机如果用户不在 `dialout` 组，可能会卡在：
`stty: ... 权限不够`。

临时修复：

```bash
sudo setfacl -m u:$USER:rw /dev/ttyUSB0
```

`095x` 的恢复脚本已经内置这一步。

---

## 4. 一键恢复

直接执行：

```bash
cd /home/data/vivado-risc-v
bash workspace/095x/restore_netboot_z2m_20mhz.sh
```

这条命令会完成：

1. 准备 TFTP `/srv/tftp/Image`
2. 校验/复用 NFS export
3. JTAG 下载 `rocket64z2m-20mhz.bit + boot-r2.elf`
4. 通过 UART 进入 U-Boot
5. 执行 `ping` / `tftpboot` / `booti`
6. 等待 BusyBox 启动并拉起 `telnetd`

默认 UART 日志：

- [uart-restore.log](/home/data/vivado-risc-v/workspace/095x/uart-restore.log)

成功关键字：

- `host 192.168.200.201 is alive`
- `Bytes transferred =`
- `VFS: Mounted root (nfs filesystem)`
- `BusyBox v1.36.1`
- `Starting telnetd on port 23`

---

## 5. 验证 telnet 登录

### 5.1 自动检查

```bash
cd /home/data/vivado-risc-v
python3 workspace/095x/telnet_check.py
```

默认日志：

- [telnet-check.log](/home/data/vivado-risc-v/workspace/095x/telnet-check.log)

期望输出包含：

- `TELNET_OK`
- `dualv7-busybox`

### 5.2 手工登录

```bash
telnet 192.168.200.250
```

当前 BusyBox rootfs 默认直接给 root shell，不走密码登录。

---

## 6. 如何更换内核 Image

### 6.1 推荐方式

把新内核作为 TFTP 的 `Image`：

```bash
cd /home/data/vivado-risc-v
KERNEL_IMAGE=/path/to/new/Image \
  bash workspace/095x/prepare_host_netboot.sh
```

然后重新恢复：

```bash
KERNEL_IMAGE=/path/to/new/Image \
  bash workspace/095x/restore_netboot_z2m_20mhz.sh
```

### 6.2 直接覆盖 TFTP 文件

```bash
sudo install -m 0644 /path/to/new/Image /srv/tftp/Image
```

**约束**：

- U-Boot 当前默认拉取的文件名就是 `Image`
- 如果只改了 TFTP 内核，不需要重编 bit 或 `boot.elf`

---

## 7. 如何更换 rootfs

假设新 rootfs 在 `/path/to/new/rootfs`：

```bash
cd /home/data/vivado-risc-v
NFSROOT=/path/to/new/rootfs \
  bash workspace/095x/prepare_host_netboot.sh
```

然后重新恢复：

```bash
NFSROOT=/path/to/new/rootfs \
  bash workspace/095x/restore_netboot_z2m_20mhz.sh
```

这里不只是改 NFS export。
`restore_netboot_z2m_20mhz.sh` 会把同一个 `NFSROOT` 路径写进
U-Boot `bootargs` 里的 `nfsroot=...`。

**最小要求**：

- rootfs 目录存在
- `bin/busybox` 可执行
- 能作为 NFSv3 根目录导出

---

## 8. 分步执行

如果不想一键跑，也可以分两步：

### 8.1 先准备 host

```bash
bash /home/data/vivado-risc-v/workspace/095x/prepare_host_netboot.sh
```

### 8.2 再做 JTAG 下载

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
xsdb /home/data/vivado-risc-v/workspace/095x/jtag-boot-z2m-20mhz.tcl
```

后续 UART/U-Boot 命令仍可手工执行：

```text
setenv ethact eth0@60020000
setenv ipaddr 192.168.200.250
setenv serverip 192.168.200.201
setenv netmask 255.255.255.0
ping 192.168.200.201
tftpboot 0x81000000 Image
setenv bootargs 'earlycon console=ttyAU0,115200 root=/dev/nfs nfsroot=192.168.200.201:/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot,vers=3,tcp,rw ip=192.168.200.250:192.168.200.201::255.255.255.0:dualv7:eth0:off'
booti 0x81000000 - 0x10080
```

---

## 9. 本轮实测结果

`2026-06-24` 本地实测已通过：

- 旧脚本 `070x/smoke-20mhz.sh`
- 新脚本 `095x/restore_netboot_z2m_20mhz.sh`
- 主机侧 `095x/telnet_check.py`

对应日志：

- [uart-restore-20260624.log](/home/data/vivado-risc-v/workspace/095x/uart-restore-20260624.log)
- [uart-restore.log](/home/data/vivado-risc-v/workspace/095x/uart-restore.log)
- [telnet-check.log](/home/data/vivado-risc-v/workspace/095x/telnet-check.log)

---

## 10. 常见问题

### 10.1 `stty: 权限不够`

原因：当前用户没有 UART 写权限。  
处理：`sudo setfacl -m u:$USER:rw /dev/ttyUSB0`

### 10.2 `exportfs: duplicated export entries`

原因：重复为同一个 rootfs 写了新的 export 文件。  
处理：使用 `095x/prepare_host_netboot.sh`，它已经避免了默认基线的重复导出。

### 10.3 TFTP 能启动但内核不对

原因：`/srv/tftp/Image` 被替换成了别的内核。  
处理：重新执行：

```bash
bash /home/data/vivado-risc-v/workspace/095x/prepare_host_netboot.sh
```

### 10.4 `linux-stable/.../Image` 和历史 release 不一致

这是正常现象。`linux-stable/arch/riscv/boot/Image`
是当前源码树的移动构建产物，不再等于历史验证通过的内核。
恢复基线默认使用冻结工件：

- `/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/Image`
- `/srv/tftp/Image`
