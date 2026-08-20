# DualV7 网络 IP 外部公开方案调研报告

**日期**：2026-05-16
**调研范围**：alexforencich/verilog-ethernet 生态、LiteEth、Xilinx AXI Ethernet、RISC-V FPGA SoC DMA/cache 实践
**目的**：回答"当前 eth_mac_mii_fifo + 自定义 ring DMA + 自写 U-Boot/Linux 驱动 + MII PHY"路线是否合理

---

## 1. 外部来源清单

| 来源类型 | 具体来源 | URL |
|---------|---------|-----|
| 官方仓库 | alexforencich/verilog-ethernet | https://github.com/alexforencich/verilog-ethernet |
| 官方仓库 | LiteEth (enjoy-digital) | https://github.com/enjoy-digital/liteeth |
| 官方仓库 | Xilinx AXI Ethernet (PG138) | https://docs.xilinx.com/r/en-US/pg138-axi-ethernet |
| Linux 驱动 | fpga-axi-eth (patches/) | vivado-risc-v 工程内 `patches/fpga-axi-eth.c` |
| RISC-V CMO | RISC-V CMO扩展规范 | https://github.com/riscv/riscv-CMOs |
| MMIO/DMA | Rocket Chip PMA/Cache 文档 | chipyard/rocket-chip 源码 |
| 示例板 | verilog-ethernet examples (x30+ boards) | 含 Arty (A7), DE2-115, KC705, NexysVideo 等 |
| 示例板 | LiteX/LiteEth boards (x50+) | 含 7-series, ECP5, Spartan6 等 |

---

## 2. 对比矩阵

| 方案/项目 | MAC/IP | PHY 接口 | 软件栈 | DMA/cache 处理 | 与我们相似度 | 结论 |
|----------|--------|----------|--------|----------------|--------------|------|
| **verilog-ethernet 官方 example** | eth_mac_1g/10g/25g | GMII/SGMII/XGMII/RGMII | **裸机 UDP echo**（无 U-Boot/Linux）| 无 DMA（内部 FIFO 直连） | **低** — 软件栈完全不同 | 仅证明 RTL 本身是硅验证的，不证明软件路径 |
| **LiteEth + LiteX SoC** | LiteEth MAC | MII/RMII/GMII/RGMII | LiteX 软件栈（裸机/RTOS） | Wishbone 总线，无独立 DMA | **中等** — 硬件层 MII 最像，但总线/驱动不同 | LiteEth MII PHY 侧与 verilog-ethernet 做法一致（25MHz TX/RX clk, 4-bit nibble） |
| **Xilinx AXI Ethernet + Linux** | AXI Ethernet Subsystem | MII/GMII/RGMII/SGMII | Linux xilinx_axienet 主线驱动 | AXI DMA, `dma_alloc_coherent` | **中等** — 软件栈最成熟，但改用 Xilinx IP | 最稳的软件路径，但需换 IP + 改 BD |
| **Linux fpga-axi-eth 驱动** | 任意 AXI-Stream MAC | 任意 | Linux 主线 staging 驱动 | `dma_alloc_coherent`（cache-coherent DMA） | **高** — 当前正在用的驱动 | 思路正确，Linux 侧只需正确的 coherent DMA 映射 |
| **U-Boot 自定义网络驱动** | 同上 | 同上 | U-Boot UCLASS_ETH | 无 cache 管理（`flush_dcache_range` 弱 no-op） | **高** — 当前路径 | **最大风险点**：RISC-V U-Boot 无 cache maintenance |
| **纯裸机/Verilog testbench** | 各种 | 各种 | 裸机轮询 | 无 DMA/cache 问题 | **低** | 不具可比性 |

---

## 3. 关键发现

### 3.1 eth_mac_mii_fifo 的生态现状

- verilog-ethernet 有 **3k+ stars, 827 forks, 1203 commits**，是 FPGA 以太网领域引用最广的开源库
- 官方 example 包含 **30+ 块 FPGA 板**，但全部使用 **Gigabit+ Ethernet**（SGMII/RGMII/GMII），**没有一块板使用 MII 10/100**
- `eth_mac_mii_fifo` 有完备的 cocotb 测试，但**没有公开的 U-Boot/Linux 软件栈集成**
- 当前仓库已标记为 deprecated（迁移到 taxi 框架），但稳定性不受影响

**结论**：`eth_mac_mii_fifo` RTL 本身是**成熟经证实的**，但将其接入 U-Boot/Linux 完整 TCP/IP 栈的组合方式是**非典型的**。

