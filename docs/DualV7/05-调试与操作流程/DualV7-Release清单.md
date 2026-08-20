# DualV7 Release 清单

后续每个 release 都在这份文档**追加新章节**。
不要覆盖旧 release。

---

## Release `dualv7-r1-jtagboot-net`

**日期**：`2026-05-17`  
**状态**：`validated`  
**用途**：本地 JTAG Boot + Linux IPv4 网络验证基线

### 1. 代码位置与 commit

| 组件 | 位置 | commit | tag | 说明 |
|---|---|---|---|---|
| 主工程 | `zzx@202:~/vivado-risc-v` | `137a01660c63948368aafd31fdabaf742314acd1` | `dualv7-r1-jtagboot-net` | bit 与 `boot.elf` 的主仓 |
| U-Boot 子仓 | `zzx@202:~/vivado-risc-v/u-boot` | `702e1e7acfedbbce19d12235471c3c5f1a888029` | `dualv7-r1-jtagboot-net` | 含 `vivado_mii` |
| 本地 Linux | `/home/data/vivado-risc-v/linux-stable` | `567ee7b75dd6a078b7f02b839fae36b2c33563d2` | `dualv7-r1-jtagboot-net` | 当前实测用内核 |
| 本地 ramdisk | `/home/data/vivado-risc-v/ramdisk-realcheck-src` | `dc20df9580683175dd38c09d50eb1e46280aa1d6` | `dualv7-r1-jtagboot-net` | `REALCHECK` initramfs 源 |

### 2. 产物缓存与 sha256

| 产物 | 路径 | sha256 |
|---|---|---|
| bit | `/home/data/vivado-risc-v/workspace/release-r1/rocket64b2-r1.bit` | `90cd6654e07aeef8107d714f5b9934172d37f83faf9a01b2b0f125df78b2ab47` |
| boot.elf | `/home/data/vivado-risc-v/workspace/release-r1/boot-r1.elf` | `91c898cfc9d9d019755d7807632ff19950feb13455b990d559a3b1cd05ca3d73` |
| Image | `/home/data/vivado-risc-v/linux-stable/arch/riscv/boot/Image` | `e228bb35d02c84fc5878b45ac1d5f3ffbdfee7c13af07432b21a1e3797a0f553` |
| ramdisk | `/home/data/vivado-risc-v/ramdisk-realcheck-src/out/ramdisk-realcheck` | `efd0217b56a93a3765e64a1e93270d074cc1b1cad9e25d559cd8058fa70a5d19` |

### 3. bit 构建流程

**机器**：`zzx@192.168.200.202`

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
cd ~/vivado-risc-v

make -j"$(nproc)" BOARD=dualv7 CONFIG=rocket64b2 \
  workspace/rocket64b2/system-dualv7.v

make BOARD=dualv7 CONFIG=rocket64b2 \
  workspace/rocket64b2/rocket.vhdl

make BOARD=dualv7 CONFIG=rocket64b2 vivado-project

make BOARD=dualv7 CONFIG=rocket64b2 MAX_THREADS="$(nproc)" \
  workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit
```

**结果**：

- `WNS = +0.935ns`
- `WHS = -7.690ns`
- `Timing constraints are not met`
- 但 bit 已实机通过当前 JTAG Boot + IPv4 验证

### 4. boot.elf 构建流程

**机器**：`zzx@192.168.200.202`

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
cd ~/vivado-risc-v
rm -f workspace/patch-u-boot-done
make -j"$(nproc)" bootloader
```

产物：

- `~/vivado-risc-v/workspace/boot.elf`

### 5. 内核构建流程

**机器**：本地 `/home/data/vivado-risc-v`

```bash
cd /home/data/vivado-risc-v/linux-stable
make ARCH=riscv CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- oldconfig
make -j"$(nproc)" ARCH=riscv CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- all
```

说明：

