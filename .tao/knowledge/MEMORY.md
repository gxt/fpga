# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-21 现场快照）

- **阶段**：Phase4 板级 · **T015 已达成**（UART host 通路 + 程序加载 + 上板运行）
- **里程碑**：T007 标量+浮点程序在 S2C 板**上板运行 ALL PASS**（out_mul={700,1600,2700,4000}、fout={2.0,3.0,5.0,7.0}），模拟→综合→上板闭环打通
- **T015 根因定案**：此前"host 写 ITCM 卡/无响应/SLVERR"全部源于 **uart_rx 亚稳态**（rx_in 无同步器，长命令偶发 RX 错），与 AXI/仲裁/直写无关；修复 = uart_rx 加 2 级同步器 + DIV 四舍五入 + phys_opt -hold_fix → W/DTCM/ITCM 全 16/16 稳定
- **方案 A（host_tcm 直写 ITCM）**：已实现且工作（16/16），保留为 ITCM 加载通路
- **当前 bit**：`synth/out/T010-sync/top_coralnpu.bit`（10:59，md5 514c5a56...，最新）
- **下一步**：T015 收尾（修正 load_elf Q 轮询误报）→ T016 阶段 B（Debug 上板写）或直接推进 T013（NPU 功能验证）→ 完整 SoC 规划（soc-analysis.md）
- **环境**：bazel `CC=clang-14`；串口 `ttyUSB0` 需 `sg dialout`；202 所有 Vivado 任务；测试脚本 `sim/`（itcm_direct_test/uart_raw_probe/uart_baud_probe/csr_probe/t007_result_check）
- **详细调试**：`.tao/knowledge/board-debug-log.md`（根因证据链 + 修复链 + T007 上板记录）

**机器分工**：机器201 = 仓库维护/opencode/板卡烧录；机器202 = 所有 Vivado 任务（xsim/综合/bitstream），git 局域网同步（fetch-then-pull），sudo 需用户允许。
**Phase4 任务链**：T012（已验证）→ T015（阻塞，方案A中）→ T016（阶段A过/阶段B Debug 上板未生效）→ T013（前置 LED 修正）→ T014。
**上板纪律**：复位必先提醒+等确认；脚本 201 编写→git→202 执行；SRAM 复位不清。

| 日期 | 项目/模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 2026-08-16 | Phase0 · T001 安装 bazelisk + bazel 8.6.0 | 已验证 | reviewer Accepted；产出 toolchain-notes.md；零代码改动 |
| 2026-08-17 | Phase0 · T002 跑通官方 Cocotb 快速开始 | 已验证 | 双模型交叉验收；方案 B csr_test PASSED；零代码改动 |
| 2026-08-17 | Phase0 · T003 跑通官方 Verilator C++ sim | 已验证 | 双模型交叉验收；hello_world ELF + sim 运行 exit 0；零代码改动 |
| 2026-08-17 | Phase1 · T004 架构文档研读与知识沉淀 | 已验证 | 双模型交叉验收；产出 coralnpu-architecture.md；零代码改动 |
| 2026-08-17 | Phase1 · T005 构建链路与验证体系梳理 | 已验证 | 双模型交叉验收；产出 coralnpu-build-map.md；零代码改动 |
| 2026-08-18 | Phase2 · T006 Cocotb 测试套件核心子集 | 已验证 | 三轮 reviewer 验收 + Mimo 复核；37/37 通过，产出 cocotb-test-matrix.md；零代码改动 |
| 2026-08-18 | Phase2 · T007 编写自定义测试程序 | 已验证 | 双模型交叉验收（含代码 review）；sim/ 新增 7 文件；见 changelog |
| 2026-08-18 | Phase3 · T008 机器202工作流搭建 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；synth/ 工作流脚本 + 拓扑三要素；见 changelog |
| 2026-08-18 | Phase3 · T009 fusesoc 生成 Vivado 工程并跑通官方器件综合 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；官方基线综合成功，产出 synth-notes.md；零代码改动 |
| 2026-08-18 | Phase3 · T010 目标器件适配与 bitstream 生成 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；上板 bitstream 产出（.bit/.bin）；synth/rtl/xdc/tcl/sim 新增；见 changelog |
| 2026-08-18 | Phase3 · T011 资源时序报告分析与知识沉淀 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；资源构成/对比表/时序分析沉淀 synth-notes.md；零代码改动 |
