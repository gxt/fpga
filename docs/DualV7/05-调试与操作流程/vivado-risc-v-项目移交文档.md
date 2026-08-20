# vivado-risc-v 项目移交文档

**更新日期**：2026-07-29  
**交接范围**：本地管理仓、202 构建环境、DualV7 FPGA 上板基线，
以及仍未闭环的 SingleE V7 和 BOOM-stop 工作线。

---

## 1. 先看结论

项目当前有一条已经实测闭环、可直接复现的主线：

```text
DualV7 + MegaBoom
  JTAG 下载 bit + boot.elf
  -> U-Boot 静态网络
  -> TFTP 下载 Image
  -> Linux NFS root
  -> BusyBox telnet 登录
```

推荐的默认功能基线是 `rocket64z2m` 双核 Mega 的
`dualv7-r3-z2m-busybox-netboot`。

最近一次完成综合并完成全链路上板验证的版本是 097x：
`rocket64z1` 单核 Mega、20 MHz。它用于单核性能实验参考，
不替代 r3 的双核稳定基线。

下列工作不能视为已交付能力：

| 工作线 | 当前状态 | 交接判断 |
|---|---|---|
| DualV7 `z2m` 网络引导 | 已验证 | 当前默认入口 |
| DualV7 `z1` 20 MHz | 已验证 | 单核实验入口 |
| 40 MHz / 多档时钟 | 实验或阻塞 | 不作为发布基线 |
| SingleE V7 | DDR/MIG 实现受阻 | 尚不能启动 Linux |
| BOOM-stop 接入 | 最小补丁编译级验证 | 尚未形成可评测 FPGA bit |

### 1.1 接手优先顺序

1. 先复现 DualV7 `z2m` 的既有网络引导，不修改任何 RTL/TCL/XDC。
2. 将当前可用工件、日志和本机网络拓扑核验清楚。
3. 只有基线复现成功后，再选择继续 SingleE V7、频率或
   BOOM-stop 中的一条工作线。

不要以早期任务、40 MHz 实验或 BOOM donor 替换结果作为新工作的
默认起点。

---

## 2. 系统、机器与职责边界

| 对象 | 位置/地址 | 职责 |
|---|---|---|
| 本地管理与上板机 | `/home/data/vivado-risc-v` | 文档、任务、工件缓存、JTAG、UART、TFTP/NFS |
| 远端构建机 | `zzx@192.168.200.202:~/vivado-risc-v` | Chisel/RTL、Vivado 综合与实现、`boot.elf` 构建 |
| 板卡 | S2C Dual Virtex-7 TAI LM | 当前已验证目标板 |
| FPGA | `xc7v2000tflg1925-1` | DualV7 与 SingleE V7 均使用此器件型号 |
| 主机网络 | `192.168.200.201/24` | TFTP/NFS server |
| FPGA 网络 | `192.168.200.250/24` | U-Boot/Linux 静态地址 |

202 不能联网。需要的 Maven/SBT、工具和源码依赖应从已准备的本地或
远端缓存复用；不要在 202 上假设可以在线下载依赖。

远端主工程是 dirty worktree。接手后不要执行 `git reset --hard`、
`git checkout --` 或直接覆盖 `board/dualv7/` 文件。新实验应在远端
sandbox 副本中进行。

---

## 3. 本地仓库说明

本地仓库不是单纯的 RTL 源码仓，而是项目的管理、交付物和本地
验证工作区。根提交为 `e7b7f3a`，当前工作树含有大量未提交的项目
资料和工件；这些内容不能当作可随意清理的临时文件。

```text
/home/data/vivado-risc-v/
├── code-agent/             项目管理资料
├── doc/                    面向人阅读的流程、设计与报告
├── doc-v7-single/          SingleE V7 板卡资料与迁移路线
├── workspace/              release、bit、日志、脚本和实验工件
├── linux-stable/           本地 Linux 源码及可能变化的构建输出
├── busybox-nfsroot-src/    BusyBox NFS rootfs 源码
├── ramdisk-realcheck-src/  早期 REALCHECK initramfs 源码
├── bootrom/                Boot ROM 源码与构建材料
├── patches/                Linux/U-Boot/OpenSBI/外设驱动补丁
├── boom-fpga/              BOOM-stop 参考工程及子仓
├── tests/                  本地小型辅助脚本
├── CHATGPT.md              AI 工作规则
└── CLAUDE.md               角色、任务模板和当前配置摘要
```

