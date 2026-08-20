# DualV7 子卡网络 IP 方案报告

> 版本：v1.0
> 日期：2026-05-13
> 作者：deepseek（基于 §03/§04/027x/037x/038x 事实汇总）

---

## 1. 硬件约束前提（结论稳固，不可推翻）

### 1.1 PHY 芯片

| 参数 | 值 |
|------|-----|
| 型号 | **KSZ8081MNX**（Microchip/Micrel，32-QFN） |
| 接口 | **MII**（4-bit 数据，10/100Base-TX） |
| 不支持 | SGMII / RGMII / GMII / RMII（本板 strapping 固定为 MII） |
| PHY 地址 | **1**（PHYAD[2:0]=001，原理图 Sheet 13 实测） |
| PHY ID | `0x00221560`（OUI=0010A1h，Reg2=0x0022，Reg3=0x1560） |
| 中断 | INTRP **未引出到 FPGA**（009x 已用 xlconstant 0 替代） |
| 参考文档 | KSZ8081MNX-RNB Data Sheet v1.0.pdf |

### 1.2 MII 接口完整引脚（18 信号，全部已约束）

| 信号 | 方向 | FPGA 引脚 | IO Bank | IO Standard |
|------|------|-----------|---------|-------------|
| phy_tx_clk | IN | AR26 | - | LVCMOS18 |
| phy_rx_clk | IN | AT23 | - | LVCMOS18 |
| mii_txd[3:0] | OUT | BB26/BB27/AY25/BA25 | - | LVCMOS18 |
| mii_tx_en | OUT | AU27 | - | LVCMOS18 |
| mii_rxd[3:0] | IN | AY26/AY27/AR25/AT25 | - | LVCMOS18 |
| mii_rx_dv | IN | AU25 | - | LVCMOS18 |
| mii_rx_er | IN | BC28 | - | LVCMOS18 |
| mii_crs | IN | BA24 | - | LVCMOS18 |
| mii_col | IN | BB25 | - | LVCMOS18 |
| mii_mdio | INOUT | AP23 | - | LVCMOS18 |
| mii_mdc | OUT | AL23 | - | LVCMOS18 |
| phy_rst_n | OUT | BA18 | - | LVCMOS18 |

### 1.3 时钟与速率

- TX_CLK / RX_CLK：各 25 MHz（100Mbps 模式），由 **PHY 输出**
- MDC：~2.5 MHz（FPGA 内部生成）
- PHY 复位：RST# 低电平 ≥500μs（warm reset），BA18 直接驱动，无 RC 延迟

### 1.4 千兆升级可行性

**不存在**。KSZ8081MNX 是纯 10/100 Fast Ethernet PHY，无 SerDes 硬件，封装无高速差分引脚。若需千兆，唯一路径是**更换 PHY 芯片**（硬件改造）。vc707 的 SGMII 链路（gig_ethernet_pcs_pma + GTX）对 DualV7 完全不可用。

---

## 2. 当前方案状态

### 2.1 技术路径

```
ethernet.v (MDIO master)
  └── ethernet-dualv7.v (wrapper)
        └── eth_mac_1g_fifo (GMII MAC core)
              ├── axis_gmii_rx (mii_select=1 → MII nibble→byte)
              └── axis_gmii_tx (mii_select=1 → byte→MII nibble)
```

本质是 **GMII MAC 通过 mii_select 参数降级为 MII 适配**，非原生 MII MAC。

### 2.2 运行时验证结果（037x / 038x，2026-05）

