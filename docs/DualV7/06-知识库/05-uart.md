# §05 UART

## §05.1 DualV7 UART 引脚与串口设备

- UART0 TX: FPGA `AU42` → J8-48 → USB-UART (CH341) TX（UART0SOUT）
- UART0 RX: FPGA `AV42` ← J8-46 → USB-UART (CH341) RX（UART0SIN）
- IO standard: `LVCMOS18`
- 串口设备: **`/dev/ttyUSB2`**, 115200 8N1
- **⚠️ 032x 验证结论**：FPGA UART 在 CH341 (`/dev/ttyUSB2`)，不是 Digilent JTAG-SMT2 (`ttyUSB1`)。
  - `ttyUSB1` = Digilent JTAG-SMT2 Channel B（FTDI FT2232），032x 确认无 FPGA 数据
  - `ttyUSB2` = CH341 USB-UART（VID:1a86 PID:5523），032x 确认收到 BootROM 日志
- Symlink: `/dev/serial/by-id/usb-1a86_5523-if00-port0 → ../../ttyUSB2`
- 流控引脚 CTS/RTS 无板级物理连接（CH341 不支持硬件流控）

## §05.2 vivado-risc-v UART 实现

### RTL

- 源文件: `uart/uart.v`（328 行），模块名 `uart`
- 总线接口: AXI4-Lite（16-bit 地址，32-bit 数据）
- 时钟: 100MHz（`clock_100MHz`）
- 波特率: 硬编码 `BAUD_RATE = 115200`，prescaler = 100000000/115200 - 1 ≈ 867

### 寄存器映射

| 偏移 | 读写 | 描述 |
|------|------|------|
| 0x00 | R | RX FIFO 数据 `[7:0]` |
| 0x04 | W | TX FIFO 数据 `[7:0]`，`[8]`=xon_xoff |
| 0x08 | R | STATUS `[4:0]` = {!CTSn, tx_full, tx_empty, rx_full, !rx_empty} |
| 0x0C | R/W | CONTROL `[6:4]`={tx_stop, irq_enable[1:0]}，`[1:0]`=flush TX/RX |

- TX FIFO: 16-deep（4-bit 指针）
- RX FIFO: 16-deep
- STATUS[3] = tx_full（写入前需轮询）

### 端口

| 端口 | 方向 | BD 名 | 引脚 | 说明 |
|------|------|-------|------|------|
| TxD | OUT | `rs232_uart_txd` | AU42 | UART 发送 |
| RxD | IN | `rs232_uart_rxd` | AV42 | UART 接收 |
| RTSn | OUT | `rs232_uart_rtsn` | 无约束 | 硬件流控（未使用） |
| CTSn | IN | `rs232_uart_ctsn` | 无约束 → xlconstant=0 | 硬件流控（拉低 bypass） |

### Vivado 集成

- BD 中 `IO/UART` 为 module reference（非 IP），通过 `io_axi_s/M00_AXI` 连接
- 地址段: `0x60010000`，映射到 `RocketChip/IO_AXI4`
- 中断: `UART/interrupt` → `xlconcat_0/In0` → 软件 IRQ 1
- XDC: 仅约束 TX/RX，无 CTS/RTS

### 已知问题

- **CTS floating (021x)**：浮空 CTSn 可能保持高电平 → TX 状态机永久阻塞
- **022x 修复**：用 `xlconstant` 将 `IO/UART/CTSn` 拉到 0，不修改共享 `uart.v`
- **022x 状态**：TCL 已修复，但 bitstream 未重建/未上板验证

### Device Tree

```
uart@60010000 {
    compatible = "riscv,axi-uart-1.0";
    reg = <0x60010000 0x10000>;
    port-number = <0>;
};
```

## §05.3 Chipyard 旧 UART 实现

### RTL 来源

- SiFive UART（`sifive.blocks.devices.uart`），Chisel 生成
- 路径: `chiptop/system/uartClockDomainWrapper/uart_0`
- 配置: `WithDefaultPeripherals` → `UARTParams(address = 0x64000000L)`

### 总线

- TileLink-UL（连接在 CBUS 外设总线）
- 所有 Chipyard 外设（UART/SPI/GPIO）共享 CBUS

