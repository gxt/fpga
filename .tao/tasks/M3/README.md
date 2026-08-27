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
| T022 | 标量 SoC 基座：CoreTlul(enableRvv=false) + Xbar + clint/plic/gpio/sram(256K) + host 桥（Axi2TLUL）；xsim 验证 r/w → 综合 → 上板测试向量 | ✅ |
| T023 | RVV SoC：enableRvv=true（默认 TCM 8K/32K）→ 综合 20M → 上板 t007_rvv HALTED | ✅ |
| T024 | RVV 用例评测第一轮（默认 SoC）：621 ELF 构建、606 全测（604 PASS + 2 预期 fault）、matmul 性能 MACs/Cycle 7-25%、wfi 唤醒方案 | ✅ |

**M3 里程碑完成（2026-08-26）**：
- ✅ 较完整 SoC（CoreTlul + CoralNPUXbar + 最小外设 + SRAM 256K + UART 加载桥）在 DualV7 上板跑通
- ✅ **RVV 核上板验证通过**（t007_rvv 自校验 HALTED——T017 目标实现）
- ✅ 20M 时序收敛（标量 WNS+15.410 / RVV WNS+0.754）；RVV route 拥塞未复现（LUT 38%）
- ✅ UART 加载保留（host_cmd_fsm→Axi2TLUL→Xbar→核 tl_device，与 chip_nexus 架构一致）
- ✅ RVV 宏与 chip_nexus.core 对齐（VLEN_128/ZVE32F_ON/TB_SUPPORT）
- ✅ **RVV 全量评测完成**：606/621 用例（默认 TCM 可跑部分），通过率 100%（正常用例），8 个 matmul 性能分析完成

**M3 结束（606 默认用例评测完成）**——超限的 15 个 highmem/gemma 用例转入 M4（内存系统扩展）。

## 待定项
- TCM 配置：T023 前统计 RVV 用例 ELF 段大小定 ITCM/DTCM
- host 桥 Axi2TLUL 与 host_cmd_fsm 的位宽/握手匹配（xsim 验证）