- 当前 release 使用的是**本地** 5.15.4 内核。
- 202 上也能编 kernel，但那是 `/home/zzx/vivado/sw/linux` 的 6.1.166，
  **不属于本 release**。

### 6. ramdisk 构建流程

**机器**：本地 `/home/data/vivado-risc-v`

```bash
cd /home/data/vivado-risc-v/ramdisk-realcheck-src
make clean
make
```

### 7. 本地验证脚本与日志

**脚本**：

- [run_release_check.py](/home/data/vivado-risc-v/workspace/release-r1/run_release_check.py)
- [jtag-boot-r1.tcl](/home/data/vivado-risc-v/workspace/release-r1/jtag-boot-r1.tcl)

**日志**：

- [uart-r1.log](/home/data/vivado-risc-v/workspace/release-r1/uart-r1.log)
- [host-ping4.log](/home/data/vivado-risc-v/workspace/release-r1/host-ping4.log)
- [tcpdump-r1.log](/home/data/vivado-risc-v/workspace/release-r1/tcpdump-r1.log)

### 8. 验证结论

这组 commit 与产物已验证：

1. U-Boot 阶段能枚举 `vivado_mii` 与 `eth0@60020000`
2. Linux 阶段能 probe `riscv-axi-eth`
3. 主机 `192.168.200.201` 到 FPGA `192.168.200.250` 的 IPv4 `ping`
   成功
4. `tcpdump` 能看到 ARP 与 ICMP request/reply

### 8.1 NFS Root 验证（058x, 2026-05-17）

**状态**：`verified-nfs-root-mount`

在同一组 release-r1 固定产物（bit / boot.elf / Image）基础上，
验证 Linux 阶段 NFS root：

1. 本机安装 `nfs-kernel-server`，配置 NFS export
2. 放行 UFW 防火墙 NFS 端口（2049/111 + mountd/lockd 动态端口）
3. JTAG Boot 不加载 ramdisk，U-Boot 手工设置 NFS root `bootargs`
4. 关键日志路径：`workspace/dualv7-test/058x/`

**验证结论**：
- `VFS: Mounted root (nfs filesystem)` ✅ — NFS root 挂载成功
- `Run /sbin/init as init process` ✅ — init 从 NFS 正确执行
- `REALCHECK: READY` ✅ — init 网络验证通过
- `eth0` link ready, ARP send OK ✅ — NFS root 下网络可用

**已知限制**：
- 当前 REALCHECK init 是单次测试，执行完退出导致 kernel panic
- `host-ping4` 不能作为 NFS root 持续网络判据
- 生产环境需常驻 init（busybox / systemd）

### 8.2 网络引导扩展（063x, 2026-05-17）

**状态**：`validated`

这不是新的独立 release tag，而是在 `release-r1` bit 基础上，
补出一条已经验证通过的**非 JTAG 下发内核/ramdisk** 启动链：

1. JTAG 仅下载：
   - `rocket64b2-r1.bit`
   - `boot-r1-netboot.elf`
2. U-Boot 通过 **TFTP** 获取 `Image`
3. Linux 通过 **NFS root** 挂根文件系统

#### 8.2.1 产物

| 产物 | 路径 | sha256 |
|---|---|---|
| bit | `/home/data/vivado-risc-v/workspace/release-r1/rocket64b2-r1.bit` | `90cd6654e07aeef8107d714f5b9934172d37f83faf9a01b2b0f125df78b2ab47` |
| boot.elf | `/home/data/vivado-risc-v/workspace/release-r1-netboot/boot-r1-netboot.elf` | `bef224570468ce4c4f0486ca0c4f58c302970ffcff5e1d8b30be53feb39081e9` |
| TFTP/NFS root | `/home/data/vivado-risc-v/workspace/release-r1-netboot/nfsroot` | `目录工件，复用 063x 已验证内容` |

#### 8.2.2 JTAG 下载入口

