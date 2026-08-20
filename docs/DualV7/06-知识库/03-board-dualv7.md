# §03 DualV7 板卡规格

## §03.1 基本信息

- 板卡：S2C Dual Virtex-7 TAI LM
- FPGA part：`xc7v2000tflg1925-1`
- Config voltage：`1.8`，`CFGBVS`：`GND`

## §03.2 时钟

- 主时钟：`s2cclk_1_p/n`，100 MHz LVDS，引脚 `L4`/`L3`

## §03.3 复位

- SW1，引脚 `AP31`，active-low，带上拉，接入时需取反

## §03.4 PHY（以太网）

- 型号：KSZ8081MNX（32-QFN，Microchip/Micrel，多重来源交叉验证）
- 速率：10/100 Mbps Fast Ethernet
- 模式：**MII 或 RMII**（不支持 SGMII/RGMII/GMII）
- IO standard：`LVCMOS18`
- INTRP（中断）引脚**未引出到 FPGA**（S2C 板未连接，vivado-risc-v BD 中 `eth_mdio_int` 已改为常数 0）

**SGMII 不可行**（010x 已确认）：KSZ8081MNX 为纯 10/100 PHY，无 SerDes 硬件，封装无高速差分引脚；
vc707 的 SGMII 链路（gig_ethernet_pcs_pma + GTX）对 DualV7 完全不可用。
若需千兆，唯一路径是更换 PHY 芯片（硬件改造）。

### MII 引脚表

| 信号 | 引脚 |
|------|------|
| `mii_tx_en` | `AU27` |
| `mii_txd[0]` | `BA25` |
| `mii_txd[1]` | `AY25` |
| `mii_txd[2]` | `BB27` |
| `mii_txd[3]` | `BB26` |
| `phy_tx_clk` | `AR26` |
| `phy_rx_clk` | `AT23` |
| `mii_rx_dv` | `AU25` |
| `mii_rx_er` | `BC28` |
| `mii_rxd[0]` | `AT25` |
| `mii_rxd[1]` | `AR25` |
| `mii_rxd[2]` | `AY27` |
| `mii_rxd[3]` | `AY26` |
| `mii_crs` | `BA24` |
| `mii_col` | `BB25` |
| `mii_mdio` | `AP23` |
| `mii_mdc` | `AL23` |
| `phy_rst_n` | `BA18` |

## §03.5 UART

- 本地路径：**`/dev/ttyUSB2`** (CH341)，115200 baud（权限 crw-rw-rw-，无需 sudo）
- ⚠️ 032x 实测确认：`ttyUSB2` 收到 BootROM 日志，`ttyUSB1` (Digilent JTAG-SMT2) 无数据
- Symlink: `/dev/serial/by-id/usb-1a86_5523-if00-port0 → ../../ttyUSB2`

## §03.6 JTAG

- 适配器：**Digilent JTAG-SMT2**（SN: SULEE2211346A，VID:PID `0403:6010`，FT2232H）
- 同一 USB 设备提供 JTAG（Channel A）和 UART（Channel B → `/dev/ttyUSB1`）
- 调试工具：`xsdb` + `hw_server`（均在 `/tools/Xilinx/2025.1/Vivado/bin/`）
- OpenOCD：未安装（Digilent JTAG-SMT2 原生支持 Vivado hw_server，无需 OpenOCD）
- 启动 hw_server：
  ```bash
  source /tools/Xilinx/2025.1/Vivado/settings64.sh
  hw_server -d &   # 监听 TCP:localhost:3121
  ```
- 连通性验证（2026-04-26 确认）：
  - `xsdb` connect 后 `targets` 显示 `xc7v2000t`，JTAG ID `236b3093`
  - 烧录命令：`xsdb -e "connect; target 1; fpga -file <path>.bit"`

## §03.9 GPIO LED（已验证）

