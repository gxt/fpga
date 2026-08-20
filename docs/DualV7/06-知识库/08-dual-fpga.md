# §08 DualV7 双 FPGA 架构

## §08.1 板卡双 FPGA 硬件事实

> 来源：`Dual V7 Hardware Reference Manual v1.08`（89 页，2016-05-24）

### §08.1.1 芯片

- 板卡：S2C Dual Virtex-7 TAI Logic Module
- 两片 Xilinx Virtex-7 **XC7V2000T**（FLG1925 封装）
- 标称 F1（FPGA1）和 F2（FPGA2）

### §08.1.2 Dedicated I/O

- 每片 FPGA：**360 条** Dedicated I/O
- F1 专用连接器：**J8、J9、J10**（Samtec QTH-120 × 3）
- F2 专用连接器：**J3、J4、J5**（Samtec QTH-120 × 3）
- IO 电压：软件可调 1.2V / 1.5V / 1.8V
- 电源区域：
  - J8 和 J5 各为独立电源区域
  - J9+J10 共享一个电源区域
  - J3+J4 共享一个电源区域

### §08.1.3 Shared I/O

- **480 条** Shared I/O，同时连接到 F1 和 F2
- 引出到 J2/J6/J7/J12 连接器
- 电压固定 **1.8V**，不可软件调整

### §08.1.4 Inter-FPGA 直连

- **50 条** Inter-FPGA 连线，F1 ↔ F2 直接 PCB 走线
- 电压固定 **1.8V**
- 官方推荐 **LVDS** 电平（"for higher performance"）
- 引脚对应表：HW Manual §9.3 Table 8-5（需手工从 PDF 提取）

### §08.1.5 全局时钟

- 14 条全局时钟（MRCC），同时分布到 F1 和 F2
- 来源：
  - 6 对可编程差分时钟（0.16~710MHz）
  - 6 对 SMB 差分时钟输入
  - 2 个单端晶振座
- 6 对反馈差分时钟（来自用户 FPGA）
- s2cclk_1（当前使用）：F1.L4(P)/L3(N) = F2.N4(P)/N3(N)

### §08.1.6 GTX Transceiver

- 每片 FPGA：**16 条** GTX
- 共计 32 条 GTX
- 各自独立，非共享

### §08.1.7 存储

- DDR3 SO-DIMM：J14 插槽（容量 1/2/4/8GB）
- DDR2 SO-DIMM：J12 相关（待确认）

### §08.1.8 配置链

- 4 种配置方式：USB 线缆、SD 卡、以太网、SPI Flash
- F1_DONE / F2_DONE 各有独立 LED 指示
- JTAG 链拓扑待确认（单链串联两片 vs 双链独立）

## §08.2 当前工程现状

### §08.2.1 FPGA 命中

- **当前工程仅使用 FPGA1（F1）**
- `Makefile.inc`：`XILINX_PART = xc7v2000tflg1925-1`（单 part）
- `top.xdc` 时钟引脚 L4/L3 = F1 的 s2cclk_1
- 所有外设引脚（UART/ETH/SD/LED/DDR3）均连接 F1

### §08.2.2 现有外设与 F1 连接器对应

| 外设 | F1 连接器 | F1 引脚 |
|------|----------|---------|
| 时钟 s2cclk_1 | 全局时钟 | L4(P)/L3(N) |
| 复位 SW1 | J9-2 | AP31 |
| LED0-2 | J8-101/103/105 | AH44/AH43/AL40 |
| UART0 | J8-46/48 | AV42/AU42 |
| ETH MII | J9 多个 | AU27/BA25/... |
| SD MMC1 | J8 多个 | AT37/AT38/BA43/... |
| DDR3 SO-DIMM | J14 | Bank 17+19 |

### §08.2.3 FPGA2 工程状态

- **无任何 FPGA2 工程文件、XDC、TCL、bit**
- 远端 `board/` 仅有 `board/dualv7/`（单板目录）
- `fpga2` / `FPGA2` 搜索零命中
- 无 F2 引脚约束记录

## §08.3 缺失关键信息

| # | 信息 | 来源 | 影响 |
|---|------|------|------|
| 1 | Inter-FPGA 50 条引脚 F1↔F2 对应表 | HW Manual §9.3 Table 8-5 | 阻塞方案 B/C |
| 2 | F2 连接器 J3/J4/J5 管脚定义 | 需从 S2C 获取 xlsx/DSN | 阻塞 F2 外设分配 |
| 3 | DDR3/DDR2 SO-DIMM 分别接哪片 FPGA | 原理图 | 影响 F2 内存方案 |
| 4 | JTAG 链拓扑 | 原理图/实测 | 影响 F2 调试方案 |
| 5 | 配置方式（F2 是否有独立 SPI Flash） | HW Manual/原理图 | 影响上电启动 |
| 6 | TAI Player 运行时软件 | S2C 提供 | 影响 IO 电压/时钟配置 |

## §08.4 双 FPGA 可行路径

### §08.4.1 方案 A：双独立 bitstream（推荐起步）

- F1：保持现有 Linux SoC，不修改
- F2：新建 `board/dualv7-fpga2/`，独立 Vivado 工程
- F2 承担：简单 GPIO、PCI 桥接、辅助外设
- 两片 FPGA 无直接通信（不使用 Inter-FPGA）
- **改动面最小，风险最低**

### §08.4.2 方案 B：主 SoC + 从 FPGA 协处理

- F1：保持现有 Linux SoC
- F2：加速器或高速 IO 聚合
- 通信：通过 50 条 Inter-FPGA 直连（LVDS 推荐）
- 需设计：Inter-FPGA 通信 IP（AXI4-Stream over LVDS 或自定义并行总线）
- **前提：确认 Inter-FPGA 引脚映射表**

### §08.4.3 方案 C：跨 FPGA 设计分区

- 单系统拆分到两片 FPGA
- 需：Inter-FPGA 通道、时钟对齐、复位同步、跨片约束
- Vivado Hierarchical Design / Partial Reconfiguration 经验要求高
- **风险最高，不推荐优先尝试**

## §08.5 下一步最小实验

1. **提取 Inter-FPGA 引脚表**（从 HW Manual PDF 手工读或原理图 DSN）
2. **F2 最小点亮**：`board/dualv7-fpga2/top.xdc`（时钟 N4/N3 + 1 LED），验证 F2 可配置
3. 确认 J3/J4/J5 上当前接了什么子卡
