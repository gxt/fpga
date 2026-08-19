# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-18）

- **阶段**：Phase3 综合（完成）→ Phase4 板级
- **下一步**：`/dispatch T012`（板卡加载 bitstream 与连通性验证，需本机连板卡 + JTAG cable；**需确认 OSC1 实际频率与 RS232 线缆**）
- 说明：Phase0-3 全部完成（T001-T011 已验证）；**上板 bitstream 就绪**（`synth/out/T010/top_coralnpu.bit`）；资源分析已沉淀（xc7v2000t LUT 3.56%，与 xcvu13p 基线对比）；服务器 license `XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic`

| 日期 | 项目/模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 2026-08-16 | Phase0 · T001 安装 bazelisk + bazel 8.6.0 | 已验证 | reviewer Accepted；产出 toolchain-notes.md；零代码改动 |
| 2026-08-17 | Phase0 · T002 跑通官方 Cocotb 快速开始 | 已验证 | 双模型交叉验收；方案 B csr_test PASSED；零代码改动 |
| 2026-08-17 | Phase0 · T003 跑通官方 Verilator C++ sim | 已验证 | 双模型交叉验收；hello_world ELF + sim 运行 exit 0；零代码改动 |
| 2026-08-17 | Phase1 · T004 架构文档研读与知识沉淀 | 已验证 | 双模型交叉验收；产出 coralnpu-architecture.md；零代码改动 |
| 2026-08-17 | Phase1 · T005 构建链路与验证体系梳理 | 已验证 | 双模型交叉验收；产出 coralnpu-build-map.md；零代码改动 |
| 2026-08-18 | Phase2 · T006 Cocotb 测试套件核心子集 | 已验证 | 三轮 reviewer 验收 + Mimo 复核；37/37 通过，产出 cocotb-test-matrix.md；零代码改动 |
| 2026-08-18 | Phase2 · T007 编写自定义测试程序 | 已验证 | 双模型交叉验收（含代码 review）；sim/ 新增 7 文件；见 changelog |
| 2026-08-18 | Phase3 · T008 远程综合服务器工作流搭建 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；synth/ 工作流脚本 + 拓扑三要素；见 changelog |
| 2026-08-18 | Phase3 · T009 fusesoc 生成 Vivado 工程并跑通官方器件综合 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；官方基线综合成功，产出 synth-notes.md；零代码改动 |
| 2026-08-18 | Phase3 · T010 目标器件适配与 bitstream 生成 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；上板 bitstream 产出（.bit/.bin）；synth/rtl/xdc/tcl/sim 新增；见 changelog |
| 2026-08-18 | Phase3 · T011 资源时序报告分析与知识沉淀 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；资源构成/对比表/时序分析沉淀 synth-notes.md；零代码改动 |
