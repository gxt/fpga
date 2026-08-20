# DualV7 开发资料集（供其它仓库读取使用）

> 本目录是从 `vivado-risc-v` 工作区复制出来的 **DualV7（S2C Dual Virtex-7 TAI LM）开发资料全集**，
> 供在其它 CPU 类项目仓库中做本板 FPGA 开发/调试时参考。
> 复制日期：2026-08-20。
>
> **与本板当前 RISC-V 工程（vivado-risc-v）的产物差异说明**：本目录只含**资料**，
> 不含源码与 bit 产物。原仓库中可复用的 bit / boot.elf / 内核 / rootfs 工件路径见
> 第 6 节"固定工件位置（原仓库）"。

---

## 目录索引

| 目录 | 内容 |
|------|------|
| `01-板卡与FPGA硬件/` | 板卡手册（PDF）、FPGA 芯片信息、SoC 架构与频率、资源占用 |
| `02-原理图与PCB/` | 子卡 MPRC-V7FPGA 原理图（PDF）、PCB（.brd）、工程文件（.DSN） |
| `03-管脚对应表/` | J8/J9/J10 插座管脚对应表（xlsx）+ 含全部管脚表的 Chipyard 详细设计 |
| `04-子卡与外设芯片/` | 子卡芯片汇总说明 + 各外设芯片数据手册（USB/MAC/Flash/内存条 PDF） |
| `05-调试与操作流程/` | 串口/JTAG/网络引导/编译流程文档 + 可直接复制的 xsdb/U-Boot 脚本 |
| `06-知识库/` | 板卡规格、以太网、UART、SD 卡、双 FPGA、XDC 约束等专题知识 |
| `07-上板流程包/` | 从仓库到上板的一键流程包（dualv7-from-scratch-kit） |

---

## 1. 快速上手：先读这 3 份

1. `05-调试与操作流程/DualV7-FPGA本地操作流程.md`
   —— 本板调试总入口：串口、JTAG Boot、U-Boot 网络引导、成功判据、常见坑。
2. `06-知识库/16-closed-work-and-current-baseline.md`
   —— 已收口工作与当前基线，告诉你在本板上做新工作的默认起点。
3. `04-子卡与外设芯片/子卡芯片与连接方案.md`（本目录新建）
   —— 子卡三块功能板（B1/B2/B3）→ J10/J9/J8 的芯片与连接总览。

---

## 2. 板级关键参数速查（Fact）

| 项目 | 值 |
|------|-----|
| 主板 | S2C Dual Virtex-7 TAI Logic Module（V7 TAI LM） |
| FPGA | 2× Xilinx **XC7V2000T**（FLG1925，-1L）；Vivado part `xc7v2000tflg1925-1`；**当前仅用 F1** |
| 主时钟 | `s2cclk_1_p/n` **100 MHz LVDS**，F1 引脚 **L4(P)/L3(N)**（XDC：`DIFF_HSTL_II_18`） |
| 复位 | SW1，F1 **AP31**，active-low，`PULLUP TRUE` |
| 内存 | DDR3 SO-DIMM（J14），**MT41K256M16XX-125**，64-bit 双 rank，MIG 400MHz/800MT/s，基址 `0x80000000` |
| UART | `AU42`(TX)/`AV42`(RX)，115200 8N1，主机 `/dev/ttyUSB2`（CH341，symlink `usb-1a86_5523-if00-port0`） |
| 以太网 PHY | **KSZ8081MNX**（J9 BIOS 子卡），MII 10/100M，PHYAD=1，IO=LVCMOS18 |
| SD 卡 | J8 子卡 TF 槽（MMC1，4-bit，LVCMOS18），`sdio_clk=AT37, cmd=AT38, dat[3:0]=BA43/AY43/AW44/AW43, cd=BA39` |
| LED | LED0/1/2 = `AH44`/`AH43`/`AL40`，active-high |
| JTAG | Digilent JTAG-SMT2（FT2232H），`hw_server` on localhost:3121 |
| 主机网卡 | `enp1s0`，主机 `192.168.200.201/24`，FPGA `192.168.200.250` |
| Config Voltage | 1.8V，CFGBVS=GND |

