# DualV7 `rocket64z1` 单核 Mega 网络引导手册

**日期**：`2026-06-24`  
**适用对象**：DualV7 本地单核 Mega 环境  
**目标**：恢复并使用
`rocket64z1 bit + boot-r2.elf + U-Boot TFTP + BusyBox NFS root + telnetd`

---

## 1. 当前固定基线

- bit：
  `/home/data/vivado-risc-v/workspace/experiments/dualv7-test/035x/rocket64z1.bit`
- bit sha256：
  `160dc4306937afa5290a369f595ca3191a201eb2f03d55961b7b45655db21dd6`
- boot.elf：
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix/boot-r2.elf`
- frozen Image：
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/Image`
- BusyBox rootfs：
  `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot`
- Host IP：
  `192.168.200.201`
- FPGA IP：
  `192.168.200.250`
- UART：
  `/dev/serial/by-id/usb-1a86_5523-if00-port0`

这套单核环境当前**不重新综合 bit**，直接复用历史 `rocket64z1` bit。

---

## 2. 和 z2m 环境的关系

`z1` 与 `z2m` 当前共用：

- `boot-r2.elf`
- `frozen Image`
- BusyBox NFS root
- 主机侧 TFTP/NFS 配置
- UART/JTAG 基础流程

唯一关键差异是 FPGA bit：

- `z1`：
  `workspace/experiments/dualv7-test/035x/rocket64z1.bit`
- `z2m`：
  `workspace/070x/rocket64z2m-20mhz.bit`

另外，当前 `z1` 是 **1 CPU**，不是 `z2m` 的 2 CPU。

---

## 3. 096x 入口脚本

- [prepare_host_netboot.sh](/home/data/vivado-risc-v/workspace/096x/prepare_host_netboot.sh)
  - 复用 `095x` 的 host 准备逻辑
- [jtag-boot-z1.tcl](/home/data/vivado-risc-v/workspace/096x/jtag-boot-z1.tcl)
  - 下载 `rocket64z1.bit + boot-r2.elf`
- [restore_netboot_z1.sh](/home/data/vivado-risc-v/workspace/096x/restore_netboot_z1.sh)
  - 单核 Mega 一键恢复
- [telnet_check.py](/home/data/vivado-risc-v/workspace/096x/telnet_check.py)
  - 验证 telnet 登录

---

## 4. 一键恢复

```bash
cd /home/data/vivado-risc-v
bash workspace/096x/restore_netboot_z1.sh
```

它会完成：

1. 准备 TFTP `/srv/tftp/Image`
2. 复用 NFS export
3. JTAG 下载 `rocket64z1.bit + boot-r2.elf`
4. UART 打断 U-Boot
5. 执行 `ping` / `tftpboot` / `booti`
6. 等待 BusyBox rootfs 起完并拉起 `telnetd`

默认日志：

- [uart-z1.log](/home/data/vivado-risc-v/workspace/096x/uart-z1.log)

关键成功字样：

- `host 192.168.200.201 is alive`
- `Bytes transferred =`
- `Brought up 1 node, 1 CPU`
- `VFS: Mounted root (nfs filesystem)`
- `Starting telnetd on port 23`

---

## 5. telnet 登录验证

```bash
cd /home/data/vivado-risc-v
python3 workspace/096x/telnet_check.py
```

日志：

- [telnet-check.log](/home/data/vivado-risc-v/workspace/096x/telnet-check.log)

期望输出包含：

- `Welcome to DualV7 BusyBox`
- `TELNET_OK`
- `dualv7-busybox`

手工登录：

```bash
telnet 192.168.200.250
```

---

## 6. 当前实测结论

`2026-06-24` 本地实测已通过：

1. `rocket64z1` bit JTAG 下载成功
2. U-Boot `ping 192.168.200.201` 成功
3. `tftpboot 0x81000000 Image` 成功
4. Linux `VFS: Mounted root (nfs filesystem)` 成功
5. `smp: Brought up 1 node, 1 CPU`
6. BusyBox `telnetd` 成功
7. telnet 登录成功

日志：

- [uart-z1.log](/home/data/vivado-risc-v/workspace/096x/uart-z1.log)
- [telnet-check.log](/home/data/vivado-risc-v/workspace/096x/telnet-check.log)

---

## 7. 已知边界

1. 这不是新的 `rocket64z1` release 重建结果，而是：
   - 历史 `z1` bit
   - 当前稳定 `boot-r2.elf`
   - 当前稳定 BusyBox rootfs
   的本地组合基线
2. 当前 `z1` bit 的历史 timing 结论仍是：
   `WNS=-9.826ns`
3. 当前环境优先目标是：
   **单核 Mega 软件链可用**
   不是单核 Mega 提频

---

## 8. 如何更换内核 / rootfs

和 `095x` 完全一致：

### 更换内核

```bash
cd /home/data/vivado-risc-v
KERNEL_IMAGE=/path/to/new/Image \
  bash workspace/096x/prepare_host_netboot.sh
```

### 更换 rootfs

```bash
cd /home/data/vivado-risc-v
NFSROOT=/path/to/new/rootfs \
  bash workspace/096x/restore_netboot_z1.sh
```

`restore_netboot_z1.sh` 会把同一个 `NFSROOT` 路径写进 `bootargs`。

---

## 9. 关联文档

- [DualV7-z2m-网络引导-telnet恢复手册.md](/home/data/vivado-risc-v/doc/DualV7-z2m-网络引导-telnet恢复手册.md)
- [DualV7-FPGA本地操作流程.md](/home/data/vivado-risc-v/doc/DualV7-FPGA本地操作流程.md)
- [DualV7-Release清单.md](/home/data/vivado-risc-v/doc/DualV7-Release清单.md)
