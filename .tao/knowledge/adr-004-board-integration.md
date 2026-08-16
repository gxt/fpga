# ADR-004: 上板集成方式（NPU core + AXI 桥接）

- 状态：已接受
- 日期：2026-08-16
- 相关任务：T012、T013

## 背景

官方 `fpga/` 提供完整 SoC（`coralnpu_soc.sv`），集成大量外设：UART、SPI、I2C、ISP（ispyocto）、DDR4 控制器、显示（waveshare）、GPIO 等，目标硬件为 Google 内部 Nexus 板（xcvu13p），并依赖大量 lowrisc/opentitan IP 与 DPI 模型。完整 SoC 移植到本地新板卡工程量巨大、且许多外设与板卡无关。

另一方面，官方提供最小可集成配置：`core_mini_axi`（scalar-only 或 RVV 版本）——通过 **AXI slave** 写 TCM/CSR、通过 **AXI master** 访问外部内存，见 `doc/integration_guide.md`。这是 NPU 核心计算能力的最小集成面。

上板验证目标应聚焦"NPU 核心在真实 FPGA 上跑通计算"。

## 决策

1. **上板集成采用 NPU core + AXI 桥接方式**：以 `core_mini_axi`（或对应 RVV 配置）为 RTL，宿主通过 AXI slave 端口写入程序（TCM）与配置，NPU 执行，结果通过 AXI master 读回或板载简单外设（LED/UART）输出。
2. **不做完整 SoC 移植**：不引入 ISP、DDR、显示等与 NPU 验证无关的外设。
3. AXI 桥接的 host 侧可以是：
   - 板卡上现成的软核（MicroBlaze）或硬核（Zynq PS），或
   - 外部 JTAG/驱动脚本通过调试口直接读写，或
   - 简单的状态机主控（视板卡能力选择，任务内落实）。
4. 上板结果须与 RTL 仿真（T003/T006/T007 同程序）对齐，作为正确性证据。

## 影响

- 验证范围聚焦 NPU 计算正确性，工程量可控，适合本地板卡。
- 与上游 SoC 验证存在差异（无外设、无 DDR），需在交付文档中说明差异与验证覆盖。
- host 侧 AXI 桥接驱动是新增工作，方案依赖板卡能力，需在 T013 内细化。

## 已拒绝方案

- **完整 SoC 移植**：工程量巨大、依赖 Nexus 专用硬件与大量外设 IP。
- **仅做 bitstream 不上板**：用户明确要求上板验证。