- LED0：引脚 `AH44`，active-high
- LED1：引脚 `AH43`，active-high
- LED2：引脚 `AL40`，active-high
- IO standard：`LVCMOS18`
- AXI GPIO 地址：`0x60040000`（020x 验证通过）
- 018x 裸 FPGA LED blink：WNS=+8.47ns，通过
- 020x Core 驱动 LED：通过，二进制计数闪烁确认
- BootROM LED 入口：`_hang` → `_led_main`，`_start` 不可靠入口
- `RocketChip/mem_ok` 接 `clock_ok` 是临时 DDR bypass

## §03.7 DDR3 / MIG

### §03.7.1 硬件规格

- 类型：DDR3 SDRAM（板上 SODIMM 插槽）
- 颗粒型号（已验证）：`MT41K256M16XX-125`（Micron 4Gb, 256Mx16, DDR3-1600 降频至 DDR3-800）
- 数据位宽：64-bit（8 个 DQ byte lane × 8 DQS 对）
- Rank：双 rank（`ddr3_cs_n[0]` + `ddr3_cs_n[1]`）
- 行地址：15 位，列地址：10 位，Bank 地址：3 位
- Bank：17（地址/控制/数据低 32bit）、19（数据高 32bit）
- I/O 电压：1.5V（`SSTL15`、`SSTL15_T_DCI`、`DIFF_SSTL15_T_DCI`）
- 参考时钟：200 MHz（由 clk_wiz_0 `clk_out2` 提供，输入时钟 `s2cclk_1` = **100 MHz** → clk_wiz 倍频到 200MHz）

### §03.7.2 MIG PRJ 配置（已验证通过）

关键参数（来自 chipyard 已实现并验证的 `dualv7mig.prj`）：

| 参数 | 值 | 说明 |
|------|----|------|
| TimePeriod | 2500 ps | 等效 400 MHz / 800 MT/s |
| PHYRatio | 4:1 | UI Clock = 100 MHz |
| InputClkFreq | 200 MHz | MIG 参考时钟 |
| MemoryDevice | `DDR3_SDRAM/Components/MT41K256M16XX-125` | Component 类型（非 SODIMM）|
| DataWidth | 64 | |
| RowAddress | 15 | |
| ColAddress | 10 | |
| BankAddress | 3 | |
| InternalVref | 1 | 内部生成参考电压 |
| ReferenceClock | No Buffer | |
| XADC_En | Enabled | 温度监控 |
| CAS Latency | 6 | |
| CAS write latency | 5 | |
| tRFC | 260 | |
| tFAW | 40 | |
| AXI Data Width | 64 | 直连 Rocket Chip |
| AXI Addr Width | 32 | |
| AXI ID Width | 4 | |

### §03.7.3 TargetFPGA 格式（关键坑）

MIG v4.2 使用 ISE 时代的 part 格式解析 `<TargetFPGA>`：
- **正确**：`xc7v2000t-flg1925/-1`（ISE 格式，用 `-` 分隔 device-package-speed）
- **错误**：`xc7v2000tflg1925-1`（Vivado 格式，device=`xc7v2000tflg1925` ≠ `xc7v2000t`）
- vivado-risc-v 当前 TCL 中的 `string map` 将 part name 从 `xc7vx485t-ffg1761/-2` 改为 `xc7v2000t-flg1925/-1`，格式碰巧正确

### §03.7.4 Rank-1 引脚约束

**009x 实测结论**：MIG 7-series 在顶层**不暴露独立的 rank-1 信号端口名**（如 `ddr3_addr[15]`、`ddr3_cke[1]` 等），rank-1 引脚由 MIG IP 内部的 XDC 处理，无法通过 `ddr3.xdc` 的 `get_ports` 匹配。

`ddr3.xdc` 中**不应**包含 rank-1 的 `PACKAGE_PIN`/`IOSTANDARD` 约束，否则 Vivado 报 `NSTD-1`/`UCIO-1` 错误。正确做法：仅保留 `CLOCK_DEDICATED_ROUTE` 约束（见 §03.7.5）。

