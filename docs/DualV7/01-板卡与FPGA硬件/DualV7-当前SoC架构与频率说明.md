# DualV7 当前 SoC 架构与频率说明

本文对应当前已验证的 bit 基线：

- 板卡：`S2C Dual Virtex-7 TAI LM`
- FPGA：`xc7v2000tflg1925-1`
- Release：`dualv7-r3-z2m-busybox-netboot`
- bit：`/home/data/vivado-risc-v/workspace/release-r3-z2m-busybox/rocket64z2m-r3.bit`
- sha256：`655d7dac2fa2ede5858ccf27038d246da4a4652122262a64509cb15d1690bc38`
- 状态：功能已验证；timing 未完全收敛

## 1. 版本与代码来源

| 组件 | 位置 | commit | tag |
|---|---|---|---|
| 主工程 | `zzx@202:~/vivado-risc-v` | `137a01660c63948368aafd31fdabaf742314acd1` | `dualv7-r3-z2m-busybox-netboot` |
| U-Boot | `zzx@202:~/vivado-risc-v/u-boot` | `fe394fd6bba5105b0d2ef5793e617ede412defe0` | `dualv7-r3-z2m-busybox-netboot` |
| Linux | `/home/data/vivado-risc-v/linux-stable` | `567ee7b75dd6a078b7f02b839fae36b2c33563d2` | `dualv7-r3-z2m-busybox-netboot` |
| BusyBox rootfs | `/home/data/vivado-risc-v/busybox-nfsroot-src` | `6950e444f62889be56aeb6f3627ad8d9e7c402ee` | `dualv7-r3-z2m-busybox-netboot` |

## 2. SoC 总体架构

当前 bit 使用 `CONFIG=rocket64z2m`，对应：

- CPU 类型：`2 × MegaBoom Z1`
- 核数：`2`
- ISA：`rv64imafdc`
- 宽总线配置：`RocketWideBusConfig`
- Cache 配置：`WithInclusiveCache`
- 扩展寻址：`WithExtMemSize`

运行时证据：

- OpenSBI：`Platform HART Count : 2`
- Linux：`smp: Brought up 1 node, 2 CPUs`
- PMP Address Bits：`36`

可把当前 SoC 粗略理解为：

```text
                +-----------------------------------+
                |          2 x MegaBoom Z1         |
                |      (RocketChip / RV64GC)       |
                +-----------------+-----------------+
                                  |
                 +----------------+----------------+
                 |                                 |
              MEM_AXI4                          IO_AXI4
             (256-bit)                         (256-bit)
                 |                                 |
          +------+-------+                 +-------+----------------------+
          | axi_smc_1    |                 | io_axi_s SmartConnect       |
          | 256 -> 64    |                 |                             |
          +------+-------+                 +-- UART  0x60010000          |
                 |                            SD    0x60000000           |
                MIG                           ETH   0x60020000           |
                 |                            XADC  0x60030000           |
              DDR3 1 GiB                      LED   0x60040000           |
                                              DDRSTAT 0x60050000         |
```

同时存在 DMA 回写路径：

- `SD / Ethernet` 通过 `io_axi_m` 回写 `DMA_AXI4`
- `DMA_AXI4` 为 256-bit

## 3. 存储与外设

### 3.1 主存

- 类型：DDR3
- 容量：`1 GiB`
- 连接方式：`MIG`
- 访问路径：`MEM_AXI4 -> axi_smc_1 -> MIG -> DDR3`

### 3.2 主要 MMIO 外设

| 地址 | 外设 | 说明 |
|---|---|---|
| `0x60000000` | SD 控制器 | SD/MMC 启动与 DMA |
| `0x60010000` | UART | 串口控制台，`115200` |
| `0x60020000` | Ethernet | MII PHY，Linux/U-Boot 均已验证到可用阶段 |
| `0x60030000` | XADC | 板级监测 |
| `0x60040000` | LED GPIO | 用户 LED |
| `0x60050000` | DDR Status GPIO | MIG 状态寄存器 |

### 3.3 以太网

- PHY：`KSZ8081MNX`
- 模式：`MII`
- 速率：`10/100 Mbps`
- 时钟分层：
  - MAC/AXI 侧：挂 `AXI_clock = 10 MHz`
  - PHY 侧：`phy_tx_clk / phy_rx_clk = 25 MHz`
- 当前软件路径：
  - U-Boot：静态 IP + `ping` + `tftpboot`
  - Linux：IPv4 可用，已验证 `NFS root`

## 4. 时钟与频率

### 4.1 板级输入时钟

- 板级主时钟：`s2cclk_1_p/n`
- 频率：`100 MHz`
- 类型：`LVDS`

### 4.2 当前 bit 的板级时钟树

当前 `rocket64z2m` bit 的 DualV7 shell 时钟树要分两层看：

1. `clk_wiz_0/clk_out1`：当前硬件实际接到 `RocketChip/clock` 的 SoC 主时钟
2. `clock_100MHz`：只给 UART / SD / SmartConnect 外设侧使用

直接证据：