- [jtag-boot-r1-netboot.tcl](/home/data/vivado-risc-v/workspace/release-r1-netboot/jtag-boot-r1-netboot.tcl)
- [uboot-tftp-nfs-commands.txt](/home/data/vivado-risc-v/workspace/release-r1-netboot/uboot-tftp-nfs-commands.txt)

#### 8.2.3 Host 服务配置

- NFS export：
  `/home/data/vivado-risc-v/workspace/release-r1-netboot/nfsroot`
- TFTP：
  `dnsmasq --enable-tftp --tftp-root=/home/data/vivado-risc-v/workspace/release-r1-netboot/nfsroot`
- UFW：
  额外放行 FPGA -> host 的 `69/udp`

#### 8.2.4 关键结论

- U-Boot `ping 192.168.200.201`：✅
- U-Boot `tftpboot 0x81000000 Image`：✅
- Linux `VFS: Mounted root (nfs filesystem)`：✅
- JTAG **不再**下载 `Image` / ramdisk：✅

#### 8.2.5 日志

- [uart-attach-tftp-nfsboot.log](/home/data/vivado-risc-v/workspace/dualv7-test/063x/uart-attach-tftp-nfsboot.log)
- [tcpdump-attach-tftp-nfsboot.log](/home/data/vivado-risc-v/workspace/dualv7-test/063x/tcpdump-attach-tftp-nfsboot.log)
- [dnsmasq-tftp.log](/home/data/vivado-risc-v/workspace/dualv7-test/063x/dnsmasq-tftp.log)

---

## Release `dualv7-r2-uboot-tftp-nfs`

**日期**：`2026-05-17`  
**状态**：`validated`  
**用途**：U-Boot 网络引导基线；JTAG 仅下 `bit + boot.elf`，由 U-Boot TFTP 拉起内核，Linux 挂 NFS root

### 1. 代码位置与 commit

| 组件 | 位置 | commit | tag | 说明 |
|---|---|---|---|---|
| 主工程 | `zzx@202:~/vivado-risc-v` | `137a01660c63948368aafd31fdabaf742314acd1` | `dualv7-r2-uboot-tftp-nfs` | bit 沿用 r1 已验证产物 |
| U-Boot 子仓 | `zzx@202:~/vivado-risc-v/u-boot` | `fe394fd6bba5105b0d2ef5793e617ede412defe0` | `dualv7-r2-uboot-tftp-nfs` | 含 U-Boot RX ring 修补与 netboot 可用驱动 |
| 本地 Linux | `/home/data/vivado-risc-v/linux-stable` | `567ee7b75dd6a078b7f02b839fae36b2c33563d2` | `dualv7-r2-uboot-tftp-nfs` | 当前实测用内核 |
| 本地 ramdisk | `/home/data/vivado-risc-v/ramdisk-realcheck-src` | `dc20df9580683175dd38c09d50eb1e46280aa1d6` | `dualv7-r2-uboot-tftp-nfs` | 当前 NFS root init，已知会退出 |

### 2. 产物缓存与 sha256

| 产物 | 路径 | sha256 |
|---|---|---|
| bit | `/home/data/vivado-risc-v/workspace/release-r2/rocket64b2-r2.bit` | `90cd6654e07aeef8107d714f5b9934172d37f83faf9a01b2b0f125df78b2ab47` |
| boot.elf | `/home/data/vivado-risc-v/workspace/release-r2/boot-r2.elf` | `bef224570468ce4c4f0486ca0c4f58c302970ffcff5e1d8b30be53feb39081e9` |
| TFTP/NFS root | `/home/data/vivado-risc-v/workspace/release-r2/nfsroot` | `目录工件，来源于 063x 已验证路径` |

### 3. 启动方式

1. JTAG 仅下载：
   - `rocket64b2-r2.bit`
   - `boot-r2.elf`
2. U-Boot 手工执行：
   - `ping 192.168.200.201`
   - `tftpboot 0x81000000 Image`
3. `bootargs` 指向：
   - `root=/dev/nfs`
   - `nfsroot=192.168.200.201:/home/data/vivado-risc-v/workspace/release-r2/nfsroot,vers=3,tcp,rw`
