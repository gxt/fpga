# Chipyard 1.13.0 + DualV7 集成设计

> 日期：2026-05-13
> 目标：在不破坏当前 `vivado-risc-v` 基线的前提下，
> 引入 Chipyard 1.13.0 对应的 BOOM 版本
> `d2a64f7ca9fd914d9c686cb23edcd32d3465a02e`

## 1. 设计结论

推荐采用一条**混合集成路线**：

1. **RTL 生成基线**使用 **Chipyard 1.13.0**
2. **板级承接基线**继续使用当前已验证的
   **DualV7 Vivado shell**
3. 两边通过一个明确的**系统边界 wrapper**
   对接，而不是直接在当前 `vivado-risc-v`
   主线里升级全部子模块

这个方案对应的核心判断是：

- 不在当前 `vivado-risc-v` 上 backport 目标 BOOM
- 不把当前主工作区整体回滚/升级到 Chipyard 1.13.0
- 在独立仓库里让 Chipyard 1.13.0 负责生成
  **目标 BOOM 对应的 SoC RTL**
- 在 Vivado 侧继续复用已经为 DualV7 调通的
  clock/reset/MIG/XDC/JTAG/UART/SDC shell

## 2. 为什么这样做

### 2.1 不选“直接合并 BOOM 代码”

当前 `vivado-risc-v` 的 BOOM 是：

- `18c48bb41ac3c64f6c65ef51db2e165d5460679d`

目标 BOOM 是：

- `d2a64f7ca9fd914d9c686cb23edcd32d3465a02e`

两者之间确认有 **250 commits** 差距。

这不是“补几个 feature”级别的差异，而是：

- BOOM 自身实现演进
- `rocket-chip` API 演进
- `testchipip` / `diplomacy` / `cde` 依赖演进
- Chisel / sbt 依赖栈演进

在当前 `vivado-risc-v` 栈上直接 backport，
实际等价于手工做一次跨版本移植，不划算。

### 2.2 不选“直接升级当前主线仓库”

当前 DualV7 主线已经积累了：

- `rocket64b2`
- `rocket64z1`
- `rocket64z2m`
- SDC 启动链
- 当前 Vivado board shell

如果在这个仓库里直接升级子模块和构建栈，
会把现有可工作基线一起打散。

这条路线的问题不是“最终绝对做不到”，
而是**破坏面太大**，没有必要先这么做。

### 2.3 为什么是“Chipyard RTL + DualV7 shell”

目标 BOOM commit 本来就属于
**Chipyard 1.13.0 依赖栈**。

因此最稳妥的做法是：

- 让 Chipyard 1.13.0 负责提供
  **正确版本匹配的 SoC RTL**
- 让当前 DualV7 工程继续提供
  **已验证的 FPGA 落地外壳**

这样可以把问题拆成两个相对清晰的面：

1. **SoC 生成问题**
2. **FPGA 板级集成问题**

## 3. 总体架构

建议把系统拆成三层：

### 3.1 Layer A：Chipyard 1.13.0 SoC 生成层

职责：

- 生成目标 BOOM 对应的 SoC RTL
- 固定 Chipyard 1.13.0 依赖栈
- 提供可被 FPGA shell 消费的顶层端口

不在这层解决：

- DualV7 pin constraint
- Vivado board design
- MIG/ILA/XDC
- JTAG 下载流程

### 3.2 Layer B：DualV7 Integration Wrapper

这是新路线的关键层。

职责：

- 作为 Chipyard SoC 与 DualV7 shell 的边界
- 统一 clock/reset 进入方式
- 统一 memory / mmio / dma 外部接口
- 统一 interrupt / bootrom / debug 暴露方式

这个 wrapper 的目标不是实现全部外设，
而是把 Chipyard 生成的 SoC 整理成
当前 Vivado shell 能稳定接住的形式。

### 3.3 Layer C：当前 DualV7 Vivado Shell

职责：