| 层级 | 结果 | 详情 |
|------|------|------|
| FPGA 配置 | ✅ 通过 | `rocket64z2m`，WNS=-0.755ns |
| Boot ROM | ✅ 通过 | 可加载 OpenSBI |
| U-Boot 层 | ❌ 失败 | `Net: No ethernet found.` |
| U-Boot mii 命令 | ❌ 缺失 | MAC 未枚举，mii 子命令不可用 |
| Linux MDIO | ✅ 通过 | `libphy: axi-eth-mdio: probed`，PHY ID `0x00221560` ✅ |
| Linux netdev | ⚠️ 部分 | eth0 存在，驱动 `riscv-axi-eth` |
| Linux link | ❌ 失败 | operstate=down，carrier 返回 `invalid length` |
| Linux 流量 | ❌ 失败 | 0 RX / 0 TX（`/proc/net/dev`） |
| 203 对端 | ⚠️ 阻塞 | USB NIC 锁死在 100M/Half/autoneg off，无法修改 |

**结论**：`eth_mac_1g_fifo + mii_select=1` 在 DualV7 上运行时验证**未通过**。U-Boot 无法枚举 MAC，Linux 无法建立链路。203 对端锁死在 autoneg off 是加重因素，但不是唯一根因（U-Boot 驱动层面即失败）。

---

## 3. 候选 IP 方案总览矩阵