引脚物理位置供参考（来自硬件原理图，R26/E27/C27/C28/T28/P28），但约束由 MIG 管理。

### §03.7.5 CLOCK_DEDICATED_ROUTE（跨 CMT 列布局）

外部 MMCM（`clk_wiz_0`）→ MIG 内部 PLL（`PLLE2_ADV_X0Y7`）跨 CMT 列布线。必须在 `opt_design` 后设置：

```tcl
# 在 post_opt.tcl 中：
foreach clknet [get_nets -quiet {chiptop_ddr3_sys_clk_i chiptop_ddr3_sys_clk_i_BUFG}] {
    set_property CLOCK_DEDICATED_ROUTE FALSE $clknet
}
```

opt_design 会插入 BUFG，将 net 名从 `chiptop_ddr3_sys_clk_i` 变为 `chiptop_ddr3_sys_clk_i_BUFG`，所以需匹配两条 net。

### §03.7.6 MIG PRJ 文件位置

- chipyard 验证通过的 PRJ：`/home/data/vivado-risc-v/.research/006x/dualv7-mig.prj`
### §03.7.7 已知构建问题与修复

**XADC 冲突**：chipyard 的 `mig.prj` 默认 `XADC_En>Enabled`，与 IO 层级 XADC wizard 冲突。xc7v2000t 仅 1 个 XADC site，MIG PRJ 中需改为 `<XADC_En>Disabled</XADC_En>`。

**MIG clk_ref_i**：PRJ 使用 `ReferenceClock>No Buffer`，需在 TCL 中显式连接：`[get_bd_pins mig_7series_0/clk_ref_i]` 到 `clock_200MHz` 网表。

**rank-1 端口约束**：MIG 不在顶层暴露独立 rank-1 引脚名，`ddr3.xdc` 中不应包含 rank-1 的 `PACKAGE_PIN`/`IOSTANDARD` 约束（它们由 MIG 内部处理）。

**CLOCK_DEDICATED_ROUTE**：`*ddr3_sys_clk*` net 在 XDC 加载时不存在（opt_design 后才生成），约束会报 CRITICAL WARNING 但 opt 后仍生效。

**未引出 BD 端口**：`sdio_*`、`rs232_uart_ctsn/rtsn`、`fan_en` 在 BD 中存在但无板级引脚，需在 XDC 中降级 `NSTD-1`/`UCIO-1` DRC severity。

**构建结果（已验证）**：
- bitstream 成功生成：~54MB，WNS=+8.234ns，WHS=+0.081ns，0 失败端点
- MIG 合成正常通过（~52min），无 hang

**上板测试结果**：
- FPGA 配置成功（`fpga -file` 100%），JTAG 可识别 `xc7v2000t`
- **DTM 始终处于复位状态**（`Debug Transport Module is held in reset`）
- CPU 未走出 Boot ROM `head.S`：`_start` 中 `jr s0` 跳转到 `_ram = 0x80000000`（DDR），DDR 未就绪时总线挂死，`main()` 中的 UART 打印永不执行
- **Boot ROM 不能独立于 DDR 运行**：`_start_bootrom` 第一行 `sw s2, 0(s0)` 写 DDR，`sp = 0x80002000` 也在 DDR，`head.S` 阶段就依赖 DDR
- 根因：`init_calib_complete` 未拉高 → 要么 CPU 在复位中，要么 CPU 已出复位但在 `jr s0` 后总线挂死
- 需进一步排查 MIG PHY calibration 失败原因（可能需 ILA 抓取 `mmcm_locked` / `init_calib_complete`）

### §03.7.7 eth_mdio_int 处理（PHY 中断引脚未引出）

KSZ8081MNX 的 INTRP（中断）引脚**未连接到 FPGA**（chipyard `constraints.xdc` 无此信号）。
vivado-risc-v TCL 从 vc707 继承了 `eth_mdio_int` 顶层 BD port，实现阶段会因无 pin 约束报错。

