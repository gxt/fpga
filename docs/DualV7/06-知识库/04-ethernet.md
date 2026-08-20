# §04 以太网

## §04.1 PHY 硬件

- 型号：**KSZ8081MNX**（Microchip）
- 接口：**MII**（Media Independent Interface），10/100 Mbps
- 不支持 SGMII / RGMII / GMII
- IO standard：`LVCMOS18`（1.8V bank）
- 参考时钟：`phy_tx_clk` / `phy_rx_clk` 各 25 MHz（PHY 输出）
- MDIO 时钟：~2.5 MHz（内部生成）
- 引脚表：见 `§03.4`

## §04.2 Vivado 模块

- 当前方案：`ethernet-dualv7.v` + `ethernet.v`（wrapper）
- MAC 核：`eth_mac_1g_fifo`（非 Chipyard EthernetLite）
- 接口：
  - MII 物理侧：`mii_txd[3:0]`, `mii_tx_en`, `mii_rxd[3:0]`,
    `mii_rx_dv`, `mii_rx_er`
  - CPU 侧：AXI-Stream（TX_AXIS / RX_AXIS）+ AXI-Lite
- BM DNS：`IO→Ethernet→EthernetDualV7→ethernet_stream_0`

## §04.3 中断与 MDIO

- `eth_mdio_int`：KSZ8081 INTRP 引脚，S2C DualV7 **未引出到 FPGA**
  - 009x 已用 `xlconstant` 常量 0 替代，BD 中不复存在
- MDIO (mdc/mdio)：Clock 与 Data 信号已正常约束在 `ethernet.xdc`
- MDIO Reset 通过 `eth_mdio_reset` 输出控制

## §04.4 备用方案

- `alt_eth`：仅作为备用参考，缺少 MDIO master，**不作为当前主线**
- **推荐方案 A**：`eth_mac_mii_fifo`（原生 MII MAC，与当前 `eth_mac_1g_fifo` 同属 verilog-ethernet 库）
  - 替换当前 GMII→MII 适配方案（`eth_mac_1g_fifo` + `mii_select=1`）
  - AXI-Stream 接口完全兼容，MDIO 复用 `ethernet.v`
  - 移植量小：仅改 `ethernet-dualv7.v`，TCL/BD/XDC/DTS 不变
  - 详见 §04.6

## §04.5 约束文件

- `ethernet.xdc`：MII 引脚 PACKAGE_PIN + IOSTANDARD
- 加载链：`vivado.tcl` → `source ethernet-dualv7.tcl` → `add_files ethernet.xdc`

## §04.6 MII MAC IP 方案综合对比（043x 详细调研，2026-05-13）

### 候选方案矩阵