### 寄存器映射（SiFive 标准）

| 偏移 | 读写 | 描述 |
|------|------|------|
| 0x00 | W | txdata `[7:0]`=data, `[31]`=full |
| 0x04 | R | rxdata `[7:0]`=data, `[31]`=empty |
| 0x08 | R/W | txctrl `[0]`=txen, `[1]`=nstop |
| 0x0C | R/W | rxctrl `[0]`=rxen |
| 0x10 | R/W | ie（中断使能） |
| 0x14 | R | ip（中断挂起） |
| 0x18 | R/W | div `[15:0]`，baud = f_clk/(div+1) |

- 波特率: 软件控制，115200@10MHz → div=86
- TX FIFO: 8-deep

### 端口

| 端口 | 方向 | 顶层名 | 引脚 |
|------|------|--------|------|
| txd | OUT | `uart_txd` | AU42 |
| rxd | IN | `uart_rxd` | AV42 |
| CTS/RTS | 无 | 不存在 |

### Harness 绑定

`WithDualV7UARTBinder` 直接将 SoC `UARTPortIO` 连接到 TestHarness I/O:
```scala
th.uart_txd := ports.head.txd
ports.head.rxd := th.uart_rxd
```
无 CTS/RTS 参与，无手动 BD IPI。

### 时钟

- SoC 主时钟 10MHz（MMCM CLKOUT1，WithFPGAFrequency(10)）
- UART clock 与 SoC 同频，无独立分频

### Device Tree

```
uart@64000000 {
    compatible = "sifive,uart0", "sifive,serial";
    reg = <0x64000000 0x1000>;
};
```

## §05.4 验证证据

Chipyard DualV7 UART 已在多个配置下通过上板验证（有 UART 日志/串口输出）：

| Release | 配置 | 验证结果 | 证据 |
|---------|------|----------|------|
| RocketXIPTestConfig | SPI XIP + UART | ✅ PASS | MANIFEST: "UART 输出均正常" |
| SmallBoomXIPTestConfig | BOOM + SPI + UART | ✅ PASS | MANIFEST: "UART 输出均正常" |
| DDR3RomConfig | DDR3 + BRAM ROM | ✅ PASS | MANIFEST: "串口正常输出 DDR3 test / CALIB OK / DDR3 PASS" |
| DDR3FlashTest | DDR3 + SPI XIP | ✅ PASS | MANIFEST: "串口正常输出... DDR3 PASS" |

## §05.5 差异对比

| 维度 | vivado-risc-v 当前 | Chipyard 旧 |
|------|--------------------|-------------|
| RTL 来源 | 自定义 `uart.v` | SiFive TL-UART |
| 总线 | AXI4-Lite | TileLink |
| 地址 | `0x60010000` | `0x64000000` |
| 寄存器 map | 自定义（RX/TX/STATUS/CONTROL） | SiFive 标准 |
| TX full 检测 | `STATUS[3]` | `txdata[31]` |
| CTS/RTS | 有（CTS 经 xlconst 拉低） | 无 |
| 波特率控制 | RTL 硬编码 115200 | 软件 div 寄存器 |
| 时钟 | 100MHz | 10MHz |
| 端口名 | `rs232_uart_txd/rxd` | `uart_txd/rxd` |
| DTS compatible | `riscv,axi-uart-1.0` | `sifive,uart0` |
| Linux 驱动 | AXI UART driver（riscv,axi-uart-1.0） | sifive serial driver |
| Vivado 集成 | BD module reference + IPI | Chisel 生成 Verilog + XDC |
| 验证状态 | ✗ 无输出（CTS 修复后待测） | ✓ 多次上板通过 |

## §05.6 推荐方案

**推荐方案 A（继续修当前 UART）**：
- 022x 已修复 CTS floating → xlconstant=0
- 重建 bitstream 并上板验证
- 预期改动量: 0 文件（仅重建）
- 风险: 低（修复方式已被 `eth_mdio_int` 同类方案验证）
- 理由: 最小改动、最快验证、不引入新总线协议

详见 [023x 任务完成区](code-agent/tasks/023x-dualv7-uart-chipyard-compare.md)