- `zzx@202:~/vivado-risc-v/board/dualv7/riscv-2025.1.tcl`
  中 `clk_wiz_0` 被固定为：
  - `CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {10.000}`
- 同一文件把
  `clk_wiz_0/clk_out1 -> RocketChip/clock`
- `zzx@202:~/vivado-risc-v/workspace/rocket64z2m/system-dualv7.tcl`
  虽然写了 `set riscv_clock_frequency 20.0`，
  但 `vivado.tcl` 对 `dualv7` 有特判：
  不会再用这个变量去覆盖 `clk_wiz_0` 的 `clk_out1`

因此，当前 bit 的**硬件实际频率**如下：

| 时钟/域 | 频率 | 来源 | 用途 |
|---|---:|---|---|
| `AXI_clock` | `10 MHz` | `clk_wiz clk_out1` | RocketChip core、MEM/IO AXI 主域、Ethernet logic 侧 |
| `clock_100MHz` | `100 MHz` | `clk_wiz clk_out3` | UART、SD、外设 SmartConnect `aclk1` |
| `clock_200MHz` | `200 MHz` | `clk_wiz clk_out2` | MIG `sys_clk_i` / `clk_ref_i` |
| `MIG UI clk` | `100 MHz` | MIG 内部 PLL | MIG AXI 用户接口 |
| `DDR3 PHY IO clk` | `400 MHz` | MIG 内部 PLL | DDR3 PHY，等效 `800 MT/s` |

补充说明：

- `AXI_clock` 当前是 `10 MHz`，`clock_100MHz` 是 `100 MHz`，两者是明确异步域。
- 当前 UART 波特率固定为 `115200`，其寄存器访问时钟来自 `clock_100MHz`。
- Ethernet MII 物理侧另外使用来自 PHY 的 `25 MHz` 时钟，不属于 `clk_wiz_0` 输出。

### 4.3 软件可见频率

当前运行时已直接观测到的频率信息：

- OpenSBI timer：`aclint-mtimer @ 200000Hz`
- Linux 启动日志：
  - `riscv_timer_init_dt: Registering clocksource`
  - `Calibrating delay loop ... 0.40 BogoMIPS`

这里要区分两类频率：

1. **硬件主时钟/板级时钟**  
   当前 SoC 主域是 `10 MHz`，UART/SD 等外设域是 `100 MHz`，DDR 参考时钟是 `200 MHz`。

2. **软件可见 timer 频率**  
   当前 OpenSBI/Linux 看到的 `aclint-mtimer` 频率是 `200 kHz`。  
   这不是 CPU 主时钟本身，而是软件使用的 timer/timebase。

3. **当前还存在“软件声明频率”和“硬件实际频率”不一致**  
   当前 `system-dualv7.tcl` 里 `riscv_clock_frequency = 20.0`，但 DualV7
   板级 TCL 将 `clk_out1` 固定在 `10 MHz`，并且 `vivado.tcl` 对 `dualv7`
   禁止再覆盖这个值。  
   因此：
   - **硬件实际 SoC 主时钟 = 10 MHz**
   - **OpenSBI/Linux 当前 timer 看到的是 200 kHz**
   - 这两者说明当前生成链仍有频率口径不一致问题，后续若做严格发布，
     应单独收敛 `riscv_clock_frequency` / DTS / timer 配置。

因此，当前 bit 的频率口径建议写成：

- SoC 主时钟域：`10 MHz`
- UART/SD/外设 AXI-Lite 域：`100 MHz`
- DDR 参考时钟：`200 MHz`
- DDR PHY IO：`400 MHz`（`800 MT/s`）
- OpenSBI/Linux timer：`200 kHz`

### 4.4 Core / 总线 / IP 频率表

下面这张表只列当前 bit 最关心的运行频率归属。

| 对象 | 频率 | 说明 |
|---|---:|---|
| CPU core（2 × MegaBoom Z1） | `10 MHz` | `RocketChip/clock <- clk_wiz_0/clk_out1` |
| SoC 主总线域（RocketChip 主域） | `10 MHz` | Core 与主 AXI 侧同域 |
| `MEM_AXI4` | `10 MHz` | RocketChip 发出的内存主接口 |
| `IO_AXI4` | `10 MHz` | RocketChip 发出的 MMIO 主接口 |
| `DMA_AXI4` | `10 MHz` | RocketChip 侧 DMA 回写接口 |
| `AXI_clock` | `10 MHz` | 当前 bit 的主 AXI/SoC 时钟 |
| `clock_100MHz` | `100 MHz` | UART/SD/部分 SmartConnect 外设侧时钟 |
| UART IP | `100 MHz` | `UART/clock <- clock_100MHz` |
| SD 控制器 IP | `100 MHz` | `SD/clock <- clock_100MHz` |
| `io_axi_s` SmartConnect S00 侧 | `10 MHz` | 核心侧接入 `IO_AXI4` |
| `io_axi_s` M00/M01 外设侧 | `100 MHz` | 给 UART / SD 做跨域 |
| `io_axi_s` M02-M05 外设侧 | `10 MHz` | 当前用于 ETH / XADC / LED / DDRSTAT |
| `io_axi_m` SmartConnect S00/S01 侧 | `10 MHz` | SD / ETH 的 DMA 回写入口 |
| `io_axi_m` M00 侧 | `10 MHz` | 回写到 RocketChip `DMA_AXI4` |
| Ethernet IP（AXI/MMIO/MAC logic 侧） | `10 MHz` | `Ethernet/clock <- AXI_clock` |
| Ethernet MII PHY 侧 | `25 MHz` | `phy_tx_clk / phy_rx_clk` 来自 PHY |
| XADC AXI-Lite 接口 | `10 MHz` | `XADC/s_axi_aclk <- AXI_clock` |
| LED GPIO AXI 接口 | `10 MHz` | `LEDGPIO/s_axi_aclk <- AXI_clock` |
| DDR Status GPIO AXI 接口 | `10 MHz` | `DDRSTAT/s_axi_aclk <- AXI_clock` |
| MIG `sys_clk_i` / `clk_ref_i` | `200 MHz` | 板级 DDR 参考时钟 |
| MIG UI AXI 接口 | `100 MHz` | MIG 内部 `ui_clk` |
| DDR3 PHY IO | `400 MHz` | 等效 `800 MT/s` |
| OpenSBI/Linux timer | `200 kHz` | `aclint-mtimer @ 200000Hz` |