**修复**（009x 已实施）：在 `create_hier_cell_IO` proc 中：
1. 删除 `create_bd_pin -dir I eth_mdio_int`
2. 新增 `xlconstant_eth_int`（1-bit，值=0）驱动 `Ethernet/mdio_int`
3. 删除顶层 `create_bd_port -dir I eth_mdio_int` 及对应 `connect_bd_net`

## §03.8 启动链（Boot Chain）

### §03.8.1 整体流程

```
CPU Reset (0x10000)
  └→ Boot ROM BRAM (head.S → bootrom.c)
       └→ SD卡 FAT32 加载 BOOT.ELF
            └→ OpenSBI (M-mode firmware, 0x80000000)
                 └→ U-Boot (S-mode, 0x80200000)
                      └→ Linux Kernel (0x81000000)
```

### §03.8.2 Boot ROM（第一段代码）

- **地址**：`0x10000`，大小 64KB 地址空间，**实际物理 BRAM 占用 16KB**（14.5KB 代码+DTB 补齐到 2 的幂）
- **源码**：`bootrom/` 目录，所有板子共享
- **功能**：
  1. `head.S`：hart-0 跳转到 `main()`，其他 hart 在 `_hang` 等待 IPI
  2. `bootrom.c::main()`：挂载 SD 卡 FAT → 打开 `BOOT.ELF` → 解析 ELF 段 → 写入 DDR → 跳转入口
- **DTB 传递**：`a1 = 0x10080`（DTB 嵌入 BRAM 偏移 `0x80`）
- **依赖**：DDR 必须先于 Boot ROM 工作（`mem_reset_control` 等待 `init_calib_complete`）
- **板子差异化**：通过 `board/<board>/bootrom.dts` 配置外设树（UART/SD/ETH PHY mode + MAC）
- **默认 MAC**（Xilinx OUI `00:0a:35`）：
  - vc707 / dualv7：`00:0a:35:00:00:00`
  - genesys2：`00:0a:35:00:00:02`
  - 可通过 `ETHER_MAC` 环境变量在 `make` 时覆盖

### §03.8.3 BOOT.ELF（OpenSBI + U-Boot）

- 构建命令：`make bootloader`
- 产物：`workspace/boot.elf`（= `opensbi/build/platform/vivado-risc-v/firmware/fw_payload.elf`）
- OpenSBI 链接地址：`FW_TEXT_START = 0x80000000`
- U-Boot payload 偏移：`FW_PAYLOAD_OFFSET = 0x200000`
- OpenSBI 通过 `a1` 寄存器接收 DTB 地址，解析外设信息

### §03.8.4 启动方式对比

| 方式 | 媒介 | 使用命令 | 说明 |
|------|------|----------|------|
| SD 卡启动 | SD 卡（FAT32） | FPGA 上电自动 | Boot ROM 读 `BOOT.ELF`；DualV7 J8 子卡提供 TF/SD 槽（032x 验证中，SD init 尚未通过） |
| JTAG 启动 | JTAG 调试器 | `make jtag-boot` | XSDB 下载 kernel/ramdisk/boot.elf |
| bare-metal | JTAG | XSDB `dow -clear` | 纯 Machine mode，无 OpenSBI |
| Flash 烧录 | SPI Flash | `make flash` | 仅存 bitstream，上电自动配置 FPGA；不含软件引导 |

### §03.8.5 DualV7 启动策略（012x/013x 确认）

**DualV7 通过 J8 子卡提供 TF/SD 卡槽**（MMC1 接口，4-bit，LVCMOS18）。
早期 `sdc.xdc` 仅有注释"No SD card"是历史遗留，013x 已写入正确引脚约束。

**SD 卡引脚（J8 子卡 MMC1，013x 已写入 `board/dualv7/sdc.xdc`）**：