### SoC 主频现状（Fact）

| 配置 | 核 | SoC 主频 | Timing 状态 |
|------|-----|---------|-------------|
| `rocket64b2` | 1×Big Rocket | 10 MHz | ✅（release-r2 基线） |
| `rocket64z2m`（r3） | 2×MegaBoom Z1 | 10 MHz | ⚠️ 功能验证过，WNS=-0.755ns，非 timing clean |
| `rocket64z2m`（20MHz 实验） | 2×MegaBoom Z1 | 20 MHz | ✅ WNS=+7.891ns（时序反而更好） |
| `rocket64z2m`（40MHz 实验） | 2×MegaBoom Z1 | 40 MHz | ❌ 严重 setup 违例，仅实验 |

时钟树：SoC 主域 10/20MHz（clk_wiz clk_out1）；UART/SD 外设域 100MHz（clk_out3）；
MIG 参考 200MHz（clk_out2）；DDR3 PHY 400MHz（800MT/s）；Ethernet MII 侧 25MHz（PHY 提供）。

---

## 3. 子卡与主板连接（速览）

本板子卡为 **MPRC-V7FPGA CARD V1.2**，三个功能块通过 DB1/DB2/DB3 插到主板 J10/J9/J8：

| 功能块 | 主板连接器 | 关键芯片 |
|--------|-----------|---------|
| **B1** | J10（PCI） | PCI 插槽/缓冲/时钟、PCI→USB 桥（**当前未用**） |
| **B2** | J9（BIOS） | **KSZ8081MNX**（100M MII PHY）、双 SPI Flash 插座（X86/Uni）、CH7055A（VGA）、PS2、ICE86、AT24C02N（I2C MAC EEPROM） |
| **B3** | J8（EMMC/MMC） | **USB3318**（ULPI USB PHY，13MHz）、**FE2.1**（USB2.0 HUB）、**SDIN5D2-4G**（iNAND 4GB eMMC）、**TF 卡槽**（4-bit MMC1）、UART0/1、CF 卡槽 |

当前 RISC-V 工程实际使用：**J8**（UART0 + SD/TF 卡 + LED）、**J9**（MII 以太网）、**J14**（DDR3）。
USB（USB3318）、iNAND、CF、PCI、VGA、PS2 等均未接入 SoC。

详见 `04-子卡与外设芯片/子卡芯片与连接方案.md`（含完整引脚表）。

---

## 4. 各目录详细说明

### 4.1 `01-板卡与FPGA硬件/`

| 文件 | 说明 |
|------|------|
| `Dual V7 Hardware Reference Manual.pdf` | 主板硬件手册 v1.08（时钟/IO/连接器/电源） |
| `S2C-DualV7-FPGA硬件说明.md` | 板卡概览、FPGA 资源、连接器、外设引脚、烧录/串口指南（当前工程口径） |
| `V7-FPGA-HW-Description.md` | 硬件描述：时钟、DDR3/MIG、SPI、UART、GPIO、以太网 MII 引脚、SoC 地址空间 |
| `DualV7-当前SoC架构与频率说明.md` | 当前 z2m SoC 架构、MMIO 地址、完整时钟树、timing 结论 |
| `Mega-Core-资源结构说明.md` | MegaBoom 资源占用（LUT/Reg/BRAM）、时序、总线层次 |
| `Chipyard-1.13.0-DualV7-*.md` | Chipyard 集成设计、最小 bit 上板报告、RTL 接口差异、BOOM 适配方案 |
| `DualV7-z2m频率提升调研报告.md` | 10/20/40MHz 提频调研 |

### 4.2 `02-原理图与PCB/`

| 文件 | 说明 |
|------|------|
| `MPRC-V7FPGA_SCHV12_20230526.pdf` | **子卡原理图**（21 页，可读 PDF，含全部芯片） |
| `MPRC-V7FPGA_SCHV12_20230526.DSN` | 子卡原理图 OrCAD 工程 |
| `MPRC-V7FPGA_PCBV12_20230526.brd` | 子卡 PCB（Allegro） |

