# §16 已收口工作与当前基线

**日期**：2026-05-22  
**用途**：给后续 DualV7 新工作一个明确起点，避免继续混入已经结束的工作线

---

## §16.1 已结束的两条工作线

### 1. BOOM-stop 分析线

这条线当前目标已经完成：

- 原始设计文档 `boomstop.md` 已分析
- 原始实现与设计文档的偏差已收口
- 正确性 / 防篡改风险已收口
- “最小 patch 候选语义集” 只保留到分析结论，不继续作为当前主线任务

后续若重启，默认入口文档是：

- [BOOM-stop-机制与防篡改说明.md](/home/data/vivado-risc-v/doc/BOOM-stop-机制与防篡改说明.md:1)
- [BOOM-stop-正确性与防篡改分析报告.md](/home/data/vivado-risc-v/doc/BOOM-stop-正确性与防篡改分析报告.md:1)
- [BOOM-stop-设计文档与实现偏差分析.md](/home/data/vivado-risc-v/doc/BOOM-stop-设计文档与实现偏差分析.md:1)
- [BOOM-stop-四项特性说明.md](/home/data/vivado-risc-v/doc/BOOM-stop-四项特性说明.md:1)

知识库统一口径见：

- [09-boom-stop.md](/home/data/vivado-risc-v/code-agent/knowledge/09-boom-stop.md:1)

### 2. Mega / z2m bring-up 线

这条线当前目标也已经完成：

- `rocket64z2m` 双核 bit 已上板
- U-Boot 网络引导链已跑通
- Linux BusyBox NFS root 已跑通
- `r3` 已锁为当前双核软件验证基线

当前推荐 release 基线：

- `dualv7-r3-z2m-busybox-netboot`

对应入口：

- [DualV7-Release清单.md](/home/data/vivado-risc-v/doc/DualV7-Release清单.md:1)
- [DualV7-FPGA本地操作流程.md](/home/data/vivado-risc-v/doc/DualV7-FPGA本地操作流程.md:1)
- [DualV7-当前SoC架构与频率说明.md](/home/data/vivado-risc-v/doc/DualV7-当前SoC架构与频率说明.md:1)

补充说明：

- `20MHz` 单频实验线已验证可工作，可作为后续提频参考
- `40MHz` 只属于功能可跑通的实验线，不是当前正式基线
- `076x` 多档 `soc_clk` 仍属于实验设计，不纳入当前稳定起点

---

## §16.2 当前稳定资产

### 1. bit / release / 代码

后续默认从以下资产出发：

- release 清单：
  [DualV7-Release清单.md](/home/data/vivado-risc-v/doc/DualV7-Release清单.md:1)
- 当前本地 FPGA 操作流程：
  [DualV7-FPGA本地操作流程.md](/home/data/vivado-risc-v/doc/DualV7-FPGA本地操作流程.md:1)
- 当前 SoC 架构/频率说明：
  [DualV7-当前SoC架构与频率说明.md](/home/data/vivado-risc-v/doc/DualV7-当前SoC架构与频率说明.md:1)

### 1.1 DualV7 本地恢复入口（2026-06-24）

重新把 DualV7 接回本地主机时，当前推荐直接走 `095x` 的恢复入口：

- [DualV7-z2m-网络引导-telnet恢复手册.md](/home/data/vivado-risc-v/doc/DualV7-z2m-网络引导-telnet恢复手册.md:1)
- [workspace/095x/README.md](/home/data/vivado-risc-v/workspace/095x/README.md:1)
- [DualV7-z1-单核Mega网络引导手册.md](/home/data/vivado-risc-v/doc/DualV7-z1-单核Mega网络引导手册.md:1)
- [workspace/096x/README.md](/home/data/vivado-risc-v/workspace/096x/README.md:1)

这条入口的关键补充是：

1. 默认恢复基线仍然是
   `rocket64z2m-20mhz.bit + boot-r2.elf + BusyBox NFS root`
2. 当前**不要**再把
   `linux-stable/arch/riscv/boot/Image`
   当作历史验证通过的固定内核工件
3. 当前冻结的历史验证内核应取：
   `/home/data/vivado-risc-v/workspace/release-r2-hotfix/nfsroot/Image`
   或 `/srv/tftp/Image`
4. 本地主机若用户不在 `dialout` 组，UART 可能需要临时
   `setfacl`
5. 当前已经补出 `rocket64z1` 单核 Mega 的本地入口，
   可直接复用 `boot-r2.elf + BusyBox NFS root`

### 2. 网络与引导知识

网络与引导这两块现在都已有稳定口径，不需要从头排查：

- 网络知识：
  [04-ethernet.md](/home/data/vivado-risc-v/code-agent/knowledge/04-ethernet.md:1)
- 网络复盘：
  [13-network-debug-postmortem.md](/home/data/vivado-risc-v/code-agent/knowledge/13-network-debug-postmortem.md:1)
- SDC / SD boot：
  [07-sdc-boot.md](/home/data/vivado-risc-v/code-agent/knowledge/07-sdc-boot.md:1)

### 3. 编译综合流程

后续远端 Vivado / 本地 JTAG / NFS 流程都不要再重新摸索，直接从现有文档复用：

- [vivado-risc-v-编译流程.md](/home/data/vivado-risc-v/doc/vivado-risc-v-编译流程.md:1)
- [vivado-risc-v-编译流程-简版.md](/home/data/vivado-risc-v/doc/vivado-risc-v-编译流程-简版.md:1)
- [DualV7-FPGA本地操作流程.md](/home/data/vivado-risc-v/doc/DualV7-FPGA本地操作流程.md:1)

---

## §16.3 当前不再作为默认入口的内容

后续新工作默认不要再从下面这些内容起步：

1. 早期零散 bring-up 任务
2. 旧的 `051x` 网络试错过程
3. BOOM-stop 整仓可用性假设
4. `40MHz` 可发布假设
5. `076x` 多档时钟实验设计

这些内容仍保留作历史记录，但不作为当前默认基线。

---

## §16.4 新 DualV7 工作的默认起点

如果后续开启新的 DualV7 工作，默认顺序是：

1. 先看：
   - [§16 已收口工作与当前基线](/home/data/vivado-risc-v/code-agent/knowledge/16-closed-work-and-current-baseline.md:1)
   - [DualV7-Release清单.md](/home/data/vivado-risc-v/doc/DualV7-Release清单.md:1)
   - [DualV7-FPGA本地操作流程.md](/home/data/vivado-risc-v/doc/DualV7-FPGA本地操作流程.md:1)

2. 再看对应专题知识：
   - 网络：`§04`
   - SDC：`§07`
   - 双 FPGA：`§08`
   - BOOM 版本：`§11`

3. 新工作不要默认继承：
   - BOOM-stop 任务链
   - 40MHz / 多档时钟实验链

---

## §16.5 当前一句话状态

**BOOM-stop 与 Mega/z2m 两条线都已收口；bit、代码、release、流程文档均已固定；后续可以以 `r3 z2m busybox netboot` 为硬件/软件基线，开启新的 DualV7 工作。**