## 5. 当前 bit 的运行能力

当前 `rocket64z2m-r3.bit` 已实测通过：

- 2 核启动
- U-Boot 静态 IP
- U-Boot `ping 192.168.200.201`
- U-Boot `tftpboot 0x81000000 Image`
- Linux `root=/dev/nfs`
- BusyBox NFS root

当前推荐启动方式：

1. JTAG 仅下载：
   - `rocket64z2m-r3.bit`
   - `boot-r3.elf`
2. 在 U-Boot 中执行：
   - `ping 192.168.200.201`
   - `tftpboot 0x81000000 Image`
   - 设置 `bootargs` 指向 NFS root
   - `booti 0x81000000 - 0x10080`

## 6. Timing 状态

当前 bit 的实现后关键结果：

- `WNS = -0.755ns`
- `TNS = -2.854ns`
- `WHS = +0.041ns`

因此当前结论是：

- **功能已验证**
- **不是 timing clean 基线**

如果后续需要正式对外发布硬件版本说明，建议同时标注：

> 当前 `rocket64z2m` bit 已完成双核 + U-Boot 网络取核 + Linux BusyBox NFS root 功能验证，但实现结果仍存在 setup timing 违例，属于可运行验证版，不属于 timing signoff 版。

## 7. 证据日志

- [066x 双核 netboot 日志](/home/data/vivado-risc-v/workspace/066x/uart-netboot-z2m.log)
- [068x 双核 BusyBox NFS root 日志](/home/data/vivado-risc-v/workspace/dualv7-test/068x/uart-z2m-busybox.log)
- [Release 清单](/home/data/vivado-risc-v/doc/DualV7-Release清单.md)
- [总线与时钟树知识库](/home/data/vivado-risc-v/code-agent/knowledge/06-bus-architecture.md)

---
## 8. `rocket64z2m` 20MHz 实验频率（070x，2026-05-19）

实验线，不覆盖上述 release 基线。仅记录 20MHz 的实测频率与 timing 结果。

### 8.1 硬件实际频率（20MHz 实验）

改动：仅 `board/dualv7/riscv-2025.1.tcl` 中 `CLKOUT1_REQUESTED_OUT_FREQ` 10.000 → 20.000。

| 对象 | 频率 | 对比 10MHz |
|------|------|-----------|
| CPU core (2×MegaBoom Z1) | **20 MHz** | ↑ |
| `MEM/IO/DMA_AXI4` | **20 MHz** | ↑ |
| UART/SD | 100 MHz | 不变 |
| Ethernet MII PHY | 25 MHz | 不变 |
| MIG sys_clk | 200 MHz | 不变 |
| DDR3 PHY IO | 400 MHz | 不变 |

### 8.2 20MHz Post-route Timing

| 指标 | 20MHz | 10MHz |
|------|-------|-------|
| WNS | **+7.891 ns** | -0.755 ns |
| TNS | **0.000 ns** | -2.854 ns |
| WHS | +0.131 ns | +0.041 ns |

20MHz 时序反而优于 10MHz — 10MHz 那轮的 WNS 违例是当时 P&R 的随机结果，非硬上限。

### 8.3 运行时验证

| 判据 | 20MHz | 10MHz |
|------|-------|-------|
| 2 核启动 | ✅ | ✅ |
| U-Boot ping + TFTP | ✅ | ✅ |
| Linux NFS root | ✅ | ✅ |
| BusyBox shell | ✅ | ✅ |
| telnetd | ✅ | 未测试 |
| kernel bootargs 传递 | ✅ | ⚠️ (067x 失败) |

### 8.4 证据日志

- `workspace/dualv7-test/070x/uart-20mhz.log`
- `workspace/070x/rocket64z2m-20mhz.bit` (`4581d346`)