### 3.1 `code-agent/`：先读这里

| 路径 | 用途 |
|---|---|
| `code-agent/knowledge/` | 已收口的项目事实。新工作先读索引和相关专题。 |
| `code-agent/tasks/` | 按编号保存的原始任务、步骤、完成区和实验结果。 |
| `code-agent/reports/` | 若干任务的独立报告。 |
| `code-agent/CC_HANDOFF_2026-05-07.md` | 早期交接记录，仅作历史参考。 |

知识库的优先入口是：

- [知识库索引](../code-agent/knowledge/README.md)
- [已收口工作与当前基线](../code-agent/knowledge/16-closed-work-and-current-baseline.md)
- [项目结构](../code-agent/knowledge/01-project-structure.md)
- [构建命令](../code-agent/knowledge/02-build-commands.md)
- [DualV7 板卡事实](../code-agent/knowledge/03-board-dualv7.md)

### 3.2 `doc/`：交付和使用文档

这里保留给接手者直接使用的流程、架构、release 与专题结论。
优先阅读：

- [DualV7 Release 清单](DualV7-Release清单.md)
- [DualV7 FPGA 本地操作流程](DualV7-FPGA本地操作流程.md)
- [DualV7 z2m 网络引导与 telnet 恢复手册](DualV7-z2m-网络引导-telnet恢复手册.md)
- [DualV7 当前 SoC 架构与频率说明](DualV7-当前SoC架构与频率说明.md)
- [vivado-risc-v 编译流程](vivado-risc-v-编译流程.md)

`doc/` 中有大量 BOOM-stop、XiangShan 与历史调研文档。它们是有价值的
材料，但不等价于当前 FPGA 主线的发布说明；使用时应结合对应任务与
证据等级判断。

### 3.3 `workspace/`：工件的真实位置

`workspace/` 占用约 2.2 GB，保存 release、bit、NFS root、UART 日志和
单任务实验目录。其分层约定如下：

| 路径 | 含义 |
|---|---|
| `workspace/releases/` | 整理过的 release 工件真实目录 |
| `workspace/experiments/` | 单任务实验目录 |
| `workspace/metadata/` | 知识图谱、staging 等元数据 |
| `workspace/095x/` | z2m 网络引导恢复脚本与实测日志 |
| `workspace/096x/` | z1 单核网络引导脚本与实测日志 |
| `workspace/097x/` | z1 20 MHz bit、JTAG/host 辅助脚本与日志 |

根下 `workspace/release-*`、`workspace/070x` 等一些路径是兼容旧文档
的符号链接。不要为了“整理目录”而移动它们，否则会打断已有脚本和
绝对路径引用。

### 3.4 本地源码与补丁目录

- `linux-stable/`：约 3.5 GB。本地 Linux 源码树；其
  `arch/riscv/boot/Image` 是会变化的构建输出，不能默认当成历史
  验证过的内核。
- `busybox-nfsroot-src/`：当前 BusyBox rootfs 源码；r3 基线使用它。
- `ramdisk-realcheck-src/`：早期单次 REALCHECK 启动方式的源码，
  不应作为当前 telnet 基线的首选。
- `patches/`：板级驱动和软件改动的补丁副本，含 Ethernet、SD、UART、
  U-Boot、OpenSBI、Linux 等。
- `boom-fpga/`：BOOM-stop 参考输入。硬件差异应优先查看其
  `boom-dev` 子仓；`boom_stop/example/ptrace` 主要用于生成评测程序。

---

## 4. 当前可复现的 DualV7 基线

### 4.1 默认：双核 Mega 网络引导

| 项目 | 值 |
|---|---|
| Release | `dualv7-r3-z2m-busybox-netboot` |
| CONFIG | `rocket64z2m` |
| CPU | 2 × MegaBoom Z1，RV64IMAFDC |
| bit | `workspace/releases/release-r3-z2m-busybox/rocket64z2m-r3.bit` |
| bit SHA256 | `655d7dac2fa2ede5858ccf27038d246da4a4652122262a64509cb15d1690bc38` |
| boot.elf | `workspace/releases/release-r3-z2m-busybox/boot-r3.elf` |
| 主线能力 | JTAG、U-Boot ping/TFTP、Linux NFS root、BusyBox telnet |

