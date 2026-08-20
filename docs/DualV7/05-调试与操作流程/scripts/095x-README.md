# 095x DualV7 z2m netboot + telnet 恢复工件

## 入口脚本

- `prepare_host_netboot.sh`
  - 准备 host 侧 TFTP/NFS
  - 默认冻结内核：
    `/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/Image`
  - 默认 rootfs：
    `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot`
- `jtag-boot-z2m-20mhz.tcl`
  - 下载 `rocket64z2m-20mhz.bit + boot-r2.elf`
- `restore_netboot_z2m_20mhz.sh`
  - 执行完整恢复 smoke
- `telnet_check.py`
  - 验证 `telnet 192.168.200.250`

## 默认基线

- bit:
  `/home/data/vivado-risc-v/workspace/070x/rocket64z2m-20mhz.bit`
- boot.elf:
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix/boot-r2.elf`
- frozen Image:
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/Image`
- busybox rootfs:
  `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot`

## 本轮日志

- UART:
  `uart-restore-20260624.log`
- UART:
  `uart-restore.log`
- telnet:
  `telnet-check.log`
