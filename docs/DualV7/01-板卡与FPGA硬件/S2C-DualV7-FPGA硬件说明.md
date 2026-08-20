# S2C Dual V7 FPGA 硬件说明

**最后更新**：2026-05-27  
**适用工程**：vivado-risc-v（rocket64b2/z1/z2m）

---

## 1. 板卡概述

| 参数 | 值 |
|------|-----|
| 型号 | **S2C Dual Virtex-7 TAI Logic Module (TAI LM)** |
| 手册 | `doc/AI相关资料/Dual V7 Hardware Reference Manual v1.08.pdf` |
| FPGA 数量 | 2 片（标称 **F1** / **F2**），当前工程**仅使用 F1** |
| FPGA 型号 | **Xilinx Virtex-7 XC7V2000T** |
| 封装 | FLG1925 |
| Speed Grade | **-1L**（最慢速级） |
| Vivado 格式 | `xc7v2000tflg1925-1` |
| 板级尺寸 | 260.0 mm × 230.0 mm |
| 电源输入 | PC 开关电源（12V@16A, 5V@16A） |
| Config Voltage | 1.8V，CFGBVS = GND |
| 风扇 | PWM 控制板载风扇 |

---

## 2. FPGA 资源容量

### 2.1 XC7V2000T 芯片资源

| 资源 | 单芯片 | 双芯片总计 |
|------|--------|-----------|
| **Logic Cells** | **1,954,560** | 3,909,120 |
| **Slice LUTs**（6-LUT） | **1,221,600** | 2,443,200 |
| **Slice Registers** | **2,443,200** | 4,886,400 |
| **DSP48E1 Slices** | **2,160** | 4,320 |
| **Block RAM (36Kb)** | **1,292**（46,512 Kb） | 2,584（93,024 Kb） |
| **GTX Transceivers** | 36（芯片总计） / **16（板上引出）** | 72 / 32 |
| **Max User I/O** | **1,200**（含 dedicated + shared） | 2,400 |
| **Global Clocks** | 14 | 14（分布到两片） |

### 2.2 当前工程资源占用

| 配置 | 核心 | Slice LUTs | 占用率 | Registers | BRAM (36K) |
|------|------|-----------|--------|-----------|-----------|
| `rocket64b2` | 1×Big Rocket | 84,322 | **6.90%** | 51,953 | — |
| `rocket64z1` | 1×MegaBoom Z1 | 436,256 | **35.71%** | 152,525 | — |
| `rocket64z2m` | **2×MegaBoom Z1** | 829,901 | **67.94%** | 271,416 | 290 (22.45%) |

双核 MegaBoom 占用约 68% LUT，**仍有 ~32% 余量**用于调试逻辑或附加外设。

---

## 3. 连接器与子卡

### 3.1 F1 专用连接器（当前工程使用）

| 连接器 | 型号 | 用途 | 当前连接 |
|--------|------|------|---------|
| **J8** | Samtec QTH-120 | 通用 I/O (120-pin) | **MMC1 TF 卡槽子卡**：SD 卡启动与 DMA |
| **J9** | Samtec QTH-120 | 通用 I/O (120-pin) | **BIOS 子卡**：以太网 PHY (KSZ8081MNX) + SRAM/Flash |
| **J10** | Samtec QTH-120 | 通用 I/O (120-pin) | **PCI 子卡**：当前未使用 |

### 3.2 F2 专用连接器（当前工程未使用）

| 连接器 | 型号 | 用途 |
|--------|------|------|
| **J3** | Samtec QTH-120 | F2 通用 I/O (120-pin) |
| **J4** | Samtec QTH-120 | F2 通用 I/O (120-pin) |
| **J5** | Samtec QTH-120 | F2 通用 I/O (120-pin) |

### 3.3 共享 I/O 连接器

| 连接器 | 用途 |
|--------|------|
| **J2** | 共享 I/O |
| **J6** | 共享 I/O |
| **J7** | 共享 I/O |
| **J12** | 共享 I/O |

### 3.4 DDR3 内存