这条基线功能已验证，但实现时序并未完全收敛。记录的结果为
`WNS=-0.755ns`、`TNS=-2.854ns`、`WHS=+0.041ns`。
因此它适合继续功能、软件和系统调试；若要做严格频率或性能结论，
应先完成独立的 timing 收敛工作。

当前硬件主域为 10 MHz，而不是文档或软件变量中偶尔出现的 20 MHz：

| 域 | 当前 r3 实际频率 |
|---|---:|
| Mega 核与 SoC 主 AXI | 10 MHz |
| UART/SD 等外设域 | 100 MHz |
| MIG 参考时钟 | 200 MHz |
| DDR3 PHY | 400 MHz，等效 800 MT/s |
| 软件可见 timer | 200 kHz |

完整架构、地址映射和频率证据见
[当前 SoC 架构与频率说明](DualV7-当前SoC架构与频率说明.md)。

### 4.2 最近一次全链路验证：单核 Mega 20 MHz

097x 在 2026-07-02 完成：

| 项目 | 值 |
|---|---|
| CONFIG | `rocket64z1` |
| CPU | 单核 MegaBoom Z1 |
| bit | `workspace/097x/rocket64z1-20mhz.bit` |
| SHA256 | `93ab49ce60697e82a37992dc5bb78a9b6ced2a070257b2d87d09aa0ec0708e7b` |
| 上板结果 | JTAG、U-Boot ping、TFTP、Linux NFS root、telnet 全通过 |

097x 的 build 过程记录在
[097x 任务](../code-agent/tasks/097x-dualv7-z1-20mhz-bit.md)。
它有 JTAG、host 准备和 telnet 检查辅助脚本，但没有独立的一键综合
封装脚本；综合步骤仍以任务文件中的已验证命令为准。

### 4.3 推荐的恢复操作

先使用 z2m 的恢复脚本确认环境：

```bash
cd /home/data/vivado-risc-v
bash workspace/095x/restore_netboot_z2m_20mhz.sh
python3 workspace/095x/telnet_check.py
```

该流程会准备主机侧 TFTP/NFS、通过 JTAG 下载 bit 与 `boot.elf`，
再由串口驱动 U-Boot 完成 TFTP/NFS 引导。完整操作和故障处理见
[z2m 恢复手册](DualV7-z2m-网络引导-telnet恢复手册.md)。

恢复时使用冻结工件 `workspace/release-r2-hotfix/nfsroot/Image`
或脚本所选定的 release Image。不要不加核验地改用
`linux-stable/arch/riscv/boot/Image`。

---

## 5. 板卡与接口事实

### 5.1 DualV7

- 板卡：S2C Dual Virtex-7 TAI LM。
- 主时钟：100 MHz LVDS，`s2cclk_1_p/n`，引脚 L4/L3。
- 复位：SW1，AP31，低有效。
- JTAG：Digilent JTAG-SMT2，使用 `hw_server` 和 `xsdb`。
- 当前稳定 UART：
  `/dev/serial/by-id/usb-1a86_5523-if00-port0`，115200 baud。
- 以太网 PHY：KSZ8081MNX，MII，10/100 Mbps，LVCMOS18。
- DDR：64-bit、双 rank DDR3，MIG UI 100 MHz。

MIG、DDR 约束、PHY 引脚和启动链的细节均以
[DualV7 板卡知识库](../code-agent/knowledge/03-board-dualv7.md)为准。

### 5.2 网络与本地服务

当前网络引导为静态地址拓扑：

```text
本地主机 enp1s0: 192.168.200.201
       |  TFTP: Image；NFSv3: rootfs
       +------------------------------+
                                      |
DualV7 FPGA eth0: 192.168.200.250 ---+-- KSZ8081 MII PHY
```

关键服务是 `hw_server`、TFTP（通常为 dnsmasq）和 NFS server。
首次使用前还需检查 UART 权限；当前用户若不在 `dialout` 组，现有
脚本会尝试临时授权，手动操作也可用 `setfacl`。