- `xc7v2000tflg1925-1` 顶层板级落地
- MIG / clock wizard / reset
- XDC / pinout
- JTAG / xsdb
- 现有 UART / SDC / Ethernet / GPIO 接入骨架

这层尽量复用现有已经调通的内容，
不要一开始就重写。

## 4. 推荐的系统边界

在设计上，先不要把 Chipyard 的原始顶层直接塞进
当前 BD。

应先定义一个稳定的 FPGA 外部边界：

### 4.1 时钟与复位

- `sys_clk_100m`
- `sys_reset_n`

### 4.2 内存接口

优先抽象成：

- `MEM_AXI4`

由 Vivado shell 负责接到：

- `axi_smc`
- `MIG`

### 4.3 MMIO 接口

优先抽象成：

- `IO_AXI4`

由 Vivado shell 负责挂接：

- UART
- SDC
- Ethernet
- XADC
- GPIO

### 4.4 DMA 接口

如 SoC 仍需要独立 DMA 出口，
则明确保留：

- `DMA_AXI4`

如果第一阶段不需要，
可以先只保留接口定义，不急着全部接通。

### 4.5 中断

先定义明确的 interrupt bundle，
由 Vivado shell 侧映射：

- UART irq
- SDC irq
- Ethernet irq
- 其他 GPIO/XADC irq

## 5. 第一阶段不追求的东西

第一阶段目标是**让目标 BOOM 版本可生成、
可被集成**，不是立刻跑 Linux。

因此以下内容先不作为阶段目标：

- DDR 可启动 Linux
- SDC 引导
- Ethernet 可收发
- 双核 / 多核扩展
- 两片 FPGA 分担

第一阶段只要求：

1. Chipyard 1.13.0 sandbox 建立
2. 目标 BOOM config 能 `make verilog`
3. 顶层接口差异报告写清楚
4. Wrapper 设计边界清楚

## 6. 推荐实施顺序

### Phase 1：准备 Chipyard 1.13.0 基础环境

产物：

- 独立目录
- 可离线使用的 source tree
- 可调用的 `sbt` / Java 环境

### Phase 2：生成目标 BOOM RTL

产物：

- Chipyard 1.13.0 下目标 config 的 Verilog
- 顶层模块名和端口清单

### Phase 3：接口差异分析

产物：

- Chipyard 顶层 vs 当前 DualV7 shell 的接口差异
- clock/reset/AXI/interrupt 对接表

### Phase 4：做 DualV7 integration wrapper

产物：

- 明确的 wrapper 设计
- 最小接入路径

### Phase 5：先做最小硬件冒烟

顺序建议：

1. LED
2. UART
3. DDR
4. SDC
5. Ethernet

## 7. 基础环境要求

202 上后续要满足这些前提：

### 7.1 Source tree

需要一份**独立于当前 `vivado-risc-v` 的**
Chipyard 1.13.0 source tree。

建议路径：

```text
/home/zzx/work/chipyard-dualv7-bootstrap/
```

### 7.2 Java / sbt

当前 202 上已有：

- Java 17

但系统路径里没有全局 `sbt`。

后续应至少保证：

- 可用的 `sbt` launcher
- 可在 bootstrap 环境里稳定调用

### 7.3 不污染现有工作区

不要在下面这些目录里直接改：

- `~/vivado-risc-v`
- `~/chipyard`
- `~/chipyard-old`

新的工作目录必须单独建立。

## 8. 下一步任务边界

下一任务不该直接写成：

- “移植 board 文件”
- “直接跑 bitstream”

下一任务应该收成：

1. 在 202 建立 Chipyard 1.13.0 bootstrap 目录
2. 记录实际使用的 source/tag/submodule 状态
3. 验证 `sbt` / build 入口
4. 跑第一轮 `make verilog` 级验证
5. 输出顶层接口差异报告

## 9. 一句话结论

**推荐路线不是“在当前 vivado-risc-v 里升级 BOOM”，
而是“用 Chipyard 1.13.0 生成目标 RTL，
再通过明确的 integration wrapper 接回当前
DualV7 Vivado shell”。**