4. `booti 0x81000000 - 0x10080`

### 4. 固定入口

- [jtag-boot-r2.tcl](/home/data/vivado-risc-v/workspace/release-r2/jtag-boot-r2.tcl)
- [uboot-tftp-nfs-commands.txt](/home/data/vivado-risc-v/workspace/release-r2/uboot-tftp-nfs-commands.txt)
- [artifacts.txt](/home/data/vivado-risc-v/workspace/release-r2/artifacts.txt)

### 5. Host 侧依赖

- `nfs-kernel-server`
- `dnsmasq`（TFTP）
- UFW 放行：
  - `69/udp`
  - `111/tcp`
  - `2049/tcp`
  - `30000:65535/tcp+udp`

### 6. 验证结论

- U-Boot `ping 192.168.200.201`：✅
- U-Boot `tftpboot 0x81000000 Image`：✅
- Linux `VFS: Mounted root (nfs filesystem)`：✅
- JTAG **不再**下载 `Image` / ramdisk：✅

### 7. 已知限制

- 当前 `nfsroot/init` 仍是单次 REALCHECK 程序
- 执行完成后会触发：
  `Kernel panic - not syncing: Attempted to kill init!`
- 后续应在此 release 基线上继续修复常驻 init

### 8. 验证日志

- [uart-attach-tftp-nfsboot.log](/home/data/vivado-risc-v/workspace/dualv7-test/063x/uart-attach-tftp-nfsboot.log)
- [tcpdump-attach-tftp-nfsboot.log](/home/data/vivado-risc-v/workspace/dualv7-test/063x/tcpdump-attach-tftp-nfsboot.log)
- [dnsmasq-tftp.log](/home/data/vivado-risc-v/workspace/dualv7-test/063x/dnsmasq-tftp.log)

### 9. 与 r1 的关系

- bit 与本地 Linux 内核沿用 r1 已验证版本
- 主要增量来自：
  - U-Boot `vivado_mii` RX ring 修补
  - 固定的 U-Boot `TFTP -> Linux NFS root` 启动流程

### 10. 后续动作

1. 修复 REALCHECK 退出导致 panic
2. 在此基线上继续验证长期常驻 NFS root
3. 后续如切到 BusyBox/systemd，再单独做 r3

### 10.5 065x 后续 hotfix（未单独切 release）

- ramdisk 源仓提交：
  `7a2e40d46a94ab861b925be7a1ed8b55937fd002`
  (`Print REALCHECK hold marker before idle loop`)
- 本地 hotfix 工作目录：
  `/home/data/vivado-risc-v/workspace/release-r2-hotfix`
- 固定 `init` hash：
  `8e001f8608a3a2b6de01f441f49bee21a2bc9686898e28a98a324573be717e4d`
- 复测结果：
  - `workspace/release-r2-hotfix/uart-netboot-r2.log`
    中已出现：
    `VFS: Mounted root (nfs filesystem)`、
    `REALCHECK: READY`、
    `REALCHECK: done`、
    `REALCHECK: hold`

当前推荐执行路径已经切到 `release-r2-hotfix`，但为了保持
`dualv7-r2-uboot-tftp-nfs` 这个 release 的可追溯性，本 hotfix
暂不单独打新 release tag。

### 10.6 067x BusyBox NFS root 仓

- rootfs 工作目录：
  `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot`
- 本地仓：
  `/home/data/vivado-risc-v/busybox-nfsroot-src`
- commit：
  `6950e444f62889be56aeb6f3627ad8d9e7c402ee`

该仓不是 BusyBox 上游源码仓，而是当前**验证通过的 rootfs 仓**。
用于在 `release-r2-hotfix` 网络引导基线上替代 `REALCHECK hold`
占位用户态。

---

## Release `dualv7-r3-z2m-busybox-netboot`