| # | 方案 | 来源 | 原生 MII | AXI 接口 | MDIO | 移植量 | 驱动成熟度 | 当前推荐 |
|---|------|------|----------|----------|------|--------|-----------|----------|
| 1 | eth_mac_mii_fifo | [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) 库 | ✅ 原生 4-bit | AXI-Stream | 复用 ethernet.v | **小** (~30行) | 高（同库验证） | **短期首选** |
| 2 | eth_mac_1g_fifo (当前) | [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) 库 | ⚠️ GMII 适配 | AXI-Stream | ethernet.v | 0 | 中（DualV7 未通过） | 不推荐继续 |
| 3 | Xilinx AXI Eth Subsystem | Vivado IP Catalog (PG138) | ✅ 原生 MII | AXI4 | ✅ 内置 | 中 | 高（主线驱动） | 中期备选 |
| 4 | Xilinx AXI Eth Lite | Vivado IP Catalog (PG135) | ❌ MII RX bug | AXI4 | 内置 | 中 | 低（已知缺陷） | **不推荐** |
| 5 | LiteEth | [LiteX liteeth](https://github.com/enjoy-digital/liteeth) | ✅ 原生 MII | ❌ Wishbone | ✅ 内置 | 大 | 中（Migen 链） | 不推荐 |
| 6 | ETHOC | [OpenCores ethmac](https://opencores.org/projects/ethmac) | ✅ 原生 MII | ❌ Wishbone | ❌ 无 | 大 | 低（极少验证） | 不推荐 |

---

## 4. 逐方案详细分析

### 4.1 方案 1：eth_mac_mii_fifo（短期推荐）

**来源**：verilog-ethernet 库（与当前 `eth_mac_1g_fifo` 同源）
**路径**：`lib/verilog-ethernet/rtl/eth_mac_mii_fifo.v`

| 维度 | 评估 |
|------|------|
| **来源** | [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) 库，位于 vivado-risc-v submodule `lib/verilog-ethernet/rtl/eth_mac_mii_fifo.v` |
| **硬件匹配** | ✅ 原生 MII 4-bit，完全匹配 KSZ8081MNX |
| **AXI 接口** | ✅ AXI-Stream（8-bit tdata/tkeep/tvalid/tready/tlast/tuser），**与当前完全兼容** |
| **MDIO** | ✅ 可完整保留 `ethernet.v` 中的 MDIO master（MDIO 独立于 MAC core） |
| **RTL 改动** | `ethernet-dualv7.v`：替换实例化（~30 行端口映射） |
| **TCL/BD 改动** | **无**（同源库，模块引用路径相同） |
| **XDC 改动** | **无**（引脚完全不变） |
| **DTS 改动** | **无**（同一 compatible: `riscv,axi-ethernet-1.0`） |
| **BootROM 改动** | **无**（同一驱动绑定） |
| **Linux 驱动** | `riscv-axi-eth`（已有，不变） |
| **U-Boot 驱动** | 同 `riscv,axi-ethernet-1.0`（不变） |
| **时钟** | phy_tx_clk / phy_rx_clk 25MHz（不变） |
| **复位** | phy_rst_n（不变） |
| **IOB 支持** | `mii_phy_if.v` 使用 IDDR 原语，7-series 需 `CLOCK_INPUT_STYLE="BUFR"` |
| **bring-up 风险** | **低**（同源库、同接口、已验证平台） |
| **调试复杂度** | **低**（无 GMII→MII 适配层，逻辑更简洁） |

**移植清单**（仅需修改 1 个文件）：
1. `ethernet-dualv7.v`：将 `eth_mac_1g_fifo` 替换为 `eth_mac_mii_fifo`，修改端口映射
2. 添加 `defparam` 或 parameter override：`CLOCK_INPUT_STYLE = "BUFR"`
3. 所有其他文件不变

**风险评估**：
- 同属 verilog-ethernet 库，接口层一致，移植风险极低
- 去除 GMII→MII 适配层（nibble 拆/拼逻辑），降低逻辑出错概率
- 唯一风险点：IDDR 时序约束需验证（可通过 ILA 快速确认）

### 4.2 方案 2：保留当前方案 eth_mac_1g_fifo（不推荐）

| 维度 | 评估 |
|------|------|
| **来源** | [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) 库，位于 vivado-risc-v submodule `lib/verilog-ethernet/rtl/eth_mac_1g_fifo.v` |
| **硬件匹配** | ⚠️ 非原生 MII，通过 GMII→MII nibble 适配（`mii_select=1` 参数降级 8-bit GMII → 4-bit MII） |
| **当前状态** | ❌ DualV7 runtime 验证未通过 |
| **问题定位难度** | **高**——需在 RTL 层定位 GMII→MII 适配 bug、U-Boot 驱动枚举失败、Linux link 建立失败，三个问题可能相互交织 |
| **继续投入风险** | 修改 GMII→MII 适配逻辑可能引入新问题；且 U-Boot 驱动本身兼容性存疑 |
| **适用场景** | 仅当方案 1 也阻塞时，作为回退调试基线 |

### 4.3 方案 3：Xilinx AXI Ethernet Subsystem（PG138）（中期备选）

| 维度 | 评估 |
|------|------|
| **来源** | Xilinx IP Catalog（PG138），Vivado 2025.1 内置 IP，路径 `IP Catalog → AXI Ethernet Subsystem` |
| **硬件匹配** | ✅ 支持 MII 模式 |
| **AXI 接口** | AXI4（Memory-Mapped），需通过 AXI DMA 或 AXI-Stream FIFO 转换为 RocketChip 所需的 AXI-Stream |
| **MDIO** | ✅ 内置 MDIO master |
| **RTL 改动** | 中——替换 `ethernet.v` + `ethernet-dualv7.v` 为 BD 中的 IP 实例 |
| **BD 改动** | 必须——需在 Vivado BD 中创建/配置 IP，连接 AXI 接口到 RocketChip IO bus |
| **TCL 改动** | 必须——需编写 IP 配置 TCL |
| **XDC 改动** | 小——引脚不变，但端口命名可能不同（需对齐 IP wrapper 端口名） |
| **DTS 改动** | 必须——compatible 改为 `xlnx,axi-ethernet-1.00.a` |
| **Linux 驱动** | `xilinx_axienet`（主线，成熟，含 MDIO 管理） |
| **U-Boot 驱动** | `xilinx_axi_emac`（主线 U-Boot 支持） |
| **时钟约束** | 需验证 IP 内部时钟生成逻辑（MII 模式通常使用 PHY 提供的 25MHz TX/RX clock） |
| **bring-up 风险** | **中**（新驱动栈、新 BD 连接、需验证 AXI4↔AXI-Stream 桥接） |
| **调试复杂度** | **中**（Xilinx 文档齐全，但 IP 配置参数多，AXI 桥可能引入额外延迟） |
| **历史坑** | 早期版本（≤2019.x）有 preamble/SFD RX bug；Vivado 2025.1 中需确认已修复 |

**适用场景**：若方案 1（eth_mac_mii_fifo）长期不稳定，或需要利用 Xilinx IP 的 DMA/checksum offload 等高级特性。

### 4.4 方案 4：Xilinx AXI Ethernet Lite（PG135）（不推荐）

| 维度 | 评估 |
|------|------|
| **来源** | Xilinx IP Catalog（PG135），Vivado 2025.1 内置 IP，路径 `IP Catalog → AXI EthernetLite` |
| **硬件匹配** | ❌ Chipyard 已验证 MII 模式下 RX bug（SFD 状态机不推进） |
| **Bug 状态** | VHDL 内部状态机缺陷，非 IO 层问题，Vivado 2025.1 是否修复不明确 |
| **推荐** | **强烈不推荐优先尝试**（已知缺陷，调试成本不可控） |

### 4.5 方案 5：LiteEth（不推荐）

| 维度 | 评估 |
|------|------|
| **来源** | [LiteX 生态](https://github.com/enjoy-digital/liteeth)，Migen（Python）构建链，非标准 Verilog IP |
| **硬件匹配** | ✅ 原生 MII，7-series 已验证（Arty A7 等） |
| **构建链** | ❌ Python/Migen 构建链，与 Vivado BD TCL 流**不兼容** |
| **接口** | ❌ Wishbone，需 Wishbone→AXI4 桥接 |
| **移植量** | **大**（需重构整个 Ethernet 构建链路） |
| **驱动** | `litex_liteeth`（主线 5.11+），但需配套 LiteX 设备树生成 |
| **推荐** | 不推荐（构建链不兼容，移植代价远超收益） |

### 4.6 方案 6：ETHOC / OpenCores（不推荐）

| 维度 | 评估 |
|------|------|
| **来源** | [OpenCores](https://opencores.org/projects/ethmac) 开源项目，Wishbone 总线接口 |
| **硬件匹配** | ✅ 支持 MII |
| **接口** | ❌ Wishbone B3 |
| **MDIO** | ❌ 无 MDIO master（需自行实现） |
| **RISC-V 验证** | ⚠️ 极少（主要 OpenRISC 生态） |
| **移植量** | **大**（Wishbone 适配 + MDIO 实现 + DTS 定制） |
| **推荐** | 不推荐（缺少 MDIO、生态薄弱、移植代价高） |

---

## 5. 当前工程改动面分析

### 5.1 只改一个 wrapper 就能试的方案

**仅方案 1（eth_mac_mii_fifo）**：
- 修改文件：`ethernet-dualv7.v`（~30 行）
- 其余 TCL / BD / XDC / DTS / BootROM / Linux / U-Boot **全部不变**

### 5.2 会牵动驱动、设备树或 BD 结构的方案

**方案 3（Xilinx AXI Eth Subsystem）**：
- 需要修改/新增：BD 中 IP 实例化、TCL IP 配置
- 需要修改：DTS（compatible string 变更）
- 可能需要：AXI-Stream FIFO / AXI DMA 桥接
- 驱动变更：`riscv-axi-eth` → `xilinx_axienet`

**方案 4/5/6**：均需要驱动/设备树/BD 大幅改动。

### 5.3 理论可行但对当前项目不划算的方案

- **方案 4**（AXI Eth Lite）：已知 MII RX bug，调试风险不可控
- **方案 5**（LiteEth）：Migen 构建链与 Vivado BD 不兼容
- **方案 6**（ETHOC）：无 MDIO master，RISC-V 验证极少

---

## 6. 分阶段推荐

### 6.1 短期建议（最小改动，验证网络可用性）

**推荐方案：eth_mac_mii_fifo（方案 1）**

理由：
1. **最小改动面**：仅修改 1 个 Verilog 文件（`ethernet-dualv7.v`），约 30 行
2. **接口完全兼容**：AXI-Stream + MDIO 不变，DTS/BootROM/驱动不变
3. **同源库验证**：与当前 `eth_mac_1g_fifo` 同属 verilog-ethernet 库，已在多块 FPGA 板上验证
4. **逻辑更简洁**：去除 GMII→MII nibble 适配层，消除潜在 bug 源
5. **可快速综合**：改动小，综合时间与当前方案相当

实施步骤：
1. 修改 `ethernet-dualv7.v`：替换实例化 + 添加 `CLOCK_INPUT_STYLE = "BUFR"`
2. 综合 + 生成 bitstream
3. 上板验证：U-Boot `mii info` / `dhcp` / Linux `eth0` link
4. 若成功，直接使用；若失败，方案 3 作为中期备选

### 6.2 中期建议（稳定运行与可维护性）

**推荐方案：Xilinx AXI Ethernet Subsystem（方案 3）**

适用条件：
- 方案 1（eth_mac_mii_fifo）长期运行出现稳定性问题
- 或需要利用 Xilinx IP 的高级特性（DMA、checksum offload、interrupt coalescing）

理由：
1. 驱动成熟：`xilinx_axienet` 为主线驱动，长期维护
2. 功能完整：内置 MDIO、DMA、中断管理
3. 生态支持：Xilinx 官方文档 + 社区验证

代价：
- 需修改 BD 结构（IP 实例化 + AXI 连接）
- 需修改 DTS
- IP 配置学习曲线（AXI DMA mode、FIFO depth、checksum config 等）

### 6.3 不建议路线

| 方案 | 不建议原因 |
|------|-----------|
| 保留当前 `eth_mac_1g_fifo` | runtime 已验证失败，继续调试 ROI 低 |
| AXI Ethernet Lite | 已知 MII RX bug（SFD 状态机），Vivado 2025.1 修复状态不明确 |
| LiteEth | Migen 构建链与 Vivado BD 不兼容 |
| ETHOC | 无 MDIO master，RISC-V 验证极少，移植代价高 |

---

## 7. 补充说明

### 7.1 关于 203 对端问题

038x 发现 203 端 USB 网卡锁死在 100M/Half/autoneg off，且不支持 ethtool 修改。这是加重因素，但不是当前方案失败的唯一原因——U-Boot 驱动层面即已枚举失败，发生在对端配置之前。

切换到方案 1 后，若 link 仍无法建立，需优先排除 203 对端问题：
- 更换支持 autoneg 的对端网卡
- 或使用交换机（带 autoneg）中继

### 7.2 关于 U-Boot 驱动兼容性

038x 证实 U-Boot 2021.07 的 `riscv,axi-ethernet-1.0` 驱动在 `rocket64z2m` 上枚举失败。切换到方案 1 后需重新验证 U-Boot 驱动是否能正确识别原生 MII MAC——方案 1 的 MAC 对 U-Boot 驱动透明（同一 compatible），但如果 U-Boot 驱动的 Probe 逻辑依赖某些 GMII-specific 寄存器或特性，可能仍需排查。

### 7.3 关于 verilog-ethernet 库在 Vivado 2025.1 中的综合

verilog-ethernet 库大量使用 SystemVerilog 特性（interface、struct 等），当前工程已证明可在 Vivado 2025.1 中综合（当前 `eth_mac_1g_fifo` 即来自该库）。方案 1 的 `eth_mac_mii_fifo` 使用相同的 SystemVerilog 子集，综合兼容性无问题。

参考：
- 027x MII MAC IP 调研（§04.6）
- 037x Mega 以太网运行时调试
- 038x Mega 以太网 U-Boot 分层补测
- §03.4 PHY 引脚表
- §04.7 运行时验证结论
- §20.4 Ethernet XDC 约束