> 主板自身 PCB/原理图不在本资料集中（S2C 未随项目提供）；主板关键信息由
> `Dual V7 Hardware Reference Manual.pdf` + J8/J9/J10 管脚表覆盖。

### 4.3 `03-管脚对应表/`

| 文件 | 说明 |
|------|------|
| `S2C-V7-J8-EMMC插座管脚对应表20230801.xlsx` | J8：SD/MMC、USB、UART、QIDE/CF 等（**F1 管脚=FPGA1 管脚**） |
| `S2C-V7-J9-BIOS插座管脚对应表20201012.xlsx` | J9：MII 以太网、SPI、ICE86、VGA、I2C、PS2 |
| `S2C-V7-J10-PCI插座管脚对应表20200925.xlsx` | J10：PCI 总线信号（未使用） |
| `Chipyard详细设计.md` | **内含 J8/J9/J10 三张管脚表完整文本**（无 Excel 时看这份）+ 外设芯片参数 |

### 4.4 `04-子卡与外设芯片/`

| 文件 | 说明 |
|------|------|
| `子卡芯片与连接方案.md` | **（本资料集新建）** 子卡 B1/B2/B3 芯片清单与连接总览，含引脚表 |
| `USB3318.pdf` | USB PHY 数据手册（ULPI，13MHz REFCLK，60MHz CLKOUT） |
| `KSZ8081MNX-RNB Data Sheet v1.0.pdf` | 以太网 PHY 数据手册（MII 时序、寄存器、strap） |
| `w25q32fv_3v3.pdf` | SPI Flash 数据手册（4MB，25 系列） |
| `M471B5773内存条.pdf` | DDR3 SO-DIMM 内存条资料 |
| `V7_FPGA_DDR3内存条.pdf` | DDR3 内存条接口/时序参数 |

### 4.5 `05-调试与操作流程/`

| 文件 | 说明 |
|------|------|
| `DualV7-FPGA本地操作流程.md` | **调试主流程**：hw_server、JTAG Boot TCL、UART 交互、NFS/TFTP 网络引导、成功判据、常见坑 |
| `DualV7-z2m-网络引导-telnet恢复手册.md` | z2m（20MHz）网络引导 + telnet 一键恢复手册 |
| `DualV7-z1-单核Mega网络引导手册.md` | z1 单核 Mega 网络引导手册 |
| `DualV7-Release清单.md` | r1/r2/r3/20MHz 各 release 的 commit、产物 sha256、构建与验证结论 |
| `DualV7-子卡网络IP方案报告.md`、`DualV7-网络IP外部方案调研.md` | 以太网方案调研 |
| `vivado-risc-v-编译流程.md`（+简版） | 远端构建 bit/boot.elf 流程 |
| `vivado-risc-v-项目移交文档.md` | 项目移交文档 |
| `scripts/` | **可直接复用的 xsdb TCL / U-Boot 命令 / 工件清单**（见下） |

`scripts/` 内容：

| 文件 | 用途 |
|------|------|
| `jtag-boot-z2m-20mhz.tcl` | 下载 z2m 20MHz bit + boot-r2.elf（当前推荐恢复入口） |
| `jtag-boot-20mhz.tcl` / `jtag-boot-40mhz.tcl` | 20MHz/40MHz 实验 bit |
| `jtag-boot-z1.tcl` | 单核 Mega z1 bit |
| `jtag-boot-r3-z2m.tcl` | r3 双核 10MHz 基线 |
| `jtag-boot-r2.tcl` | r2 网络引导基线 |
| `uboot-tftp-nfs-commands.txt` / `r3-uboot-tftp-nfs-commands.txt` | U-Boot TFTP+NFS 命令序列 |
| `手动测试流程-20mhz.md` | 20MHz 手动测试分步流程与判据 |
| `095x-README.md` / `096x-README.md` | 095x（z2m）/096x（z1）恢复工件说明 |
| `artifacts.txt` | r3 工件清单 |

