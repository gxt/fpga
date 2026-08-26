# M3（Milestone 3）

第三阶段。目标：在 DualV7 板子上跑起来**较完整的 SoC**（CoreTlul + CoralNPUXbar + 最小外设 + SRAM），含 RVV。

## 背景（2026-08-26 规划）
- M2 完成 EDA 流程梳理，当前默认 20MHz、单核 CoreMiniAxi（AXI）上板闭环
- M3 架构：与 chip_nexus 一致（CoreTlul + CoralNPUXbar 纯 TL-UL 主干），**保留已验证的 UART 加载**（host_cmd_fsm AXI → **Axi2TLUL 桥** → Xbar uart_host 端口 → 核 tl_device）
- **裁剪**：ISP/DDR/spi2tlul/dma/spi_master_flash/spi_master 不接；保留 clint/plic/gpio/sram
- **uart0 外设不做**（host 回读代替结果读取；量大再加任务）
- **单时钟域（main）**，无 CDC；20MHz
- **submodule 用 gxt/coralnpu**（fork 承载 M3 裁剪改动，上游纯净）

## 任务划分

| 任务 | 内容 | 状态 |
| --- | --- | --- |
| T022 | 标量 SoC 基座：CoreTlul(enableRvv=false) + Xbar + clint/plic/gpio/sram(256K) + host 桥（Axi2TLUL）；xsim 验证 r/w → 综合 → 上板测试向量 | 进行中 |
| T023 | RVV SoC 全量：enableRvv=true + TCM（段统计定，64K/128K 候选）→ 上板全量 RVV 用例 | 待开始 |

## 待定项
- TCM 配置：T023 前统计 RVV 用例 ELF 段大小定 ITCM/DTCM
- host 桥 Axi2TLUL 与 host_cmd_fsm 的位宽/握手匹配（xsim 验证）