| 信号 | FPGA 引脚 | IO Bank | vivado-risc-v 端口 |
|------|-----------|---------|-------------------|
| MMC1CLK | AT37 | 12 | `sdio_clk` |
| MMC1CMD | AT38 | 12 | `sdio_cmd` |
| MMC1D0  | BA43 | 11 | `sdio_dat[0]` |
| MMC1D1  | AY43 | 11 | `sdio_dat[1]` |
| MMC1D2  | AW44 | 11 | `sdio_dat[2]` |
| MMC1D3  | AW43 | 11 | `sdio_dat[3]` |
| TFCD    | BA39 | 11 | `sdio_cd` |

全部 LVCMOS18，CLK/CMD/DAT 加 `IOB TRUE`。无 `sdio_reset`（BD 无此端口，bootrom.c 自动跳过）。
因此 DualV7 **并不缺 SD card-detect 这根线**；`TFCD -> sdio_cd`
已经接到 FPGA。后续 Linux 卡检测问题应优先从
`card_detect` 寄存器语义 / `sdc_get_cd()` 路径排查，而不是先假设
“缺 GPIO”。

**推荐方案：SD 卡启动**（上电自动）或 **JTAG Boot**（`make jtag-boot`，调试阶段）
- XSDB `dow boot.elf` 将 PC 设到 ELF 入口（0x80000000 = OpenSBI），**完全绕过 bootrom 的 SD 依赖**
- 不需要任何代码修改，直接验证 DDR + CPU + 外设
- 前置产物：`workspace/boot.elf`、`linux-stable/.../Image`、`debian-riscv64/ramdisk`、bitstream

**JTAG Boot 下载顺序**（`board/jtag-boot.tcl`）：

| 步骤 | 内容 | 地址 |
|------|------|------|
| 1 | fpga 下载 bitstream | FPGA |
| 2 | stop Hart#0 | — |
| 3 | dow kernel Image | 0x81000000 |
| 4 | dow ramdisk | 0x85000000 |
| 5 | dow -clear boot.elf | ELF 入口（设 PC=0x80000000） |
| 6 | 设 a0=0, a1=0x10080（DTB） | — |
| 7 | con | — |

**当前网络验证基线（2026-05-16，050x 确认）**：

网络验证必须同时固定 `bit + boot.elf` 版本，二者任一变化会导致网络现象不同。

固定产物组合：

| 产物 | 路径 | sha256 | 说明 |
|------|------|--------|------|
| bit | `workspace/dualv7-test/044x/rocket64b2-mii-fifo-v2.bit` | `4f0c36ca...` | `eth_mac_mii_fifo` + `CLOCK_INPUT_STYLE=BUFG` |
| boot.elf | `workspace/dualv7-test/044x/boot-uboot-v11.elf` | `101008cd...` | 含 `vivado_mii` 自定义驱动 (UCLASS_ETH) |
| Image | `linux-stable/arch/riscv/boot/Image` | `e228bb35...` | Linux 5.15.4 |
| ramdisk | `workspace/dualv7-test/044x/ramdisk` | `b740ac6a...` | 最小 initramfs |

**用 `boot-uboot-mii.elf` 会落到 `Net: No ethernet found.`**。
用 `boot-uboot-v11.elf`（含 `vivado_mii` 驱动）会枚举 `eth0: eth0@60020000`。

推荐入口：**JTAG Boot**（不需要 BootROM 参与）。

**推荐本地流程**：

```tcl
connect
targets 1
fpga -file <bit>
targets -set -filter {name =~ "Hart #0*"}
stop
targets -set -filter {name =~ "RISC-V*"}
dow -data <Image> 0x81000000
dow -data <ramdisk> 0x85000000
targets -set -filter {name =~ "Hart #0*"}
dow -clear <boot-uboot-v11.elf>
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000
con
```

UART 打断 autoboot 后执行：

```text
booti 0x81000000 0x85000000 0x10080
```

**关键结论**：

- 这条路径**不需要重编 bootrom**，也不需要 SD 卡。
- 当前网络现象的主要变量是 `boot.elf` 版本（U-Boot payload 是否有 `vivado_mii` 驱动），
  不是 BootROM。