**日期**：`2026-05-17`  
**状态**：`validated`  
**用途**：`rocket64z2m` 双核 bit + U-Boot TFTP 取内核 + Linux BusyBox NFS root

### 1. 代码位置与 commit

| 组件 | 位置 | commit | tag | 说明 |
|---|---|---|---|---|
| 主工程 | `zzx@202:~/vivado-risc-v` | `137a01660c63948368aafd31fdabaf742314acd1` | `dualv7-r3-z2m-busybox-netboot` | `rocket64z2m` bit 来源 |
| U-Boot 子仓 | `zzx@202:~/vivado-risc-v/u-boot` | `fe394fd6bba5105b0d2ef5793e617ede412defe0` | `dualv7-r3-z2m-busybox-netboot` | 固定 `boot-r3.elf` 来源 |
| 本地 Linux | `/home/data/vivado-risc-v/linux-stable` | `567ee7b75dd6a078b7f02b839fae36b2c33563d2` | `dualv7-r3-z2m-busybox-netboot` | 当前实测内核 |
| BusyBox rootfs 仓 | `/home/data/vivado-risc-v/busybox-nfsroot-src` | `6950e444f62889be56aeb6f3627ad8d9e7c402ee` | `dualv7-r3-z2m-busybox-netboot` | 当前可工作 BusyBox NFS rootfs |

### 2. 产物缓存与 sha256

| 产物 | 路径 | sha256 |
|---|---|---|
| bit | `/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/rocket64z2m-r3.bit` | `655d7dac2fa2ede5858ccf27038d246da4a4652122262a64509cb15d1690bc38` |
| boot.elf | `/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/boot-r3.elf` | `bef224570468ce4c4f0486ca0c4f58c302970ffcff5e1d8b30be53feb39081e9` |
| Image | `/home/data/vivado-risc-v/linux-stable/arch/riscv/boot/Image` | `e228bb35d02c84fc5878b45ac1d5f3ffbdfee7c13af07432b21a1e3797a0f553` |
| BusyBox | `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot/bin/busybox` | `aed8a697d1d6fdf475be9948239491ac396b1629ddb4847ce6f3f48f874bd63e` |

### 3. 启动方式

1. JTAG 仅下载：
   - `rocket64z2m-r3.bit`
   - `boot-r3.elf`
2. U-Boot 手工执行：
   - `ping 192.168.200.201`
   - `tftpboot 0x81000000 Image`
3. `bootargs` 指向：
   - `root=/dev/nfs`
   - `nfsroot=192.168.200.201:/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot,vers=3,tcp,rw`
4. `booti 0x81000000 - 0x10080`

### 4. 固定入口

- [jtag-boot-r3-z2m.tcl](/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/jtag-boot-r3-z2m.tcl)
- [uboot-tftp-nfs-commands.txt](/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/uboot-tftp-nfs-commands.txt)
- [artifacts.txt](/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/artifacts.txt)

### 5. Host 侧依赖

- `nfs-kernel-server`
- `tftpd-hpa`（当前实测服务）或等价 TFTP 服务
- 导出目录：
  `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot`

### 6. 验证结论

- OpenSBI `Platform HART Count = 2`：✅
- Linux `smp: Brought up 1 node, 2 CPUs`：✅
- U-Boot `ping 192.168.200.201`：✅
- U-Boot `tftpboot 0x81000000 Image`：✅
- Linux `VFS: Mounted root (nfs filesystem)`：✅
- BusyBox shell `[~] #`：✅
- `mount` / `ifconfig -a` / `cat /proc/net/dev`：✅

### 7. Timing 与限制

- `066x` post-route timing：
  - `WNS = -0.755ns`
  - `TNS = -2.854ns`
  - `WHS = +0.041ns`
- 当前 bit 已功能验证，但 **不是 timing clean**
- BusyBox NFS root 当前以只读方式挂载 `/`
- `rcS` 中重复挂载 `/dev` 会打印 `Device or resource busy`，属于噪音