| 参数 | 值 |
|------|-----|
| 插槽 | **J14** SO-DIMM 插槽 |
| 颗粒型号 | **MT41K256M16XX-125**（Micron 4Gb, 256Mx16, DDR3-1600 降频至 DDR3-800） |
| 数据宽度 | **64-bit**（8 DQ byte lanes × 8 DQS 对） |
| Rank | 双 rank（`cs_n[0]` + `cs_n[1]`） |
| 地址 | 15-bit row + 10-bit col + 3-bit bank |
| I/O 电压 | **1.5V**（SSTL15 / DIFF_SSTL15_T_DCI） |
| MIG 速率 | 400 MHz / **800 MT/s**（TimePeriod = 2500 ps） |

---

## 4. 当前工程外设接口

### 4.1 时钟源

| 信号 | FPGA 引脚 | 类型 | 频率 |
|------|----------|------|------|
| `s2cclk_1_p` | **L4** | LVDS | **100 MHz** |
| `s2cclk_1_n` | **L3** | LVDS | 100 MHz |
| `SW1`（复位） | **AP31** | active-low, PULLUP | — |

### 4.2 时钟树（当前 rocket64z2m r3）

| 时钟域 | 频率 | 来源 | 消费者 |
|--------|------|------|--------|
| **SoC 主域** | **10 MHz** | clk_wiz clk_out1 | CPU core ×2, MEM/IO/DMA AXI, Ethernet logic |
| **UART/SD 外设域** | **100 MHz** | clk_wiz clk_out3 | UART, SD controller |
| **MIG 参考时钟** | **200 MHz** | clk_wiz clk_out2 | MIG sys_clk_i / clk_ref_i |
| **MIG UI** | **100 MHz** | MIG 内部 PLL | MIG AXI 用户接口 |
| **DDR3 PHY IO** | 400 MHz (800 MT/s) | MIG 内部 PLL | DDR3 物理层 |
| **Ethernet MII** | 25 MHz | KSZ8081 PHY | MII PHY 侧 |

> 20 MHz 实验基线中 SoC 主域提升至 20 MHz（WNS = +7.891ns，timing clean）。

### 4.3 UART

| 参数 | 值 |
|------|-----|
| 控制器 | 自定义 AXI4-Lite UART |
| 地址 | `0x60010000` |
| TXD 引脚 | **AU42**（LVCMOS18） |
| RXD 引脚 | **AV42**（LVCMOS18） |
| 波特率 | **115200** 8N1 |
| 主机设备 | `/dev/ttyUSB2`（CH341 USB-UART） |
| symlink | `/dev/serial/by-id/usb-1a86_5523-if00-port0` |

### 4.4 以太网（J9 子卡）

| 参数 | 值 |
|------|-----|
| PHY 型号 | **KSZ8081MNX**（Microchip/Micrel, 32-QFN） |
| 速率 | **10/100 Mbps**（无千兆能力） |
| 模式 | **MII**（4-bit 数据，不支持 SGMII/RGMII） |
| IO Standard | **LVCMOS18** |
| PHY 地址 | **1**（PHYAD[2:0] = 001） |
| 主机 IPv4 | `192.168.200.201/24` |
| FPGA IPv4 | `192.168.200.250` |

MII 信号引脚（共 18 个）：

| 信号 | 方向 | FPGA 引脚 |
|------|------|----------|
| `mii_tx_en` | FPGA→PHY | AU27 |
| `mii_txd[0:3]` | FPGA→PHY | BA25, AY25, BB27, BB26 |
| `phy_tx_clk` | PHY→FPGA | AR26 (25 MHz) |
| `phy_rx_clk` | PHY→FPGA | AT23 (25 MHz) |
| `mii_rx_dv` | PHY→FPGA | AU25 |
| `mii_rxd[0:3]` | PHY→FPGA | AT25, AR25, AY27, AY26 |
| `mii_rx_er` | PHY→FPGA | BC28 |
| `mii_crs` | PHY→FPGA | BA24 |
| `mii_col` | PHY→FPGA | BB25 |
| `mii_mdio` | PHY↔FPGA | AP23 |
| `mii_mdc` | FPGA→PHY | AL23 |
| `phy_rst_n` | FPGA→PHY | BA18 |

### 4.5 SD 卡（J8 子卡 MMC1）