- 2026-05-16 本地进一步实测确认：在该 JTAG Boot 基线上，
  Linux 侧 `eth0` 的 IPv4 数据面已经打通，可从主机 `192.168.200.201`
  成功 ping 通 FPGA `192.168.200.250`。
- `bootrom` 不应再作为当前网络现象的主嫌疑。
- UART 交互需在 autoboot 倒计时内发送新行打断，否则进入 BOOTP broadcast 循环。

**推荐 JTAG Boot TCL**（050x 已验证）：

`workspace/dualv7-test/050x/jtag-boot-v11.tcl`

**050x 实测日志**：

- U-Boot 网络基线：`workspace/dualv7-test/050x/uboot-v11.log`
- MII 命令输出：`workspace/dualv7-test/050x/uboot-mii.log`
- Linux 启动日志：`workspace/dualv7-test/050x/linux.log`
- 产物哈希记录：`workspace/dualv7-test/050x/artifacts.txt`
- 本地 ping 复测：
  `workspace/dualv7-test/20260516-ping-check/uboot-ping.log`
  与 `workspace/dualv7-test/20260516-ping-check/tcpdump.log`

**2026-05-16 本地 ping 结论**：

- 当前固定基线
  `rocket64b2-mii-fifo-v2.bit + boot-uboot-v11.elf`
  下，U-Boot 可稳定枚举 `eth0: eth0@60020000`，但
  `ping 192.168.200.201` 会停在
  `Using eth0@60020000 device`。
- 同时在本机 `enp1s0` 抓包，**没有看到任何**
  `192.168.200.250` 发出的 ARP 或 ICMP。
- 因此当前只能确认：
  **PHY/MDIO/link-up 路径成立**；
  **U-Boot IP 数据面仍未打通**。
- 现阶段**还不能进入 NFS 启动验证**。

**未来选项**：`make flash` 烧 bitstream 到 SPI Flash → 上电自动加载 FPGA → 再 JTAG 下载软件（省去每次 bitstream 下载）。

**当前执行口径（2026-05-17）**：

- 本地 bring-up 与网络验证统一按
  `doc/DualV7-FPGA本地操作流程.md`
  执行
- 当前锁定的 release 为
  `dualv7-r1-jtagboot-net`
- release 的代码位置、commit、产物哈希、构建命令统一记录在
  `doc/DualV7-Release清单.md`

**BD 中存在但无物理引脚的信号**（悬空，不报错）：
- `fan_en`（XADC 温度告警输出，无约束）
- `rs232_uart_ctsn/rtsn`（UART 流控，无约束）
- `sdio_*` 已由 013x 补充 XDC 约束，不再悬空

### §03.8.6 三板总线架构差异

虽然三块板子在软件启动链层面一致，但硬件互连层有本质差异：

| 维度 | vc707 | genesys2 | dualv7 |
|------|-------|----------|--------|
| **Ethernet PHY** | SGMII（串行 GbE，Xilinx PCS/PMA IP） | RGMII（并行 GbE） | MII（10/100M） |
| **ETH 参考时钟** | `sgmii_mgt_clk` 125MHz（MGT ref） | `clk_wiz` clk_out4 = 125MHz | `phy_tx_clk`/`phy_rx_clk` 25MHz |
| **RocketChip MEM_AXI4** | 64-bit | 64-bit | 64-bit |
| **MIG AXI Data Width** | 512-bit | 256-bit | 64-bit（目标） |
| **MIG DDR 位宽** | 64-bit SODIMM | 32-bit Component | 64-bit Component |
| **MIG TimePeriod** | 1250 ps (800MHz) | 1250 ps (800MHz) | 2500 ps (400MHz) |
| **系统时钟源** | 200MHz diff | 200MHz diff | 100MHz diff（`s2cclk_1`） |
| **clk_wiz 输出数** | 3 (100/200/100) | 4 (100/200/100/125) | 3 (100/200/100) |
| **配置 Flash** | BPIx16 | SPIx4 | 待确认 |
| **MIG PRJ 来源** | 预生成 `.prj` 文件 | TCL 内联生成 | 当前复制 vc707（错误） |

