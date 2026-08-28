# T026: SPI 加载（方案 B：host 实时 SPI 灌入）

## 目标
host 经 SPI 线**流式加载** ELF 到内存（spi2tlul → Xbar → DDR/TCM），大用例加载从 UART 的 15min 降到秒级。

## 背景（已查证）
- **方案 B 无 4MB 限制**：数据流式直灌（不经板载 W25Q32FV flash，flash 仅 4MB 装不下 10MB 用例），容量只受内存 + 传输时间
- **SPI 无多时钟域**：chip_nexus SPI 经 `io_external_ports_spim_*`（main 域），外部 SCLK 由 SPI 模块内部采样——无需 async/CDC
- **上游已有**：`spi2tlul`（HostConfig，TL 主机桥）+ `spi_master`（0x40020000）+ `spi_master_flash`（0x40070000）——spi2tlul 连接 `coralnpu_device/sram/ddr_ctrl/ddr_mem`
- **spi2tlul 未实例化**：chisel SoC 只有 HostConfig 声明，无 `new Spi2TLUL`——**预留未完成**，T026 需接入
- **两个版本**：
  - **V1**（Spi2TLUL）：纯协议桥，SPI 数据直接转 TL 写——**无 DMA**，适合方案 B 流式
  - **V2**（Spi2TLULV2）：DMA 驱动（DmaDesc/DmaEngineRegs：dma_addr/dma_len）——**内置 DMA**，适合指定目标地址的批量加载
- **DMA 非必需**：方案 B 流式直写用 V1 即可；V2 才带 DMA（无需额外加 DMA 模块）
- 速度：SPI 50MHz ≈ 10MB/1.6s（vs UART 115200 的 15min，快 ~500 倍）
- **依赖**：加载到 DDR 需 T027（先验证 TCM/SRAM 通路）
- **启动对比**：模式 A（板载 flash W25Q32FV）有 4MB 限制，模式 B 无——选方案 B

## 工作清单

### ① 硬件连接（host↔板）
| 项 | 内容 |
| --- | --- |
| SPI 线 | SCLK、MOSI、MISO、CS + GND（4 线） |
| 电平 | 3.3V（FPGA I/O） |
| host 端 | USB-SPI 适配器（FT2232H/FTDI）或 GPIO-SPI |
| 板侧引脚 | **查 DualV7 原理图/管脚对应表**（spim_* 引脚位置） |

### ② 接入（fork/主仓库）
- CrossbarConfig：恢复 `spi2tlul`（HostConfig）+ `spi_master`/`spi_master_flash`（DeviceConfig）+ connections（spi2tlul → coralnpu_device/sram/...）
- **选版本**：方案 B 流式 → **V1（Spi2TLUL 纯桥）**；需指定目标地址批量加载 → V2（含 DMA）
- top：spi2tlul 桥 + chip_nexus SPI 端口（spim_sclk_o/spim_csb_o/spim_mosi_o/spim_miso_i）
- **可选**：spi2tlul → ddr_mem（大用例，依赖 T027）

### ③ host 软件
- SPI 流式加载器（读 ELF → SPI 发送 → spi2tlul 写内存）
- 与 bench_rvv.py 集成（加载替代 UART W 命令）

### ④ 验证
1. SPI 加载小程序到 TCM/SRAM（通路验证）
2. xsim：spi2tlul 写内存
3. 上板：SPI 加载 + 运行 + 回读
4. T027 完成后：大用例 SPI 加载到 DDR（15min → 秒级）

## 与 UART 对比
| | UART | SPI（方案 B） |
| --- | --- | --- |
| 容量 | 无限制 | 无限制 |
| 10MB | 15min | ~1.6s |
| 硬件 | 已有（M3） | 需新增 4 线 + host 适配器 |

## 完成区
**状态**：待开始
**Commit**：
**测试结果**：
**验收结果**：
**新发现/坑**：
**遗留问题**：