| 信号 | FPGA 引脚 | IO Standard |
|------|----------|-------------|
| `sdio_clk` | AT37 | LVCMOS18, IOB TRUE |
| `sdio_cmd` | AT38 | LVCMOS18, IOB TRUE |
| `sdio_dat[0]` | BA43 | LVCMOS18, IOB TRUE |
| `sdio_dat[1]` | AY43 | LVCMOS18, IOB TRUE |
| `sdio_dat[2]` | AW44 | LVCMOS18, IOB TRUE |
| `sdio_dat[3]` | AW43 | LVCMOS18, IOB TRUE |
| `sdio_cd`（TFCD） | BA39 | LVCMOS18 |

### 4.6 GPIO LED（板载）

| 信号 | FPGA 引脚 | 电平 |
|------|----------|------|
| LED0 | AH44 | active-high |
| LED1 | AH43 | active-high |
| LED2 | AL40 | active-high |

AXI GPIO 地址 `0x60040000`，`GPIO_OUTPUT_VAL[2:0]` 控制三个 LED。

---

## 5. FPGA 烧录指南

### 5.1 硬件准备

| 设备 | 型号 | 备注 |
|------|------|------|
| JTAG 适配器 | **Digilent JTAG-SMT2**（SN: SULEE2211346A） | VID:PID `0403:6010`, FT2232H |
| USB 线 | micro USB | 连接 JTAG-SMT2 与主机 |
| 电源 | PC 开关电源（12V + 5V） | 连接至板卡电源接口 |
| 网络线 | 以太网线（可选） | 仅网络引导时需连接 |

### 5.2 启动 hw_server

```bash
# 设置 Vivado 环境
source /tools/Xilinx/2025.1/Vivado/settings64.sh

# 启动硬件服务器（后台运行）
pgrep -f hw_server >/dev/null || \
  hw_server -d >/tmp/hw-server.log 2>&1 &

# 确认运行中
sleep 2
ss -tlnp | grep 3121
```

### 5.3 烧录 bitstream

```tcl
# 连接 hw_server
connect -url tcp:localhost:3121

# 查看所有 target
targets

# 选择 FPGA（target 序号 1）
targets 1

# 烧录 bitstream（约 2 分钟）
fpga -file /path/to/your.bit
```

### 5.4 完整 JTAG Boot（bit + boot.elf + kernel）

```tcl
connect -url tcp:localhost:3121
targets 1
fpga -file /path/to/rocket64z2m-r3.bit

# 停 Hart#0
targets -set -filter {name =~ "Hart #0*"}
stop

# 下载内核 Image 到 DDR
targets -set -filter {name =~ "RISC-V*"}
dow -data /path/to/Image 0x81000000

# 下载 boot.elf（OpenSBI + U-Boot）
targets -set -filter {name =~ "Hart #0*"}
dow -clear /path/to/boot-r3.elf

# 设置启动参数
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000

# 开始执行
con
exit
```

### 5.5 网络引导（仅 bit + boot.elf）

无需下载内核和 ramdisk，由 U-Boot 通过 TFTP 获取内核、NFS 挂载 rootfs：

```tcl
connect -url tcp:localhost:3121
targets 1
fpga -file /path/to/rocket64z2m-r3.bit
targets -set -filter {name =~ "Hart #0*"}
stop
dow -clear /path/to/boot-r3.elf
rwr a0 0
rwr a1 0x10080
rwr s0 0x80000000
con
exit
```

### 5.6 烧录后的 U-Boot 网络引导命令

FPGA 启动后，在串口终端 U-Boot `=>` 提示符下执行：

```
setenv ethact eth0@60020000
setenv ipaddr 192.168.200.250
setenv serverip 192.168.200.201
setenv netmask 255.255.255.0
ping 192.168.200.201
tftpboot 0x81000000 Image
setenv bootargs 'earlycon console=ttyAU0,115200 root=/dev/nfs nfsroot=192.168.200.201:/path/to/nfsroot,vers=3,tcp,rw ip=192.168.200.250:192.168.200.201::255.255.255.0:dualv7:eth0:off'
booti 0x81000000 - 0x10080
```

### 5.7 注意事项

- bit 与 boot.elf **必须配套使用**（同一次构建），混用会导致网络异常
- 烧录约需 2 分钟（bit ~54 MB）
- JTAG Boot 完全绕过 BootROM，不依赖 SD 卡
- `hw_server` 默认监听 `localhost:3121`