| # | 方案 | 来源 | 原生MII | AXI接口 | MDIO | 移植量 | 当前推荐 |
|---|------|------|---------|---------|------|--------|----------|
| 1 | **eth_mac_mii_fifo** | [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) `lib/verilog-ethernet/rtl/` | ✅ 原生4-bit | AXI-Stream | 复用ethernet.v | **小** (~30行) | **短期首选** |
| 2 | eth_mac_1g_fifo (当前) | [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) 同库 | ⚠️ GMII适配 | AXI-Stream | ethernet.v | 0 | 不推荐继续 |
| 3 | Xilinx AXI Eth Subsystem | Vivado IP Catalog PG138 | ✅ 原生MII | AXI4 | ✅ 内置 | 中 | 中期备选 |
| 4 | Xilinx AXI EthernetLite | Vivado IP Catalog PG135 | ❌ MII RX bug | AXI4 | 内置 | 中 | **不推荐** |
| 5 | LiteEth | [LiteX liteeth](https://github.com/enjoy-digital/liteeth) Migen构建 | ✅ 原生MII | ❌ Wishbone | ✅ 内置 | 大 | 不推荐 |
| 6 | ETHOC (OpenMAC) | [OpenCores ethmac](https://opencores.org/projects/ethmac) | ✅ 原生MII | ❌ Wishbone | ❌ 无 | 大 | 不推荐 |

### 方案 1：eth_mac_mii_fifo（短期推荐，移植量最小）

**来源**：verilog-ethernet 库（与当前 `eth_mac_1g_fifo` 同源）

- `mii_phy_if.v` 使用 **IDDR 原语**采样 RX 信号（非 SDR），7-series 需指定
  `CLOCK_INPUT_STYLE = "BUFR"`（通过 module parameter 或 Verilog `defparam`）
- AXI-Stream 接口与当前 `eth_mac_1g_fifo` 完全兼容（8-bit tdata/tkeep/tvalid/tready/tlast/tuser）
- MDIO master 独立于 MAC core，`ethernet.v` 中的 MDIO 实现可**完整保留**，无需改动
- **唯一改动文件**：`ethernet-dualv7.v`（~30 行端口映射替换）
- TCL/BD/XDC/DTS/BootROM/Linux/U-Boot **全部不变**
- 去除 GMII→MII nibble 适配层，逻辑更简洁，降低 bug 风险

### 方案 2：当前 eth_mac_1g_fifo + mii_select=1（已证不可用）

- GMII MAC 通过 `mii_select=1` 将 8-bit GMII 降为 4-bit MII nibble
- 037x/038x 运行时验证结论（§04.7）：**U-Boot "No ethernet found"，Linux 0 RX/TX**
- 继续调试 ROI 低，推荐切换方案 1

### 方案 3：Xilinx AXI Ethernet Subsystem（中期备选）

- 主线驱动 `xilinx_axienet`（成熟），内置 MDIO/DMA
- 需 BD/TCL/DTS 变更，移植量中等
- 早期版本（≤2019.x）有 preamble/SFD RX bug，2025.1 中待确认
- 适用：方案 1 长期不稳定，或需 DMA/checksum offload 等高级特性

### 方案 4/5/6：不推荐路线

- **AXI EthernetLite**：已知 MII RX bug（SFD 状态机缺陷），Vivado 2025.1 是否修复不明确
- **LiteEth**：Python/Migen 构建链与 Vivado BD 不兼容，Wishbone 接口需桥接
- **ETHOC**：无 MDIO master，RISC-V 验证极少，移植代价高

## §04.7 038x Mega 以太网运行时验证（2026-05）

| 层级 | 结果 |
|------|------|
| FPGA CONFIG | `rocket64z2m` (2×MegaBoom Z1), WNS=-0.755ns |
| U-Boot 层 | `Net: No ethernet found.` — MAC 枚举失败 |
| Linux MDIO | ✅ PHY 0x00221560 (KSZ8081MNX) 探测成功 |
| Linux netdev | eth0 存在，驱动 `riscv-axi-eth` |
| Linux link | operstate=down，carrier 读取异常 (`invalid length`) |
| Linux 流量 | 0 RX / 0 TX |
| 203 对端 | USB 网卡锁死在 100M/Half/autoneg off，不支持 ethtool 修改 |

**结论**：
- `eth_mac_1g_fifo + mii_select=1` 在 DualV7 上的运行时验证未通过
- U-Boot 和 Linux 均无法建立以太网链路
- 203 对端无法调整模式，排除了对端模式 sweep 的可能
- 切换到 `eth_mac_mii_fifo`（原生 MII MAC）的优先级提升

## §04.8 043x 分阶段推荐总结（2026-05-13）

### 短期推荐：eth_mac_mii_fifo（方案 1）

- **唯一改动文件**：`ethernet-dualv7.v`（~30 行）
- TCL / BD / XDC / DTS / BootROM / Linux / U-Boot **全部不变**
- 去除 GMII→MII 适配层，逻辑更简洁
- `CLOCK_INPUT_STYLE = "BUFR"` 适配 7-series IDDR

### 中期备选：Xilinx AXI Ethernet Subsystem（方案 3）

- 主线驱动 `xilinx_axienet`，内置 DMA/MDIO
- 需 BD / TCL / DTS 变更
- 适用场景：方案 1 长期不稳定，或需高级特性（DMA/offload）

### 不推荐：方案 2（当前）、方案 4（ETHLite bug）、方案 5（Migen 不兼容）、方案 6（无 MDIO）

### 详细报告

完整分析见 `doc/DualV7-子卡网络IP方案报告.md`

## §04.9 044x eth_mac_mii_fifo rocket64b2 验证（2026-05-13）

### 构建

- 配置：`BOARD=dualv7 CONFIG=rocket64b2`
- 仅修改文件：`board/dualv7/ethernet-dualv7.v`
- 修改内容：`eth_mac_1g_fifo` → `eth_mac_mii_fifo`，`TARGET="XILINX"`, `CLOCK_INPUT_STYLE="BUFR"`
- bit：54MB，sha256 `5060084d10a71b2f71b7374de4cadeb1a92c68d46ce700fa8d06331a700ced5d`
- Timing：**WNS=+0.750ns, WHS=+0.033ns, DRC 0 Error**

### 运行时结果

| 层级 | 结果 | 详情 |
|------|------|------|
| FPGA 配置 | ✅ 通过 | `rocket64b2`，JTAG 下载成功 |
| BootROM MDIO | ✅ **通过** | PHY 扫描正常，可读取 BMCR/BMSR/ANAR/ANLPAR |
| BootROM PHY | ✅ 检测到 | 找到 KSZ8081MNX（`TARGET phy=2u`） |
| BootROM link | ⚠️ 阻塞 | 持续轮询（20+ POLL）未建立 link |
| JTAG Boot | ✅ 绕过 | `dow -clear boot.elf` 直达 OpenSBI→U-Boot |
| U-Boot ethernet | ❌ **失败** | `Net: No ethernet found.`（与旧 MAC 相同） |
| U-Boot `mii device` | ❌ 空列表 | 无 MII 设备枚举 |
| U-Boot `mii info` | ❌ | `No such device: <NULL>` ×32 |
| U-Boot `ping` | ❌ | `ping failed; host 192.168.200.203 is not alive` |
| 后续阶段 | ❌ 未达 | 未进入 Linux |

### 阻塞原因分析

1. **BootROM link 阻塞**：203 对端 USB 网卡 `enp0s20u1c2` 锁死在
   100M/Half/autoneg off，KSZ8081MNX 自动协商无法完成。
   可通过 JTAG Boot 绕过。

2. **U-Boot `No ethernet found.`**：与 `eth_mac_1g_fifo`（旧 MAC）
   表现完全一致。说明这是 **U-Boot 驱动层问题**，非 MAC RTL 问题。
   驱动 `riscv,axi-ethernet-1.0` 在 U-Boot 2022.01 中无法枚举设备，
   可能原因：DTS 节点配置不匹配、驱动 probe 函数依赖某寄存器或
   compatible string 未注册。

3. **BootROM MDIO 工作但 U-Boot 驱动不工作**：BootROM 直接通过
   memory-mapped 寄存器访问 MDIO/PHY，不依赖 U-Boot 驱动层。
   新 MAC 的硬件通路（寄存器映射、AXI 接口）是正确的。

### 结论

**partial**——`eth_mac_mii_fifo` MAC RTL 本身有效（BootROM MDIO proof），
U-Boot 驱动层阻塞与 MAC 核切换无关，是独立问题需定位。

### 第二轮验证（v2 bit，完整 TCL + U-Boot 驱动，2026-05-14）

**构建修正**：
- `ethernet-dualv7.tcl` 完整 12 源文件列表：
  `eth_mac_mii_fifo.v`, `eth_mac_mii.v`, `eth_mac_1g.v`,
  `axis_gmii_rx.v`, `axis_gmii_tx.v`, `mii_phy_if.v`, `ssio_sdr_in.v`,
  `axis_adapter.v`, `axis_async_fifo.v`, `axis_async_fifo_adapter.v`,
  `lfsr.v`, `ethernet.v`
- `CLOCK_INPUT_STYLE = "BUFG"`（BUFR/BUFIO 有 IO bank 布局冲突）
- WNS=+0.935ns, WHS=-7.690ns
- bit sha256: `4f0c36ca...`

**U-Boot 驱动**：
- 写 `vivado_mii` 驱动（`drivers/net/vivado_mii.c`, UCLASS_ETH）
- eth0 成功枚举 ✅ `Net: eth0: eth0@60020000`
- mii device/mii info/mii dump 全部可用

**PHY 验证**：
- PHY ID `0022_1560` = KSZ8081MNX ✅，地址=1
- Auto-negotiation 使能 + 完成，Link partner 检测到
- Link status = 0（待确认网线/交换机连接）

**重大发现**：
1. **MDIO 帧格式 Bug**：BootROM 用 `(1<<30)|(phy<<25)|(reg<<21)` 格式，
   地址 0-15 全发 OP=00（无效命令），FPGA 不三态总线，读回 TX 值。
   正确格式为标准 IEEE Clause 22：
   `tx = (1<<30) | (2<<28) | (phy<<23) | (reg<<18)`
2. **PHY 复位**：BootROM 残留 `mdio_reset_reg=1`（nic_ctrl=0x04），
   需写入 0 释放。板级 PHY reset 悬空（内部上拉高电平）。
3. **子卡原理图**：MDIO 有 4.7K 上拉（R398/R469），PHYAD=001，
   ERST_N→R432(0Ω)→ASYSRSTN

### 本地 JTAG Boot 复测（2026-05-16）

- 本地验证了：
  `bit + Image + ramdisk + boot.elf` 的完整 JTAG Boot 路径。
- 使用产物：
  - bit：
    `workspace/dualv7-test/044x/rocket64b2-mii-fifo-v2.bit`
  - boot ELF：
    `workspace/dualv7-test/044x/boot-uboot-mii.elf`
  - kernel：
    `linux-stable/arch/riscv/boot/Image`
  - ramdisk：
    `workspace/dualv7-test/044x/ramdisk`
- `xsdb` 下载完成后，U-Boot 会落到提示符；要继续进 Linux，
  必须手工或脚本发送：
  `booti 0x81000000 0x85000000 0x10080`
- 实测日志：
  `workspace/dualv7-test/20260516-jtag-boot-check/uart-auto-linux.log`

**本轮实测结果**：

- `OpenSBI`、`U-Boot`、`Starting kernel ...`、`Linux version`
  和 `Run /init as init process` 全部出现。
- U-Boot 这一轮仍打印：
  `Net:   No ethernet found.`
- Linux 进入 initramfs 后，驱动侧能看到：
  `riscv-axi-eth 60020000.eth0: 044x: probed as eth0, irq=4`

**对后续调试的影响**：

- 现在已经有一条**不依赖重编 BootROM** 的本地 bring-up 基线。
- 后续只要 bit 不变，软件层验证优先走
  `JTAG Boot + booti 0x81000000 0x85000000 0x10080`。
- 不要再把“为了验证 kernel/ramdisk 必须改 bootrom”当作前提。

### `boot.elf` 版本对网络现象的影响（2026-05-16）

在**同一颗 bit**
`workspace/dualv7-test/044x/rocket64b2-mii-fifo-v2.bit`
下，本地 JTAG Boot 复测得到：

- 旧 `boot.elf`
  `workspace/dualv7-test/044x/boot-uboot-mii.elf`
  - U-Boot 版本：
    `May 13 2026 - 18:43:43 +0800`
  - 现象：
    `Net:   No ethernet found.`
  - 日志：
    `workspace/dualv7-test/20260516-jtag-boot-check/uart-auto-linux.log`

- 新 `boot.elf`
  `workspace/dualv7-test/044x/boot-uboot-v11.elf`
  - U-Boot 版本：
    `May 14 2026 - 14:42:21 +0800`
  - 现象：
    `vivado_mii ...`、`eth0: eth0@60020000`
  - 日志：
    `workspace/dualv7-test/20260516-jtag-boot-check/uboot-v11-jtag.log`

**结论**：

- 之前网络调试里，**不应再把主要嫌疑放在 BootROM 本身**。
- 对当前 JTAG Boot 路径，决定 U-Boot 网络枚举结果的关键变量是
  **加载了哪一份 `boot.elf` / U-Boot payload**。
- BootROM 在这条路径里的主要影响只剩：
  - 早期串口打印（例如 `PHYPROBE 041x`）
  - 某些板级初始寄存器状态
- 但 `Net: No ethernet found.` 和
  `eth0: eth0@60020000` 这类现象，已经被证明可以在**同一颗 bit**
  下仅通过更换 `boot.elf` 改变。

**后续规则**：

- 做网络复测时，必须同时固定并记录：
  - `bit` 路径和 sha256
  - `boot.elf` 路径和 sha256
- 不要只写“用了当前 bit”，不写 `boot.elf` 版本。

## §04.10 050x 网络验证基线确认（2026-05-16）

### 基线产物

050x 正式锁定当前网络验证基线：

- bit：`workspace/dualv7-test/044x/rocket64b2-mii-fifo-v2.bit`
  sha256 `4f0c36caa5efe25061c925b31de6b0e9dee4373694c0787526cc9fa191a460b7`
- boot.elf：`workspace/dualv7-test/044x/boot-uboot-v11.elf`
  sha256 `101008cde2a8291ebb5a136a196c44ffef959b77c1fdb3f383e7f4919c2c2af3`
  U-Boot 2022.01-dirty (May 14 2026 - 14:42:21 +0800)
- Image：`linux-stable/arch/riscv/boot/Image`
- ramdisk：`workspace/dualv7-test/044x/ramdisk`

### 复测结果

| 层级 | 现象 | 状态 |
|------|------|------|
| OpenSBI | v1.7，2 HART，SBI v3.0 | ✅ |
| U-Boot | 2022.01-dirty，DRAM 1 GiB | ✅ |
| U-Boot Net | `vivado_mii: base=...` + `eth0: eth0@60020000` | ✅ |
| U-Boot MII | `mii device` → `eth0@60020000`，`mii info` → PHY 0x00 & 0x01 | ✅ |
| PHY ID | reg2=0x0022, reg3=0x1560 = KSZ8081MNX, addr=1 | ✅ |
| PHY BMCR | 0x1100: A/N enable, full duplex, 10Mbps | ✅ |
| PHY BMSR | 0x786d: link up, A/N complete, 100BaseX FDX/HDX able | ✅ |
| PHY ANLPAR | 0x4de1: partner acknowledged, 100BaseTX FDX/HDX able | ✅ |
| Linux boot | `Starting kernel ...` → `Run /init as init process` | ✅ |
| Linux eth0 | `riscv-axi-eth 60020000.eth0: 044x: probed as eth0, irq=4` | ✅ |

### 结论：`validated`

JTAG Boot 稳定复现 U-Boot 网络枚举和 Linux eth0 probe。
后续网络调试可直接复用这条基线，不需要再归咎于 BootROM。

### 关键经验

1. UART 交互必须监视 `autoboot` 输出后及时打断，否则 U-Boot 进入 BOOTP broadcast 死循环
2. `printf` / `echo` 直接写 `/dev/ttyUSB2` 在并行 cat 进程中可正常工作
3. 本地推荐使用 monitoring shell 脚本协调 JTAG boot 和 UART 交互

## §04.11 本地 U-Boot ping 复测（2026-05-16）

在与 `201/202/203` 共用同一交换机的本地环境下，按固定基线复测：

- bit：
  `workspace/dualv7-test/044x/rocket64b2-mii-fifo-v2.bit`
- boot.elf：
  `workspace/dualv7-test/044x/boot-uboot-v11.elf`
- 本地脚本：
  `workspace/dualv7-test/20260516-ping-check/uboot_ping_check.py`
- 串口日志：
  `workspace/dualv7-test/20260516-ping-check/uboot-ping.log`
- 本机抓包：
  `workspace/dualv7-test/20260516-ping-check/tcpdump.log`

### 现象

1. U-Boot 仍稳定枚举：
   `vivado_mii ...`、`eth0: eth0@60020000`
2. `printenv` 显示：
   - `ethaddr=00:0a:35:00:00:00`
   - `ethact/ethprime/ipaddr/netmask` 初始未定义
3. 设置：
   - `ethact=eth0@60020000`
   - `ethprime=eth0@60020000`
   - `ipaddr=192.168.200.250`
   - `netmask=255.255.255.0`
4. 执行 `ping 192.168.200.201` 后，串口停在：
   `Using eth0@60020000 device`
5. 同时在 `201` 的 `enp1s0` 上抓包，
   **未看到任何** 源自 `192.168.200.250` 的 ARP 或 ICMP。

### 结论

- 当前网络状态应收敛为：
  - `PHY/MDIO/link-up`：✅
  - `U-Boot device probe`：✅
  - `U-Boot IP data plane`：❌
- 这不是 BootROM 主因；
  也不是“网络已通、只差 NFS 参数”。
- 在继续 NFS 前，必须先解释：
  **为什么 U-Boot `ping` 已进入设备路径，但包没有出现在物理网口上。**

## §04.12 U-Boot `ping` 无线包根因分析（051x 调研，2026-05-16）

**注意**：
本节是 051x 的**中期收敛结果**。
不要单独依据本节直接下“只做 U-Boot 驱动修补”的实现任务；
应结合后续 `§04.13` 的修补实测结果一起判断。

### 结论：`vivado_mii` 驱动是 MDIO-only 桩，无包收发实现

`vivado_mii` 驱动源码位于远端 202 的
`u-boot/drivers/net/vivado_mii.c`（~170 行）。

三个关键事实：

1. **`send()` = `-ENOSYS` 空桩**（第 104 行）：`vivado_mii_send()`
   直接返回 `-ENOSYS`（功能未实现）。`recv()` 返回 `-EAGAIN`。
   `start()`/`stop()` 也是空桩。

2. **`nic_control` 未启用 EN_TX/EN_RX**（第 76-87 行）：
   `vivado_phy_init()` 仅清除 `CTRL_MDIO_RST`(bit 2)，未设置
   `EN_RX`(bit 0) 或 `EN_TX`(bit 1)。即使实现了 `send()`，
   RTL 硬件不会启动 TX DMA——
   `ethernet.v` 中 TX 启动条件要求 `tx_enable=1`。

3. **DMA ring 描述符管理完全缺失**：驱动没有
   TX/RX buffer 分配、描述符（addr/size）写入、
   指针（`tx_inp`/`tx_out`）维护的实现。
   需参照 Linux `patches/fpga-axi-eth.c` 的 `axi_eth_xmit()`
   实现。

### 寄存器映射关键点

| 偏移 | 寄存器 | 用途 |
|------|--------|------|
| 0x018 | tx_inp | **写此寄存器 kick TX DMA** |
| 0x01c | tx_out | TX 完成指针（硬件自动更新） |
| 0x020 | nic_control | bit0=EN_RX, bit1=EN_TX, bit2=MDIO_RST |
| 0xc00+n*0x10 | tx_pkt_regs[n].addr | TX 描述符地址 |
| 0xc00+n*0x10+0x4 | tx_pkt_regs[n].size | TX 描述符大小 |

### 下一步

**U-Boot 最小修补任务**（不需要 RTL 重综合）：
1. 在驱动中设置 `EN_TX`/`EN_RX`
2. 实现 `send()`: malloc buffer → 写 TX descriptor → 写 tx_inp
3. 实现 `recv()`: 轮询 rx_out → 写 rx 描述符 → 更新 rx_out

这里只能说明：
**U-Boot 驱动本身确实不完整**。
但不能仅凭 Linux `probe` 成功就排除 TX 数据面或硬件全局问题。

### 详细报告

完整分析见 `doc/DualV7-U-Boot-ping-no-wire-调研报告.md`

## §04.16 Linux IPv4 数据面实机验证（2026-05-16）

在同一颗网络验证基线 bit 上，使用 **JTAG Boot + 自定义最小 initramfs**
直接验证 Linux 侧真实数据面：

- bit:
  `workspace/dualv7-test/044x/rocket64b2-mii-fifo-v2.bit`
- boot.elf:
  `workspace/dualv7-test/044x/boot-uboot-v11.elf`
- 内核:
  `linux-stable/arch/riscv/boot/Image`
- 自定义 initramfs:
  `workspace/dualv7-test/20260516-network-real-check/ramdisk-realcheck`
- 驱动测试程序源码:
  `workspace/dualv7-test/20260516-network-real-check/init_real_check.c`
- 自动化脚本:
  `workspace/dualv7-test/20260516-network-real-check/run_real_check.py`
- 串口日志:
  `workspace/dualv7-test/20260516-network-real-check/uart-realcheck.log`
- 抓包日志:
  `workspace/dualv7-test/20260516-network-real-check/tcpdump-realcheck.log`
- 主机 ping 日志:
  `workspace/dualv7-test/20260516-network-real-check/host-ping4.log`
  `workspace/dualv7-test/20260516-network-real-check/host-ping6.log`

### 现象

1. U-Boot 仍稳定枚举：
   `vivado_mii ...`、`eth0: eth0@60020000`
2. Linux 侧：
   `riscv-axi-eth 60020000.eth0: 044x: probed as eth0, irq=4`
3. 自定义 `/init` 将 `eth0` 置 `UP`，配置：
   - IPv4: `192.168.200.250/24`
   - MAC: `00:0a:35:00:00:00`
4. 串口确认：
   `IPv6: ADDRCONF(NETDEV_CHANGE): eth0: link becomes ready`
5. FPGA 主动发出 3 个 ARP request：
   `ARP send attempt {1,2,3}: ret=60 err=OK`
6. 主机 `192.168.200.201` 对 `192.168.200.250` 的 IPv4 ping
   **3/3 成功**
7. 抓包可同时看到：
   - FPGA 发出的 ARP request / ARP reply
   - 主机发出的 ICMP echo request
   - FPGA 回的 ICMP echo reply
8. IPv6 link-local ping 这轮 **未通**，但不影响 IPv4 结论

### 结论

- **Linux IPv4 数据面已实机打通**
- 现在不能再把当前网络问题概括成“FPGA 完全不发包”

### 当前推荐基线（2026-05-17）

- 统一执行入口：`doc/DualV7-FPGA本地操作流程.md`
- 当前锁定 release：`dualv7-r1-jtagboot-net`
- 代码位置、commit、产物哈希、构建流程：
  `doc/DualV7-Release清单.md`
- 后续 DS 复现不再直接参考 051x 原始试错记录，只按 runbook 和
  release 清单执行
- 更准确的状态应分层描述为：
  - `U-Boot PHY/MDIO/link`：✅
  - `U-Boot IP data plane`：仍待解释
  - `Linux IPv4 TX/RX data plane`：✅
  - `Linux IPv6 link-local`：未确认/本轮未通

### 对后续任务的影响

1. **可以开始规划 NFS root bring-up**
   但应基于 Linux 已验证的 IPv4 路径，而不是假设 U-Boot `ping` 必须先通。
2. 如果后续只关心 Linux/NFS，不必再优先追 U-Boot `ping`。
3. 如果后续还要解释 U-Boot 零包，则应把问题收敛成：
    **U-Boot 专用数据面问题**，而不是板级网络硬件全局失效。

## §04.16.1 NFS Root 下网络验证（058x，2026-05-17）

在 release-r1 固定产物基础上，通过 NFS root 方式启动 Linux，
验证 NFS root 挂载期间网络是否可用：

- bit：`rocket64b2-r1.bit`
- boot.elf：`boot-r1.elf`
- Image：本地 `linux-stable/arch/riscv/boot/Image`
- NFS root：`workspace/dualv7-test/058x/nfsroot/`
- 日志：`workspace/dualv7-test/058x/uart.log`

**结果**：
- `eth0` link becomes ready ✅
- `IP-Config: Complete`，静态地址 `192.168.200.250` ✅
- `VFS: Mounted root (nfs filesystem)` ✅
- REALCHECK init 从 NFS 正确执行，`REALCHECK: READY` ✅
- ARP send OK (`ret=60`) — NFS root 期间网络可用 ✅

**结论**：Linux 在 NFS root 挂载阶段网络可用。
当前 REALCHECK init 是单次测试程序，执行完退出导致 kernel
panic，因此 `host-ping4` 不能用于 NFS root 持续网络验证。
生产环境需常驻 init（busybox/systemd）。

## §04.13 驱动修补实测结果（051x，2026-05-16）

### 修补内容

v12-v14 版本在 `u-boot/drivers/net/vivado_mii.c` 中补充了：

1. **`vivado_mii_start()`**：分配 16 个 RX buffer（`memalign`），填充 RX ring，
   写 `nic_control=0x03`（EN_RX|EN_TX）
2. **`vivado_mii_send()`**：写 TX descriptor（addr + size）→ kick `tx_inp` →
   轮询等待 `tx_out` 推进
3. **`vivado_mii_recv()`**：检查 `rx_out`，拷贝数据，回收 descriptor
4. v14 增加 `wmb()`/`mb()`/`fence w,w` 内存屏障

### 实测结果

| 现象 | 状态 |
|------|------|
| U-Boot `BOOTP broadcast N` 出现 | ✅ 网络栈正常调用 `send()` |
| `send: DONE` 打印 | ✅ 驱动认为 TX 完成 |
| 硬件 `tx_out` 推进 | ✅ DMA 引擎读完了 DDR 数据 |
| `tcpdump` 捕获 FPGA 发来的包 | ❌ **零包** |

### 分析

- 软件侧 `send()` 路径已打通（DMA descriptor → kick → hw completion）
- `tx_out` 推进说明硬件至少消费了 TX 描述符 / DMA 状态，
  但**不足以单独证明**有效帧已经进入 MAC 或 PHY
- **但 MII TX 物理链路上无有效帧**，原因可能为：
  1. **L1 cache 一致性**：`flush_dcache_range` 是 no-op，DMA 可能读到过期缓存
  2. **MII TX timing**：bit 有 WHS=-7.690ns hold 违例在 PHY 时钟域
  3. **MAC→PHY 链路**：`mii_tx_en`/`mii_txd` 可能在 PHY 端未被正确采样
- 下一步应先确认**同一 bit 下 Linux 是否可发包**：如 Linux 可发包 → 问题是 U-Boot 专用（cache/地址映射）；如 Linux 也不可发包 → 问题是 RTL/MAC/PHY 硬件层

### 关键文件

- v14 驱动：`202:~/vivado-risc-v/u-boot/drivers/net/vivado_mii.c`
- v14 boot.elf：`workspace/dualv7-test/051x/boot-uboot-v14.elf` (sha256 `8208421d...`)
- 原版备份：`202:~/vivado-risc-v/u-boot/drivers/net/vivado_mii.c.bak-051x`

## §04.14 外部方案调研结论（052x，2026-05-16）

### 核心发现

1. **`eth_mac_mii_fifo` 生态现状**：
   - 来自 alexforencich/verilog-ethernet（3k+ stars, 827 forks, 1203 commits），FPGA 以太网领域最广的开源库
   - 官方 30+ example 板全部使用 Gigabit+（SGMII/RGMII/GMII），**无 MII 10/100 软件栈示例**
   - RTL 本身是硅验证的，但"verilog-ethernet MII MAC + 自定义 DMA ring + U-Boot/Linux 驱动 + RISC-V"这条路**没有公开先例**

2. **MII PHY 时钟方案的合理性**（对比 LiteEth + verilog-ethernet `mii_phy_if.v`）：
   - 两者都用 BUFG 分发 PHY 提供的 25MHz TX/RX clk
   - 都用 async reset sync 跨时钟域
   - 都用 `IOB=TRUE` 约束输出寄存器
   - 我们当前的 BUFG 方案在两种参考实现中都一致，方案本身合理

3. **Cache coherency — 最关键的外部已知坑**：
   - Rocket Chip L1 cache 是 write-back/write-allocate，DMA 控制器不经过 L1 cache
   - CPU 写 DMA buffer → 数据残留 cache line → DMA 读到过期数据
   - U-Boot RISC-V 中 `flush_dcache_range` 在 `vivado_riscv64` 上是弱 no-op
   - Linux 当前驱动走 `dma_map_single()` / `dma_unmap_single()` 路线，
     不是 `dma_alloc_coherent()`
   - 唯一绕过方式：将 DMA buffer 映射到 non-cacheable 区域
   - 参考：RISC-V CMO 扩展（未 ratified）、Rocket Chip PMA 文档

4. **其他路径的软件栈成熟度**：
   - Xilinx AXI Ethernet + `xilinx_axienet` （✅ 主线成熟驱动，需换 IP + BD）
   - LiteEth + LiteX（⚠️ Wishbone 总线，不兼容当前 AXI 工程）
   - Linux `fpga-axi-eth`（✅ staging 驱动，已在 DTS 中，当前代码走 `dma_map_single`）

### 对当前路线的判断

**方案本身合理，但属于高调试成本的小众路线。** `eth_mac_mii_fifo` RTL 可靠，但完整链路（自定义 DMA + 自写驱动 + MII PHY + RISC-V）无公开先例。

**根因排障优先级**：
1. Cache coherency（最高嫌疑）— U-Boot DMA 读到过期缓存
2. MII TX WHS 违例（-7.690ns 在 25MHz 下可容忍但仍建议修复）
3. MAC `cfg_tx_enable` 初始值

**短期建议**：在同一 bit 下测试 Linux 发包（`fpga-axi-eth` 驱动已 probe），区分是 U-Boot 专用问题还是硬件全局问题。
**中期推荐**：如需稳定基线，评估迁移到 Xilinx AXI Ethernet Subsystem + `xilinx_axienet` 主线驱动。

### 外部来源链接

- https://github.com/alexforencich/verilog-ethernet
- https://github.com/alexforencich/verilog-ethernet/blob/master/rtl/eth_mac_mii_fifo.v
- https://github.com/alexforencich/verilog-ethernet/blob/master/rtl/mii_phy_if.v
- https://github.com/enjoy-digital/liteeth
- https://github.com/enjoy-digital/liteeth/blob/master/liteeth/phy/mii.py
- https://github.com/riscv/riscv-CMOs
- 完整报告：`doc/DualV7-网络IP外部方案调研.md`

## §04.15 053x Linux TX/RX smoke（2026-05-16）

### 背景

051x 修补 U-Boot `vivado_mii` 驱动后，软件 `send()` 路径走到 `tx_out` 推进，
但 tcpdump 仍零包。053x 用同一颗 bit 在 Linux 阶段做独立验证——
如果 Linux 可发包则是 U-Boot 专用问题，否则是硬件全局问题。

### 方法

- bit: `rocket64b2-mii-fifo-v2.bit` （不变）
- boot.elf: `boot-uboot-v11.elf` （原版，含 MDIO-only 驱动）
- 定制 initramfs：静态编译的最小网络测试程序，
  用 `AF_PACKET` 原始套接字发送 ARP 请求
- 并行 `tcpdump -i enp1s0` 抓包

### 结论：`linux-userspace-tx-ok-but-no-wire`

| 层级 | 现象 |
|------|------|
| Linux eth0 probe | ✅ `riscv-axi-eth probed as eth0` |
| PHY link | ✅ `IPv6: ADDRCONF(NETDEV_CHANGE): link becomes ready` |
| `sendto()` 返回值 | ✅ `ret=64 err=OK`（3 次发送均返回成功） |
| 物理网口 ARP | ❌ **tcpdump 零包** |

### 判定

当前证据已经明显偏向
**非纯 U-Boot 专用问题**：

- Linux 用户态 `AF_PACKET` 发送返回成功
- 同时本机抓包仍零包
- 再结合 051x 中 U-Boot 修补版同样零包

这说明问题大概率已经下沉到
**共享的 TX 数据面 / MAC / MII 边界 / 时序 / cache**
这一层。

但要注意：
053x **没有直接给 Linux 驱动加 `ndo_start_xmit` 级别的
内核 instrumentation**，
因此还不能把结论写死成
`linux-driver-path-ok-but-no-wire`。

### 建议下一步（按优先级）

1. ILA 抓 `mii_tx_en`/`mii_txd` 波形——确认 MAC 在 TX kick 后是否产生 MII 帧
2. 修复 WHS=-7.690ns hold 违例并重建 bit
3. 配置 Rocket PMA 将 DMA buffer 区域设为 non-cacheable
4. 降系统时钟排除 timing 嫌疑

## §04.18 059x U-Boot 静态 IP Ping 分层验证（2026-05-17）

### 验证基线

- bit：`rocket64b2-r1.bit`（release-r1）
- boot.elf：`boot-r1.elf`（release-r1，含 `vivado_mii` 驱动）
- **不加载** Image / ramdisk — U-Boot only
- FPGA IP：`192.168.200.250`（静态）
- 主机 IP：`192.168.200.201`
- 原始日志：`workspace/dualv7-test/059x/`
- GPT 复测日志：`workspace/dualv7-test/20260517-uboot-ping-realcheck/`

### U-Boot 驱动行为

`boot-r1.elf` 中 `vivado_mii` 驱动已有 `start()` 实现：
- `start: hw rx_i=0 rx_o=0 tx_i=0 tx_o=0` — DMA ring 初始化
- `start: nic_ctrl=00000003 DONE` — EN_RX(bit0)|EN_TX(bit1) 已设置
- `send()` 实现状态未在本轮单独验证（通过 ping 间接测试）

### 分层测试结果

| 层级 | 现象 | 状态 |
|------|------|------|
| U-Boot device probe | `vivado_mii` + `eth0: eth0@60020000` | ✅ |
| MDIO/PHY | PHY 0x0022:0x1560 (KSZ8081MNX, addr=1) | ✅ |
| `start()` / EN_TX / DMA ring | `nic_ctrl=0x03`, ring 初始化 DONE | ✅ |
| U-Boot `ping 192.168.200.201` | 停在 `Using eth0@60020000 device`，未形成成功 ping | ❌ |
| 主机 `tcpdump` 捕获 FPGA 发包 | 可见 FPGA ARP request + 主机 ARP reply；无 ICMP | ⚠️ |

### 校正后结论：`tx-on-wire-no-reply`

059x 原始记录把结果写成 `no-wire`，但该结论不成立。问题在于：

- `tcpdump` 在 FPGA 上板前就启动
- 抓包窗口只有 20 秒
- 它会在 U-Boot 真正执行 `ping` 之前就结束

2026-05-17 GPT 独立复测时，将抓包窗口对齐到
`=> ping 192.168.200.201` 这一刻，明确观察到：

- FPGA `00:0a:35:00:00:00 -> ff:ff:ff:ff:ff:ff`
  的 ARP request
- 主机 `94:c6:91:de:eb:f8 -> 00:0a:35:00:00:00`
  的 ARP reply

但**没有后续 ICMP**。

因此当前更准确的结论是：

- U-Boot TX 数据面至少已经能把 ARP 发上网线
- 主机回复也已回到链路
- 但 U-Boot 没有完成后续的 ICMP 路径，或没有正确消费 ARP reply

这修正了 059x 的“`no-wire`”误判，也说明后续不应再把问题压回
“FPGA 完全不发包”。

### 根因方向（不变）

1. **U-Boot RX / ARP reply 消费路径**
   — 主机 ARP reply 已在链路上出现，但 U-Boot 未进入 ICMP 阶段
2. **U-Boot `send()` 在 ARP 解析后的 ICMP 发送路径**
   — 需要分清 ARP-only 和 ICMP-send-after-ARP 两阶段
3. **L1 cache 一致性**
   — Linux 当前驱动路径是 `dma_map_single()`，U-Boot 仍可能受 cache 影响
4. **MII TX/RX 时序**
   — 仍需保留，尤其 RX 消费链路也需要纳入考虑

### 日志路径

- `workspace/dualv7-test/059x/uart-uboot.log`
- `workspace/dualv7-test/059x/tcpdump-ping.txt`
- `workspace/dualv7-test/059x/host-net-before.txt`
- 辅助脚本：`workspace/dualv7-test/059x/jtag-uboot-only.tcl`
  `workspace/dualv7-test/059x/uart-commands.py`
- GPT 复测：
  - `workspace/dualv7-test/20260517-uboot-ping-realcheck/uart-prepare.log`
  - `workspace/dualv7-test/20260517-uboot-ping-realcheck/uart-ping-window.log`
  - `workspace/dualv7-test/20260517-uboot-ping-realcheck/tcpdump-ping-window.log`

### §04.18.1 060x U-Boot RX instrumentation（2026-05-17）

在不改 bit 的前提下，给 `vivado_mii_recv()` 加最小 instrumentation，
仅重编 `boot.elf`，确认 ARP reply 是否进入 U-Boot RX ring。

**测试基线**：
- bit：`workspace/release-r1/rocket64b2-r1.bit`
- instrumented boot.elf：
  `workspace/dualv7-test/060x/boot-arp-rxinst.elf`
- 日志：
  - `workspace/dualv7-test/060x/uart-prepare.log`
  - `workspace/dualv7-test/060x/uart-ping.log`
  - `workspace/dualv7-test/060x/tcpdump-ping.log`

**观察结果**：
- Host `tcpdump` 明确看到：
  - FPGA `00:0a:35:00:00:00` 发出的 ARP request
  - Host `94:c6:91:de:eb:f8` 返回的 ARP reply
- U-Boot 串口 instrumentation 仅看到：
  - `recv: empty hw_rx_out=0 rx_out=0 int=000e0200 nic=00000000`
- **没有**看到任何：
  - `recv: slot=...`
  - `recv: dst=... src=... type=...`
  - `recv: arp op=...`

**结论**：
- `vivado_mii_recv()` 确实被网络栈调用
- 但在 ARP reply 已经回到网线的情况下，
  `ETH_RX_OUT` / `hw_rx_out` 仍然不前进
- 所以当前问题点**早于** ARP cache / ARP reply consume / ICMP 阶段
- 更准确地说，当前应优先怀疑：
  1. RX ring / RX DMA
  2. PHY->MAC receive path
  3. RX 侧时序 / 采样问题

这也意味着，原计划中的“先做 ARP reply consume debug”
不应直接展开到 U-Boot net 层解析，而应先确认
**reply 为什么没有进入 `vivado_mii_recv()` 可见的 RX packet**。

### §04.18.2 061x U-Boot RX ring maintenance 修补验证（2026-05-17）

060x 之后继续在**同一颗 release-r1 bit** 下，仅重编 `boot.elf` 做 U-Boot
软件侧修补，结果已经把问题从“可能 cache/硬件”收敛到
**U-Boot RX ring 维护逻辑 bug**。

#### 软件 bug 1：`start()` 把 RX ring 填满

060x 的 instrumentation 初看像“ARP reply 没有进入 U-Boot RX ring”，
但进一步核对 RTL 和软件 ring 语义后确认：

- U-Boot `vivado_mii_start()` 最初按 `RING_SIZE=16` 全量 post RX buffer
- 初始 `rx_inp=0 rx_out=0`
- post 16 次后 `rx_inp` 回卷到 `0`
- 对 RTL 而言，这等价于 `rx_pkt_inp == rx_pkt_out`，即 **空 ring**

最小修补是：**保留 1 个空槽**，不要把 RX ring 填满。

修完后首轮复测结果：
- `start: posted rx buffers, new rx_i=15 rx_o=0`
- Host ARP reply 已进入 `vivado_mii_recv()`
- FPGA 也已发出 ICMP echo request

这一步已经证明：
- 之前的 “reply 没进 RX ring” 不是板级硬件必然
- 至少首个阻塞点是 U-Boot 软件 ring 初始化错误

#### 软件 bug 2：`recv()` 消费后不补 RX buffer

首个修补后，U-Boot 仍未完成 ping。继续对照 Linux 驱动发现：

- U-Boot `vivado_mii_recv()` 消费一个 RX slot 后，只做：
  - `rx_out = rx_out + 1`
  - `writel(rx_out, ETH_RX_OUT)`
- **没有**像 Linux `axi_eth_add_rx_buffers()` 那样回补 RX buffer
- 在当前交换机背景 ARP 广播存在时，15 个已 post 的 RX slot 很快被耗尽
- 于是 ARP reply 虽然能进来，但后续 ICMP echo reply 可能落到
  “已经没有空闲 RX buffer”的窗口里

最小修补是新增：

- `vivado_mii_add_rx_buffers()`

并在 `recv()` 消费后立刻回补 ring。

#### 修补后实测结果

在 **不改 bit**、只重编 `boot.elf` 的前提下：

- 串口日志：
  - `start: posted rx buffers, new rx_i=15 rx_o=0`
  - `recv: arp op=2 ... tpa=192.168.200.250`
  - `recv: dst=00:0a:35:00:00:00 src=94:c6:91:de:eb:f8 type=0800`
  - `host 192.168.200.201 is alive`
- 主机抓包：
  - FPGA ARP request
  - Host ARP reply
  - FPGA ICMP echo request
  - Host ICMP echo reply

关键日志：
- `workspace/dualv7-test/060x/uart-ping-fix2.log`
- `workspace/dualv7-test/060x/tcpdump-ping-fix2.log`

#### 当前结论

1. **Linux 网络正常** 这一事实现在和 U-Boot 侧结果对上了  
   当前主要问题确实更像 U-Boot 软件，而不是共享硬件全局失效。
2. 至少对当前失败路径而言，`cache coherency` 已经不是主因。  
   如果是 cache 主因，仅修 RX ring 维护逻辑不应让 `ping` 直接成功。
3. 当前 U-Boot 网络链路已证实：
   - PHY/MDIO：OK
   - TX：OK
   - RX ingress：OK
   - ARP consume：OK
   - ICMP ping：OK
4. 后续若继续做 U-Boot 网络引导，应优先沿这份修补后的
   `vivado_mii.c` 继续，而不是回到“怀疑 bit/硬件/BootROM”。

### §04.18.3 063x U-Boot TFTP 取内核 + Linux NFS root（2026-05-17）

在 061x 修补后的 U-Boot 网络基线上，进一步完成了
**非 JTAG 下载内核/ramdisk** 的网络引导链验证。

#### 固定基线

- bit：`workspace/release-r1/rocket64b2-r1.bit`
- boot.elf：`workspace/release-r1-netboot/boot-r1-netboot.elf`
- Host IP：`192.168.200.201`
- FPGA IP：`192.168.200.250`
- TFTP/NFS root：
  `workspace/release-r1-netboot/nfsroot`

#### 实际采用的启动方式

1. JTAG 仅下载：
   - bit
   - `boot-r1-netboot.elf`
2. U-Boot 执行：
   - `ping 192.168.200.201`
   - `tftpboot 0x81000000 Image`
3. U-Boot `bootargs` 指向：
   - `root=/dev/nfs`
   - `nfsroot=192.168.200.201:/home/data/vivado-risc-v/workspace/release-r1-netboot/nfsroot,vers=3,tcp,rw`
4. `booti 0x81000000 - 0x10080`

#### 验证结果

| 层级 | 现象 | 状态 |
|------|------|------|
| U-Boot ping | `host 192.168.200.201 is alive` | ✅ |
| U-Boot TFTP | `Bytes transferred = 19769344 (12da800 hex)` | ✅ |
| Linux network bring-up | `riscv-axi-eth 60020000.eth0: 044x: probed as eth0` | ✅ |
| Linux NFS root | `VFS: Mounted root (nfs filesystem)` | ✅ |
| devtmpfs mount | `devtmpfs: mounted` | ✅ |

#### 为什么没有选 U-Boot `nfs` 取文件

本轮先试过 U-Boot `nfs` 直接抓取内核文件，但在当前主机配置下，
可见更多 RPC/portmapper 交互噪音，稳定性和可重复性都不如
`tftpboot`。因此当前主线固定为：

- **U-Boot TFTP 取内核**
- **Linux NFS root 挂根文件系统**

#### 关键日志

- UART：
  `workspace/dualv7-test/063x/uart-attach-tftp-nfsboot.log`
- Host 抓包：
  `workspace/dualv7-test/063x/tcpdump-attach-tftp-nfsboot.log`
- TFTP 服务日志：
  `workspace/dualv7-test/063x/dnsmasq-tftp.log`

#### 结论

当前 DualV7 的网络引导主线已经收敛为：

1. JTAG 只下 `bit + boot.elf`
2. U-Boot 用静态 IP + `tftpboot` 拉起内核
3. Linux 使用 NFS root

这条链路已经满足“**不要从 JTAG 下内核和 ramdisk**”的目标。

### §04.18.4 065x REALCHECK 常驻 init 修补（2026-05-17）

在 `dualv7-r2-uboot-tftp-nfs` 锁定之后，继续修补最小 NFS root
里的 `init`，避免 `REALCHECK` 结束后因退出而 panic。

#### 修补内容

- 源仓：`/home/data/vivado-risc-v/ramdisk-realcheck-src`
- 提交：`7a2e40d46a94ab861b925be7a1ed8b55937fd002`
- 变更：
  - `REALCHECK: done` 后不再 `return 0`
  - 先打印 `REALCHECK: hold`
  - 再进入无限 sleep 循环

#### 两步验证

1. **JTAG 下发 kernel 的窄验证**
   - 日志：`workspace/release-r2/uart-nfs-jtagkernel.log`
   - 现象：
     `REALCHECK: done` 后未见 panic
   - 随后 host ping：
     `workspace/release-r2/host-ping-after-fix.log`
     显示 `3/3` 成功

2. **完整网络引导链复测**
   - 工作目录：
     `workspace/release-r2-hotfix`
   - 日志：
     `workspace/release-r2-hotfix/uart-netboot-r2.log`
   - 现象：
     - `host 192.168.200.201 is alive`
     - `Bytes transferred = ...`
     - `VFS: Mounted root (nfs filesystem)`
     - `REALCHECK: READY`
     - `REALCHECK: done`
     - `REALCHECK: hold`

#### 当前结论

1. 当前推荐的网络引导执行路径是：
   - JTAG 只下 `bit + boot.elf`
   - U-Boot `tftpboot` 拉内核
   - Linux NFS root
   - `REALCHECK` 停在 `hold`
2. `dualv7-r2-uboot-tftp-nfs` 这个 release 本身仍保留“原始 init
   会退出”的历史事实；实际执行时应优先使用
   `workspace/release-r2-hotfix`。

### §04.18.5 067x BusyBox NFS root 验证（2026-05-17）

在 `release-r2-hotfix` 的网络引导基线上，进一步验证了一个
**可交互 BusyBox NFS root**。

#### 固定组合

- bit：
  `workspace/release-r2-hotfix/rocket64b2-r2.bit`
- boot.elf：
  `workspace/release-r2-hotfix/boot-r2.elf`
- rootfs：
  `workspace/release-r2-busybox/nfsroot`

#### GPT 复测结论

`workspace/dualv7-test/067x/gpt-busybox-retest.log` 证明：

1. U-Boot `ping 192.168.200.201`：OK
2. U-Boot `tftpboot 0x81000000 Image`：OK
3. Linux `Kernel command line` 已正确携带 BusyBox 的 NFS bootargs
4. `VFS: Mounted root (nfs filesystem)`：OK
5. BusyBox `init` / `rcS` 正常执行
6. `mount` / `ifconfig -a` / `cat /proc/net/dev` 可用

#### 更正 067x 的早期误判

067x 初版把主阻塞归到“`bootargs` 没有传进内核”。

GPT 复测后可确认：

- `bootargs` 传递本身没问题
- 问题更像是当时的交互脚本 / 重载流程不稳定
- 这条路径本身已经能带起 BusyBox 用户态

#### BusyBox 仓

- 路径：
  `/home/data/vivado-risc-v/busybox-nfsroot-src`
- commit：
  `6950e444f62889be56aeb6f3627ad8d9e7c402ee`

这是**当前可工作 rootfs 仓**，不是上游 BusyBox 源码仓。

### §04.18.6 068x z2m + BusyBox NFS root release（2026-05-17）

在 `066x` 已通过的 `rocket64z2m` bit 基础上，进一步验证了：

1. JTAG 只下载 `bit + boot.elf`
2. U-Boot 静态 IP + `tftpboot` 拉取内核
3. Linux 挂载 BusyBox NFS root
4. 双核 z2m 进入 BusyBox shell

#### 固定组合

- bit：
  `workspace/066x/rocket64z2m-066x.bit`
  (`sha256=655d7dac2fa2ede5858ccf27038d246da4a4652122262a64509cb15d1690bc38`)
- boot.elf：
  `workspace/release-r2-hotfix/boot-r2.elf`
- kernel：
  `linux-stable/arch/riscv/boot/Image`
- BusyBox rootfs：
  `workspace/release-r2-busybox/nfsroot`

#### 实测结论

`workspace/dualv7-test/068x/uart-z2m-busybox.log` 与
`workspace/dualv7-test/068x/busybox-shell-proof.log` 证明：

1. OpenSBI `Platform HART Count = 2`
2. Linux `smp: Brought up 1 node, 2 CPUs`
3. U-Boot `ping 192.168.200.201`：OK
4. U-Boot `tftpboot 0x81000000 Image`：OK
5. Linux `VFS: Mounted root (nfs filesystem)`：OK
6. BusyBox 用户态进入成功，shell 提示符为 `[~] #`
7. `mount` / `ifconfig -a` / `cat /proc/net/dev`：OK

#### release

已锁定：

- `dualv7-r3-z2m-busybox-netboot`

当前这条 release 的本质是：

- 继承 `r2` 的 U-Boot 网络引导软件基线
- 将 bit 切到 `rocket64z2m`
- 将 rootfs 切到可交互 BusyBox NFS root

### §04.19 网络调试复盘入口

这条网络 bring-up 线已经走过一轮完整弯路复盘。

后续如果再做网络定位，先看：

- `§13 网络调试复盘`
- `workspace/knowledge-graph/2026-05-17-network-debug-postmortem-kg.md`

核心结论先写死：

1. 不要再把 U-Boot 网络失败优先压给 BootROM
2. 不要再用“单次没抓到包”直接下 `no-wire`
3. 不要在未锁定 `bit + boot.elf + Image + rootfs` 时下网络结论
4. Linux 网络既然已经通，后续 U-Boot 问题默认先查软件层
