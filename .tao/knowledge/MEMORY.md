# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-20 现场快照）

- **阶段**：Phase4 板级 · 方案 A（host_tcm 直写 ITCM）调试中
- **主线**：T015 阻塞（host 经 AXI 写 ITCM 上板 SLVERR + 连续命令卡，仿真不可复现）。**方案 A**：改 CoreMiniAxi 加 host_tcm 直写端口（绕过 AXI），已实现并综合，**新 bit `T010-hosttcm` 已烧录上板，待 SW1 复位后测试 ITCM 直写**（应不再卡）
- **下一步**：① 提醒复位（每次需用户确认）→ ② `sg dialout` 跑 `sim/uart_slow_test.py` 验证 ITCM 直写连续写 → ③ R 读回验证
- **改动**：coralnpu fork `d74e0ac8`（CoreAxi host_tcm 端口，ITCM arbiter 4 端口）；主仓库 `72a4fae`（host_cmd_fsm W 写 ITCM 走直写）/`b4e6dcd`/`f30457f`
- **环境**：bazel 需 `CC=clang-14`（Ubuntu 24.04 clang-18 modules 不兼容）；串口 `ttyUSB0`（CH341）需 `sg dialout`；`/tools/Xilinx/2025.1` Vivado
- **详细调试过程**：`.tao/knowledge/board-debug-log.md`（T015/T016 全部调试、host_tcm 现场、工具/坑、恢复步骤）

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