---

## 6. 串口使用说明

### 6.1 连接确认

```bash
# 确认串口设备存在
ls -l /dev/serial/by-id/usb-1a86_5523-if00-port0

# 预期输出 → /dev/ttyUSB2
```

### 6.2 串口配置

```bash
stty -F /dev/serial/by-id/usb-1a86_5523-if00-port0 \
  115200 raw -echo -echoe -echok
```

### 6.3 查看串口输出

```bash
# 实时查看（Ctrl+C 退出）
cat /dev/serial/by-id/usb-1a86_5523-if00-port0

# 带时间戳抓日志
timeout 120 cat /dev/serial/by-id/usb-1a86_5523-if00-port0 \
  | tee /tmp/uart.log
```

### 6.4 发送命令（中断 autoboot）

看到 `Hit any key to stop autoboot:` 后：

```bash
# 向串口发送回车
echo -ne '\r' > /dev/serial/by-id/usb-1a86_5523-if00-port0
```

进入 U-Boot `=>` 提示符后即可交互。

### 6.5 交互终端（推荐）

```bash
# 使用 screen
screen /dev/serial/by-id/usb-1a86_5523-if00-port0 115200
# Ctrl+A Ctrl+D 断开; Ctrl+A Ctrl+\ 退出

# 或使用 picocom
picocom -b 115200 /dev/serial/by-id/usb-1a86_5523-if00-port0
# Ctrl+A Ctrl+X 退出
```

### 6.6 常见问题

| 问题 | 检查 |
|------|------|
| 串口无输出 | 检查 USB 线连接；确认 FPGA 已正确烧录 bitstream |
| 乱码 | 确认波特率 = 115200；确认 `stty` 配置的 `-echo` 未遗漏 |
| `ttyUSB2` 不存在 | 检查 CH341 USB-UART 驱动（`lsusb` 看 `1a86:5523`） |
| 权限错误 | 确认 `/dev/ttyUSB2` 有 crw-rw-rw- 权限 |
| U-Boot 不响应 | FPGA 复位后立刻连续发送回车打断 autoboot |

---

## 7. 电源与复位

| 电源轨 | 电压 | 用途 |
|--------|------|------|
| VCCINT | 1.0V | FPGA 内核电压 |
| VCCBRAM | 1.0V | Block RAM 电压 |
| VCCAUX | 1.8V | FPGA 辅助电压 |
| VCCO | 1.8V | Bank I/O 电压（LVCMOS18） |
| VDD_DDR | 1.5V | DDR3 内存电压 |
| VDDA_3.3 | 3.3V | PHY 模拟电源 |

复位按键 SW1（AP31, active-low, PULLUP）：按下复位 FPGA。

---

## 8. 资源参考

| 资料 | 位置 |
|------|------|
| 板卡手册 | `doc/AI相关资料/Dual V7 Hardware Reference Manual v1.08.pdf` |
| 子卡原理图 | `doc/V7子卡原理图和PCB/MPRC-V7FPGA_SCHV12_20230526.pdf` |
| J8 管脚表（SD） | `doc/V7子卡原理图和PCB/S2C-V7-J8-EMMC插座管脚对应表20230801.xlsx` |
| J9 管脚表（ETH） | `doc/V7子卡原理图和PCB/S2C-V7-J9-BIOS插座管脚对应表20201012.xlsx` |
| J10 管脚表（PCI） | `doc/V7子卡原理图和PCB/S2C-V7-J10-PCI插座管脚对应表20200925.xlsx` |
| PHY 数据手册 | `doc/AI相关资料/KSZ8081MNX-RNB Data Sheet v1.0.pdf` |
| DDR3 颗粒手册 | `doc/AI相关资料/M471B5773内存条.pdf` |
| SPI Flash 手册 | `doc/AI相关资料/w25q32fv_3v3.pdf` |
| 知识库-板卡规格 | `code-agent/knowledge/03-board-dualv7.md` |
| 知识库-总线架构 | `code-agent/knowledge/06-bus-architecture.md` |
| 本地操作流程 | `doc/DualV7-FPGA本地操作流程.md` |