> 这些 TCL/脚本内引用的 bit/elf 路径是原仓库绝对路径；在其他仓库使用前需把
> `fpga -file ...` / `dow -clear ...` 换成自己的产物路径（见第 6 节固定工件）。

### 4.6 `06-知识库/`

从 `code-agent/knowledge/` 复制与 DualV7 相关章节（保留原文件名与 §编号）：

| 文件 | 主题 |
|------|------|
| `01-project-structure.md` | 仓库结构 |
| `02-build-commands.md` | 构建命令 |
| `03-board-dualv7.md` | **板卡规格大全**：时钟/复位/PHY/UART/JTAG/DDR3-MIG/SD/启动链/网络基线 |
| `04-ethernet.md` | 以太网：PHY 事实、MII 方案对比、调试复盘 |
| `05-uart.md` | UART 实现对比与引脚 |
| `06-bus-architecture.md` | 总线架构（TileLink vs AXI4、MEM/IO/DMA） |
| `07-sdc-boot.md` | SD 卡启动硬件事实与坑 |
| `08-dual-fpga.md` | 双 FPGA 架构（F1/F2、Inter-FPGA、Shared IO） |
| `13-network-debug-postmortem.md` | 网络调试复盘 |
| `16-closed-work-and-current-baseline.md` | **当前基线入口（新工作必读）** |
| `20-xdc-constraints.md` | XDC 约束设计决策（top/uart/ethernet 引脚写法） |
| `README.md` | 知识库索引 |

### 4.7 `07-上板流程包/dualv7-from-scratch-kit/`

从仓库到上板的一键流程（`run_r1_end_to_end.sh`）：
远端 202 建 sandbox 生成 bit/boot.elf → 本地生成 Image/ramdisk → JTAG+UART smoke。
含 5 个脚本与 `TESTED.md`。适合验证"从零到板"闭环，可作为其它 CPU 项目移植的模板。

---

## 5. 串口调试方案（速查）

```bash
# 1) 设备
UART=/dev/serial/by-id/usb-1a86_5523-if00-port0   # = /dev/ttyUSB2 (CH341)

# 2) 配置
stty -F "$UART" 115200 raw -echo -echoe -echok

# 3) 查看（Ctrl+C 退出）
cat "$UART"

# 4) 打断 U-Boot autoboot（看到 "Hit any key to stop autoboot:" 后发回车）
echo -ne '\r' > "$UART"

# 5) 交互终端
picocom -b 115200 "$UART"          # Ctrl+A Ctrl+X 退出
# 或 screen /dev/serial/by-id/usb-1a86_5523-if00-port0 115200
```

**JTAG 链路**：`hw_server`（监听 3121）→ `xsdb` 执行 `jtag-boot-*.tcl`。
**网络链路**：主机 `enp1s0` = `192.168.200.201/24`，FPGA = `192.168.200.250`；
U-Boot `ping`→`tftpboot Image`→`booti`，Linux 挂 NFS root。

---

## 6. 固定工件位置（原仓库，不在本资料集内）

以下产物存在于原仓库 `/home/data/vivado-risc-v/`，本资料集只记录路径与 sha256：

| 用途 | 路径 | 备注 |
|------|------|------|
| release-r1 bit | `workspace/release-r1/rocket64b2-r1.bit` | sha256 `90cd6654...` |
| r2 boot.elf | `workspace/release-r2-hotfix/boot-r2.elf` | **网络引导通用** |
| r3 z2m bit | `workspace/release-r3-z2m-busybox/rocket64z2m-r3.bit` | sha256 `655d7dac...` |
| z2m 20MHz bit | `workspace/070x/rocket64z2m-20mhz.bit` | sha256 `4581d346...` |
| z2m 40MHz bit | `workspace/070x/rocket64z2m-40mhz.bit` | 实验 |
| z1 bit | `workspace/experiments/dualv7-test/035x/rocket64z1.bit` | sha256 `160dc430...` |
| 冻结内核 Image | `workspace/release-r2-hotfix/nfsroot/Image` 或 `/srv/tftp/Image` | **勿用 `linux-stable/.../Image`（会漂移）** |
| BusyBox rootfs | `workspace/release-r2-busybox/nfsroot` | NFS root |
| 远端构建机 | `zzx@192.168.200.202:~/vivado-risc-v` | Vivado 2025.1，离线 |