### 8. 验证日志

- [uart-z2m-busybox.log](/home/data/vivado-risc-v/workspace/dualv7-test/068x/uart-z2m-busybox.log)
- [busybox-shell-proof.log](/home/data/vivado-risc-v/workspace/dualv7-test/068x/busybox-shell-proof.log)
- [uart-netboot-z2m.log](/home/data/vivado-risc-v/workspace/066x/uart-netboot-z2m.log)

### 9. 与 r2 的关系

- `boot.elf`、Linux 内核、BusyBox rootfs 沿用 `r2` 已验证软件基线
- 主要新增：
  - `rocket64z2m` 双核 bit
  - BusyBox NFS rootfs 作为常驻用户态

### 10. 后续动作

1. 若继续用 z2m 主线，优先在此 release 上扩展用户态与业务验证
2. 如需正式签核，再处理 z2m setup timing 违例

### 12. 后续 release 追加模板

后续新增 release 时，按下面格式在本文末尾追加：

```md
## Release `<name>`

**日期**：`YYYY-MM-DD`
**状态**：`validated` / `partial` / `broken`
**用途**：...

### 1. 代码位置与 commit
...

### 2. 产物缓存与 sha256
...

### 3. 构建流程
...

### 4. 验证脚本与日志
...

### 5. 验证结论
...
```

---
## Release `dualv7-z2m-20mhz-experimental`

**日期**：`2026-05-19`  
**状态**：`validated`  
**用途**：`rocket64z2m` (2×MegaBoom Z1) @ 20MHz — 实验线，非正式 release

### 1. 代码位置与 commit

| 组件 | 位置 | commit | 说明 |
|------|------|--------|------|
| 主工程 | `zzx@202:~/vivado-risc-v` | `137a0166` | 仅改 `board/dualv7/riscv-2025.1.tcl:737` CLKOUT1 10→20 |
| U-Boot | `zzx@202:~/vivado-risc-v/u-boot` | `fe394fd` | 复用 r2-hotfix |
| 本地 Linux | `/home/data/vivado-risc-v/linux-stable` | `567ee7b` | 复用 |
| BusyBox rootfs | `/home/data/vivado-risc-v/workspace/release-r2-busybox/nfsroot` | 含 telnetd |

### 2. 产物

| 产物 | 本地路径 | SHA256 |
|------|---------|--------|
| bit | `workspace/070x/rocket64z2m-20mhz.bit` | `4581d346...e40e87bb` |
| boot.elf | `workspace/release-r2-hotfix/boot-r2.elf` | 复用 |
| kernel | `linux-stable/arch/riscv/boot/Image` | `e228bb35...a0f553` |

### 3. 构建参数

- BOARD = `dualv7`
- CONFIG = `rocket64z2m`
- SoC 主频 = **20 MHz**（从原 10MHz 提升）
- 改动：`board/dualv7/riscv-2025.1.tcl` 中 `CLKOUT1_REQUESTED_OUT_FREQ` 10.000→20.000

### 4. Post-route Timing

| 指标 | 值 | 对比 10MHz 原值 |
|------|-----|----------------|
| WNS | +7.891 ns | -0.755 ns（改进） |
| TNS | 0.000 ns | -2.854 ns（改进） |
| WHS | +0.131 ns | +0.041 ns |

### 5. 验证结果

| 判据 | 状态 |
|------|------|
| 2 核启动 | ✅ `Brought up 1 node, 2 CPUs` |
| U-Boot ping | ✅ |
| TFTP 内核 | ✅ |
| NFS root 挂载 | ✅ |
| BusyBox shell | ✅ |
| telnetd 远程登录 | ✅ `telnet 192.168.200.250` |
| `mount/ifconfig/ps/uptime` | ✅ |

### 6. 已知限制

- 非 timing signoff（实验线）
- telnet 明文（直接以太网链路，无安全风险）
- 40MHz 构建进行中（`070x` 延伸）