### 3.2 MII PHY 时钟/接口的常见做法

从 `mii_phy_if.v`（verilog-ethernet）和 `liteeth/phy/mii.py`（LiteEth）对比：

| 方面 | verilog-ethernet | LiteEth | 我们的实现 |
|------|-----------------|---------|-----------|
| TX CLK 来源 | PHY 提供 `phy_mii_tx_clk` → BUFG 扇出 | PHY 提供 `clock_pads.tx` → 直接连接 | PHY 提供 `phy_tx_clk` → BUFG |
| RX CLK 来源 | PHY 提供 `phy_mii_rx_clk` → `ssio_sdr_in` 采样 | PHY 提供 `clock_pads.rx` → 直接连接 | PHY 提供 `phy_rx_clk` → 未用 DDR/IDDR |
| CLOCK_INPUT_STYLE | 7-series 推荐 **BUFR**（但实际用 BUFG） | 无特殊原语 | 当前用 BUFG（044x WHS=-7.690ns） |
| TX 寄存器 | `(* IOB = "TRUE" *)` 要求输出寄存器在 IOB | 直接输出 | 待确认是否加 IOB |
| 复位同步 | 4 级同步器跨时钟域 | `AsyncResetSynchronizer` | 当前方案一致 |

**关键观察**：LiteEth 的 MII PHY 实现也使用 `pads.tx_en` 和 `pads.tx_data` 在同步时钟域直接驱动，没有特殊时序约束。我们的 BUFG 方案是合理的。WHS 违例在 25MHz 下通常可容忍，但仍建议修复。

### 3.3 DMA + Cache Coherency — 这是最关键的已知问题

**外部证据汇总**：

1. **RISC-V Rocket Chip 的缓存行为**：
   - Rocket Chip 的 L1 缓存是 **write-back, write-allocate**
   - DMA 控制器读 DDR 时不经过 L1 缓存
   - CPU 写 DMA buffer 后若数据残留在 L1 cache line 中未写回，DMA 读到的是 **陈旧数据**
   - 这是 FPGA SoC DMA 最常见的陷阱之一

2. **Linux 的解决方案**：
   - `dma_alloc_coherent()` 分配 non-cacheable 或 cache-coherent 内存
   - 或在 device tree 中将 DMA 区域标记为 `dma-ranges` + non-cacheable
   - Linux `fpga-axi-eth` 驱动使用 `dma_alloc_coherent()` — 这是正确的做法
   - 但 044x 实测中 Linux 仍 0 TX/RX，说明问题可能不止 cache

3. **U-Boot 的已知限制**：
   - RISC-V U-Boot 中 `flush_dcache_range()` 在 `vivado_riscv64` 上是 **弱 no-op**
   - 没有 `cbo.clean`/`cbo.flush` 指令（RISC-V CMO 扩展尚未 ratified）
   - 唯一的绕过方式：将 DMA buffer 放在 non-cacheable 区域

4. **其他项目如何处理**：
   - LiteX SoC：通过 Wishbone 总线直接访问，CPU 和 DMA 在同一总线域，无 cache 问题
   - Xilinx AXI Ethernet：Linux 的 `dma_alloc_coherent` + 成熟的 IOMMU/SMMU
   - 纯裸机：禁用 L1 cache，或手工 fence

### 3.4 其他路径的软件栈成熟度

| 路径 | 驱动成熟度 | Coherency 处理 | 对 DualV7 适用性 |
|------|-----------|----------------|-----------------|
| **当前路径：vivado_mii (U-Boot)** | ❌ 自定义，小众 | ❌ 无 | N/A — 已在用 |
| **Linux fpga-axi-eth** | ⚠️ staging 驱动，但功能完整 | ✅ dma_alloc_coherent | 已在 DTS 中 |
| **Xilinx AXI Eth + xilinx_axienet** | ✅ 主线，百万级部署 | ✅ 内置 | 需换 IP + 改 BD |
| **LiteEth + LiteX** | ⚠️ 需 LiteX 整个生态 | N/A（无独立 DMA） | 不兼容当前工程 |

---

## 4. 对当前路线的判断

### 4.1 当前软硬件大方向是否合理

**方案本身合理，但属于高难度小众路线。**