完整 commit/sha256 见 `05-调试与操作流程/DualV7-Release清单.md`。

---

## 7. 本板开发注意事项（重点坑，Fact + 经验）

1. **bit 与 boot.elf 必须配套**（同一次构建），混用会导致网络/外设异常。
2. **UART 走 `/dev/ttyUSB2`（CH341），不是 Digilent 的 `ttyUSB1`**（后者是 JTAG-SMT2 的 channel B，无 FPGA 数据）。
3. **当前推荐 JTAG Boot 主线**：只下 bit + boot.elf，内核由 TFTP 取，rootfs 用 NFS；
   不在 JTAG 里 `dow -data Image/ramdisk`。
4. **`linux-stable/arch/riscv/boot/Image` 是漂移构建产物**，恢复用冻结内核
   （`release-r2-hotfix/nfsroot/Image` 或 `/srv/tftp/Image`）。
5. **KSZ8081MNX 不支持 SGMII/RGMII/GMII**，只能 MII（10/100M）；PHY 中断脚未引出，
   需在 BD 里用常量 0 替代 `eth_mdio_int`。
6. **UART CTS/RTS 无板级连接**：`ctsn` 需在 BD 里拉低（xlconstant=0），否则 TX 永久阻塞。
7. **MIG part 格式坑**：`xc7v2000t-flg1925/-1`（ISE 格式），不是 `xc7v2000tflg1925-1`；
   `CLOCK_DEDICATED_ROUTE` 需在 post_opt 设置；rank-1 引脚约束不能写在 `ddr3.xdc`。
8. **BootROM 依赖 DDR**：`_start` 第一行就写 DDR（sp 在 `0x80002000`），DDR 未就绪则挂死；
   调试建议走 JTAG Boot（完全绕过 BootROM/SD）。
9. **SD 卡 MMC1 已接入**（含 card-detect `TFCD→sdio_cd=BA39`），不是"缺卡检测线"；
   Linux 卡检测问题应从 `sdc_get_cd()` 路径排查。
10. **SD 卡上电自动 Boot** 与 **JTAG Boot** 是两条不同入口；当前软件验证主线是 JTAG Boot。
11. **MegaBoom 双核 10MHz r3 不是 timing clean**（WNS=-0.755ns）；20MHz 反而 clean。
    40MHz 仅实验。做正式发布需单独收敛频率口径（软件声明 20 vs 硬件实际 10 的坑已记录）。
12. **`rocket64z2m` 双核软件链已可用**：OpenSBI `2 HART` + U-Boot TFTP + BusyBox NFS root + telnetd。
13. 串口权限问题：用户不在 `dialout` 组时用 `sudo setfacl -m u:$USER:rw /dev/ttyUSB0`。

---

## 8. 本资料集的新增/缺失说明

**新增（本资料集创建）**：
- `README.md`（本文件）
- `04-子卡与外设芯片/子卡芯片与连接方案.md`

**未纳入本资料集（原仓库才有）**：
- 源码与构建工程（`vivado-risc-v` 主仓、`linux-stable`、`busybox-nfsroot-src`、`bootrom` 等）
- bit/boot.elf/Image/rootfs 等二进制工件（路径见第 6 节）
- 主板自身 PCB/原理图（S2C 未提供；由手册+管脚表覆盖）

**原始资料位置对照**：本目录 `0x-*` 各子目录 = 原仓库 `doc/`、`doc/AI相关资料/`、
`doc/V7子卡原理图和PCB/`、`code-agent/knowledge/`、`workspace/095x|096x|070x|release-*`。
