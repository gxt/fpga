# §20 DualV7 XDC 约束设计决策

## 20.1 文件结构

DualV7 板级 XDC 分为以下文件，均位于 `board/dualv7/`：

| 文件 | 内容 |
|------|------|
| `top.xdc` | 系统时钟、复位 |
| `uart.xdc` | UART TX/RX（无流控） |
| `ethernet.xdc` | MII 网口 18 个信号 |
| `sdc.xdc` | 时序约束（待补充） |

---

## 20.2 TOP XDC（已定稿）

```tcl
# Clock Constraints 100MHz
set_property PACKAGE_PIN L4 [get_ports sys_diff_clock_clk_p]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports sys_diff_clock_clk_p]
set_property PACKAGE_PIN L3 [get_ports sys_diff_clock_clk_n]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports sys_diff_clock_clk_n]

create_clock -period 10 -name pclk1_p [get_ports sys_diff_clock_clk_p]

# Reset Constraints
# SW1 (AP31) is Active Low
set_property PACKAGE_PIN AP31 [get_ports reset]
set_property IOSTANDARD LVCMOS18 [get_ports reset]
set_property PULLUP TRUE [get_ports reset]
```

**理由**：
- 时钟 DIFF_HSTL_II_18：S2C 板 LVDS 时钟使用 1.8V bank
- 复位 PULLUP TRUE：确保未按时 reset=1（非复位状态），SW1 active-low

去掉内容：vc707 的 Cooling Fan 信号（DualV7 无此信号）

---

## 20.3 UART XDC 设计决策

- **去掉 CTS/RTS**：USB-UART 桥（CP210x/CH340 等）不稳定支持硬件流控，去掉避免悬空引脚干扰
- 只保留 TX/RX 两个信号
- 已确认 DualV7 当前 UART 顶层沿用 `rs232_uart` 接口展开端口名：
  - `rs232_uart_txd` -> `AU42`
  - `rs232_uart_rxd` -> `AV42`
- vc707 有 `rs232_uart_ctsn` / `rs232_uart_rtsn`，DualV7 不保留。

---

## 20.4 Ethernet XDC（MII 接口，已定稿）

IO standard：全部 LVCMOS18

| 信号 | 引脚 | 方向 |
|------|------|------|
| mii_tx_en | AU27 | OUT |
| mii_txd[0] | BA25 | OUT |
| mii_txd[1] | AY25 | OUT |
| mii_txd[2] | BB27 | OUT |
| mii_txd[3] | BB26 | OUT |
| phy_tx_clk | AR26 | IN（PHY 提供 25MHz） |
| phy_rx_clk | AT23 | IN（PHY 提供 25MHz） |
| mii_rx_dv | AU25 | IN |
| mii_rx_er | BC28 | IN |
| mii_rxd[0] | AT25 | IN |
| mii_rxd[1] | AR25 | IN |
| mii_rxd[2] | AY27 | IN |
| mii_rxd[3] | AY26 | IN |
| mii_crs | BA24 | IN |
| mii_col | BB25 | IN |
| mii_mdio | AP23 | INOUT |
| mii_mdc | AL23 | OUT |
| phy_rst_n | BA18 | OUT |

**接口选择理由**：
- MII 优于 RMII：TX/RX 时钟 25MHz（RMII 需 50MHz），时序裕量更大
- KSZ8081MNX 同时支持 MII 和 RMII，MII 模式通过 PHY strapping 引脚选择
- vc707 使用 RMII；DualV7 改为 MII，端口名需在顶层 wrapper 对齐

**待确认**：
- 已确认 vc707 不是 RMII，而是 SGMII + GMII MAC wrapper。
- DualV7 使用 MII wrapper，`eth_mac_1g_fifo` 的 `rx_mii_select` 和
  `tx_mii_select` 均为 `1'b1`。
- 当前 DualV7 BD 顶层仍保留 upstream MDIO 端口名：
  - `eth_mdio_data` 语义等价 `mii_mdio`
  - `eth_mdio_clock` 语义等价 `mii_mdc`
  - `eth_mdio_reset` 语义等价 `phy_rst_n`
- 若 XDC 改用 `mii_mdio` / `mii_mdc` / `phy_rst_n`，必须同步修改
  `board/dualv7/riscv-2025.1.tcl` 顶层端口名，否则不能综合。

---

## 20.5 参考文件位置（远端）

- vc707 参考：`/home/zzx/vivado-risc-v/board/vc707/*.xdc`
- DualV7 现有：`/home/zzx/vivado-risc-v/board/dualv7/*.xdc`
- 以太网顶层：`/home/zzx/vivado-risc-v/ethernet/ethernet.v`

---

## 20.6 001x 调研结论

当前远端 DualV7 XDC 的关键差距：

- `top.xdc` 仍含 bitstream 配置、LED 约束，且时钟 IOSTANDARD 为 `LVDS`；
  任务定稿版本要求只保留 100MHz clock/reset，并使用
  `DIFF_HSTL_II_18`。
- `top.xdc` reset 当前使用 `PULLTYPE PULLUP`；任务定稿版本使用
  `PULLUP TRUE`。
- `uart.xdc` 已符合 DualV7 需求，只含 TX/RX，无 CTS/RTS。
- `ethernet.xdc` 当前 CRS/COL 引脚与定稿表相反：
  `mii_crs` 应为 `BA24`，`mii_col` 应为 `BB25`。
- `ethernet.xdc` 当前 MDIO/Reset 端口名匹配现有 BD：
  `eth_mdio_data` / `eth_mdio_clock` / `eth_mdio_reset`。
  这与任务表中的语义名不同，但对当前远端工程是可综合写法。