DualV7 在 MIG 层面最简洁（64→64 直通，无跨宽桥），Ethernet 层面也最简（MII 非 SGMII/RGMII）。

- `board/dualv7/bootrom.dts` 已存在并配置为 MII 模式以太网
- Boot ROM 代码不需要修改（所有板子共享 `bootrom/` 源码）
- **阻塞点**：MIG DDR3 未正确配置时 DDR 不可用，Boot ROM 无法运行 `main()`（stack 在 `0x80002000`）
- SD 控制器地址 `0x60000000` 和 UART 地址 `0x60010000` 为硬编码，需确认 TCL 中映射一致

## §03.10 本地 FPGA 操作流程入口（055x，2026-05-16）

**推荐后续所有本地 FPGA bring-up 操作优先参考此文档**：
`doc/DualV7-FPGA本地操作流程.md`

该文档包含：
- 固定设备路径（UART、JTAG、网卡）
- 固定产物组合（bit + boot.elf + Image + ramdisk）及 sha256
- 最小 JTAG Boot 流程（可直接复制的 xsdb TCL）
- UART 操作规则（含 autoboot 打断方式及常见坑）
- Linux 启动验证标准
- 网络验证入口
- 常见误区
- 日志落盘路径规范

### 关键约束

1. **产物固定**：bit / boot.elf / Image / ramdisk 四个文件不可随意替换，
   所有网络验证必须同时记录四个文件的 sha256
2. **不要混用** `boot-uboot-mii.elf`（会导致 `Net: No ethernet found.`）
3. **JTAG Boot 顺序固定**：bit → stop → dow Image → dow ramdisk → dow boot.elf → rwr → con
4. **UART 交互**：脚本化不可靠时，手工用 `screen` / `minicom` 操作
5. **BootROM 不作主嫌疑**（JTAG Boot 路径完全绕过）
6. **U-Boot `ping` 不开通不做 NFS**：U-Boot `vivado_mii` 驱动 TX 数据面未实现

### NFS Root 验证（058x，2026-05-17）

**已验证可工作**：基于 release-r1 固定产物，Linux 阶段 NFS root
挂载成功（`VFS: Mounted root (nfs filesystem)`），
init 从 NFS 正确执行。操作流程已写入
`doc/DualV7-FPGA本地操作流程.md` §8。

关键前提：
1. 本机安装 `nfs-kernel-server` 并 export NFS root 目录
2. UFW 防火墙放行 NFS 端口（2049 + 111 + mountd/lockd）
3. NFS root 目录需 `sbin/init` → `../init` symlink
4. 不加载 ramdisk，U-Boot `bootargs` 指定 `root=/dev/nfs`
5. JTAG Boot TCL 不含 `dow -data ramdisk`

### 网络引导验证（063x，2026-05-17）

**已验证可工作**：在同一颗 `release-r1` bit 上，JTAG 仅下载
`bit + boot.elf`，由 U-Boot 通过 `tftpboot` 获取内核，随后由 Linux
通过 NFS 挂载 rootfs。

固定入口：

1. JTAG TCL：
   `workspace/release-r1-netboot/jtag-boot-r1-netboot.tcl`
2. U-Boot 命令：
   `workspace/release-r1-netboot/uboot-tftp-nfs-commands.txt`
3. NFS/TFTP root：
   `workspace/release-r1-netboot/nfsroot`

注意：

- 当前推荐主线是 **TFTP 取内核 + Linux NFS root**
- 不建议把 U-Boot `nfs` 文件抓取当作默认入口
- 当前 `nfsroot/init` 仍是单次 REALCHECK 程序，退出后会 panic；
  这不影响网络引导链本身已经打通
