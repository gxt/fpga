# 096x DualV7 `rocket64z1` 单核 Mega 环境

## 入口脚本

- `prepare_host_netboot.sh`
  - 复用 `095x` 的 host 侧 TFTP/NFS 准备
- `jtag-boot-z1.tcl`
  - 下载 `rocket64z1.bit + boot-r2.elf`
- `restore_netboot_z1.sh`
  - 执行单核 Mega 完整恢复 smoke
- `telnet_check.py`
  - 验证 `telnet 192.168.200.250`

## 固定基线

- bit:
  `/home/data/vivado-risc-v/workspace/experiments/dualv7-test/035x/rocket64z1.bit`
- bit sha256:
  `160dc4306937afa5290a369f595ca3191a201eb2f03d55961b7b45655db21dd6`
- boot.elf:
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix/boot-r2.elf`
- frozen Image:
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/Image`
- busybox rootfs:
  `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot`

## 与 z2m 的关系

- 共用 `boot-r2.elf`
- 共用 BusyBox NFS root
- 共用主机侧 TFTP/NFS
- 唯一区别是 FPGA bit 换成 `rocket64z1`