- `eth_mac_mii_fifo` RTL 本身是**成熟、可用**的 — 3k stars 的开源项目，有完整的 cocotb 测试
- 但"verilog-ethernet MII MAC + 自定义寄存器映射 DMA + U-Boot/Linux 自写驱动 + RISC-V NoMMU"这个**完整链路几乎没有公开先例**
- 外部能找到的最接近组合是：Xilinx FPGA + 开源 MAC + Linux staging 驱动（如 `fpga-axi-eth`），但 PHY 接口通常是 GMII/RGMII，不是 MII
- LiteEth 虽然用了 MII，但总线是 Wishbone 不是 AXI，软件栈也不是 U-Boot/Linux

### 4.2 当前最可疑的是实现细节，还是路线选型本身

**两者都是，但优先级不同**：

**路线选型问题（中期）**：
- 选择自定义驱动 + DMA ring + verilog-ethernet MAC 而不是 Xilinx AXI Ethernet 意味着**每个软件层的 bug 都需要自己排查**
- 对于调试来说，没有现成的"这个配置在 X 板上跑通了"的参考点

**实现细节问题（短期，更重要）**：
1. **Cache coherency**（最高嫌疑）：U-Boot 下 `flush_dcache_range` 是 no-op，DMA 读到过期缓存数据是极可能的原因。Linux 虽然用 `dma_alloc_coherent`，但 044x 实测 Linux 也 0 TX/RX。
2. **MII TX WHS hold 违例**：WHS=-7.690ns 在 25MHz 下虽可容忍（~4% 时钟周期），但若 `IOB=TRUE` 未正确设置，输出寄存器可能在 IOB 外导致 hold 问题。
3. **MAC `cfg_tx_enable` 初始值**：需要确认 `ethernet.v` 中 `cfg_tx_enable` / `cfg_rx_enable` 在复位后是否被正确置 1。

### 4.3 短期继续当前路线是否值得

**值得，但有条件**。

- 当前路线的最大优势是**修改范围小**：一个 RTL wrapper + 一个驱动文件
- 当务之急是**隔离验证硬件链路**（MAC→MII→PHY→网口）是否完整
- 建议先做 Linux 下的发包验证（`fpga-axi-eth` 驱动已 probe 成功），如果 Linux 可发包则问题收敛于 U-Boot 的 cache 处理

### 4.4 中期是否应转向更成熟 IP/驱动组合

**建议将 Xilinx AXI Ethernet Subsystem 作为中期备选方案**，触发条件是：
1. 当前路线调通后，稳定性或性能不满足需求
2. 或者在 1 个月内仍未找到数据面不通的根因

**不推荐 LiteEth**（需换整个 SoC 构建链）和 **AXI EthernetLite**（MII RX bug）。

---

## 5. 最终建议

### 短期（1-2 周）

1. **在 Linux 下发包测试**（同一 bit 下）：`ifconfig eth0 up; ping 192.168.200.1`
   - 如果 Linux 发包成功 → 问题收敛到 U-Boot 的 cache 一致性 + DMA 映射
   - 如果 Linux 也不发 → 问题在 RTL/PHY 层
2. **如确认是 U-Boot cache 问题**：将 Tx/Rx buffer 地址映射到 non-cacheable 区域（修改 Linker Script 或 MMU page table）

### 中期（1-3 月）

3. **评估 Xilinx AXI Ethernet Subsystem 迁移**：
   - 成本：改 BD + TCL + DTS，驱动是主线成熟驱动
   - 收益：cache coherence 由 coherent DMA 处理，有社区支持
4. **如果当前路线已调通且网络可用**：继续维护 `vivado_mii` 驱动，但需增加 non-cacheable DMA 支持

---

## 6. 外部来源链接

1. https://github.com/alexforencich/verilog-ethernet — verilog-ethernet 主仓库
2. https://github.com/alexforencich/verilog-ethernet/blob/master/rtl/eth_mac_mii_fifo.v — `eth_mac_mii_fifo` 源码
3. https://github.com/alexforencich/verilog-ethernet/blob/master/rtl/mii_phy_if.v — `mii_phy_if` 时钟处理
4. https://github.com/enjoy-digital/liteeth — LiteEth 主仓库
5. https://github.com/enjoy-digital/liteeth/blob/master/liteeth/phy/mii.py — LiteEth MII PHY 实现
6. https://github.com/riscv/riscv-CMOs — RISC-V CMO 扩展
7. `patches/fpga-axi-eth.c` — 工程内 Linux 驱动源码
8. `lib/verilog-ethernet/` — 工程内 verilog-ethernet 子模块