### 5.3 启动链

当前推荐链路不依赖 SD 启动：

```text
JTAG: bit + boot.elf
  -> OpenSBI + U-Boot
  -> U-Boot ping / tftpboot Image
  -> Linux booti
  -> NFS root
  -> BusyBox telnetd
```

SDC 的接口约束与历史 smoke 留作后续工作，不应在首次接手时加入变量。

---

## 6. 综合、实现与产物管理

### 6.1 202 环境

在 202 使用：

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
cd ~/vivado-risc-v
```

不要 `source env.sh`，该文件在现场并不稳定存在。

典型 bit 目标是：

```bash
make BOARD=dualv7 CONFIG=rocket64z1 vivado-project
make BOARD=dualv7 CONFIG=rocket64z1 MAX_THREADS="$(nproc)" \
  workspace/rocket64z1/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/\
  riscv_wrapper.bit
```

不同版本的 Makefile 可能没有 `make verilog` 这个伪目标；应优先使用
文档中对应的文件目标。完整构建链、软件构建路径、MCS 坑和日志判断
规则见 [编译流程](vivado-risc-v-编译流程.md)。

### 6.2 构建的纪律

- 长时间 Vivado 作业使用 `nohup`，日志写到 `/tmp/<task>.log`。
- `make ... | tee ...` 必须启用 `set -o pipefail`，否则可能掩盖失败。
- `make bitstream` 生成 `.bit` 后还会尝试生成 `.mcs`；MCS 的 SPI
  宽度错误不代表 `.bit` 本身不可用。
- 判断成功时同时检查目标 `.bit`、实现日志、timing 报告和错误摘要。
- 新实验不覆盖 202 主仓，复制到编号 sandbox 中执行。

### 6.3 软件构建的路径差异

202 的 `~/vivado-risc-v/linux-stable` 并非完整内核树；完整的远端
内核在 `/home/zzx/vivado/sw/linux`。本地 `linux-stable/` 则是另一条
本地源码与工件线。两者的内核版本、配置和生成 Image 不可混用。

---

## 7. 未闭环工作线

### 7.1 SingleE V7 移植

SingleE V7 与 DualV7 器件型号相同，但板级连接不同。已完成的
LED/JTAG/UART 最小 smoke 说明基本板级链可用；当前主要阻塞在 DDR3
MIG 的实现阶段。

观察事实：

- `rocket64b2 + singlev7` 可通过综合，也曾生成过不含正确 DDR 迁移的
  bit 并完成 JTAG 下载。
- DDR 官方生成路径和手工路径都在 `impl_1` 遭遇 `MDRV-1`。
- 官方生成的约束仍包含 `OLOGIC_XY` 占位，MIG 相关实现问题未收敛。

这里应谨慎表述为“已观察到 MIG 内部 DRC/MDRV-1 阻塞”，而不是直接
断言已经证明某个 Xilinx IP bug 的根因。

入口：

- [SingleE V7 移植知识库](../code-agent/knowledge/21-single-v7-porting.md)
- [094x 报告](../code-agent/reports/094x-singlev7-rocket64b2-mig-regenerate-debug.md)
- [SingleE V7 + Mega + BOOM-stop 路线图](../doc-v7-single/SingleE-V7-Mega-Boomstop-Roadmap.md)

建议下一步：先独立收敛 SingleE V7 的 DDR/MIG 生成与实现问题，
不要与 Mega、BOOM-stop、网络或 SDC 同时推进。

### 7.2 BOOM-stop

BOOM-stop 的机制、设计偏差、正确性和防篡改分析已沉淀；但它尚未成为
当前 DualV7 上可用的性能评测实现。

已经排除：

- 直接用完整 `boom_stop` fork 替换 BOOM。
- 将 `boom-dev` 当作当前 Mega 基线的 drop-in donor 直接替换。

仍然值得继续的是：在当前 Mega 基线上按语义提取的“同基线最小 patch
merge”。该路线已有 `sbt "boom/compile"` 级别验证，但剩余事件闭合、
overflow/redirect 与 UCSR 路径尚未完成，也未推进为可上板 bit。

入口：

- [BOOM-stop 交接说明](BOOM-stop-交接说明.md)
- [BOOM-stop 机制与防篡改说明](BOOM-stop-机制与防篡改说明.md)
- [BOOM-stop 知识库](../code-agent/knowledge/09-boom-stop.md)
- [BOOM-FPGA RTL 路线方案](BOOM-FPGA-RTL路线开展方案.md)

### 7.3 频率实验

- 20 MHz 单核 `rocket64z1`：097x 已上板并完成网络引导验证。
- 40 MHz：属于实验线，不是 release；不能直接作为性能评测基线。
- 076x 多档 `soc_clk`：由于 BUFGMUX 多 SLR 布局失败而阻塞。

提频前须先明确时钟源、DTS/timebase、外设跨域和实现 timing 的统一
口径，不能只观察“系统启动成功”。

---

## 8. 关键历史结论

### 8.1 XiangShan

XiangShan 的 FPGA 综合与资源分析是调研工作，未成为当前 DualV7
可运行 SoC 主线。其逻辑规模、LUT 占用和 cache/blackbox 问题不应与
当前 Mega 基线混写。

### 8.2 网络

网络问题已从早期的硬件不确定性收敛为可用链路：Linux 与 U-Boot 的
IPv4、TFTP、NFS root 已经有实测证据。后续网络问题应先复现固定
release，再按 PHY、MAC、U-Boot、Linux、主机服务分层定位。

复盘见 [网络调试复盘](../code-agent/knowledge/13-network-debug-postmortem.md)。

### 8.3 DDR 与 Boot ROM

在当前设计中 Boot ROM 运行和 JTAG 启动都依赖可工作的 DDR；
“先跳过 DDR 看 UART”通常不可成立。对新板先建立 DDR 可观测证据，
再进入软件启动调试。

---

## 9. 任务与资料索引

| 主题 | 优先任务/文档 |
|---|---|
| 当前 z2m 网络引导恢复 | 095x、[恢复手册](DualV7-z2m-网络引导-telnet恢复手册.md) |
| z1 单核网络引导 | 096x、[z1 手册](DualV7-z1-单核Mega网络引导手册.md) |
| z1 20 MHz 综合与验证 | [097x](../code-agent/tasks/097x-dualv7-z1-20mhz-bit.md) |
| release 与工件哈希 | [DualV7 Release 清单](DualV7-Release清单.md) |
| 远端构建流程 | [编译流程](vivado-risc-v-编译流程.md) |
| DualV7 板卡/DDR/PHY | [§03 知识库](../code-agent/knowledge/03-board-dualv7.md) |
| BOOM-stop 继续接入 | 078x、079x、080x、084x、085x 与 `doc/BOOM-stop-*` |
| BOOM donor 替换失败证据 | 082x、083x 与对应报告 |
| SingleE V7 DDR 阻塞 | 092x、093x、094x 与对应报告 |

任务文件的结论有新旧之分。凡是与本移交文档冲突，应优先查看较新的
任务完成区、release 清单和知识库修订，而不是只引用任务标题或计划。

---

## 10. 接手检查清单

1. 确认本地仓库、202 账号和 Vivado 许可证可访问。
2. 确认板卡连接、`hw_server`、UART symlink 和 `enp1s0` 地址。
3. 校验 r3 bit 与 097x bit 的 SHA256，确认工件没有漂移。
4. 按 095x 恢复 `z2m` 网络引导，并完成 telnet 登录。
5. 保存本次 UART、TFTP/NFS 和 telnet 日志，作为接手时的起始证据。
6. 决定只推进一条未闭环工作线，并先建立新的任务文件与 sandbox。

达到第 4 步后，才可以认为接手环境具备继续项目的基本条件。

---

## 11. 交接后的推荐行动

若目标是保持现有系统可用：固化 095x/r3 的一键恢复与工件校验，
再清晰区分“功能验证基线”和“timing 已收敛的发布基线”。

若目标是新板：先解决 SingleE V7 DDR/MIG 实现阻塞。

若目标是性能评测：先完成 BOOM-stop 最小 patch 的语义闭合，随后在
已验证的单核 Mega/DualV7 基线上完成 RTL、bit 与测量链的逐层验证；
不要直接把现有 BOOM-stop 分析结论当作可用于真实评测的实现保证。
