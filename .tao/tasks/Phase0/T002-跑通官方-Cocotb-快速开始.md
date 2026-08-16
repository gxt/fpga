# T002: 跑通官方 Cocotb 快速开始（core_mini_axi_sim_cocotb）

## 执行环境
**执行环境**：本地

## 接口规范
- 输入：coralnpu 源码（HEAD d93b5550）；bazel 8.6.0（T001 完成）
- 输出：官方 Cocotb 快速开始 target 构建并运行通过；首次构建拉取的依赖缓存于 bazel 外部仓库缓存；关键依赖下载清单记录到 `.tao/knowledge/toolchain-notes.md`
- meta target 语义：`bazel run //tests/cocotb:core_mini_axi_sim_cocotb` 是 cocotb_test_suite 生成的 **meta target**，实际运行 `tests/cocotb/BUILD` 中 `CORE_MINI_AXI_SIM_TESTCASES` 声明的全部 **20 个 case**（其中 `core_mini_axi_basic_write_read_memory`、`core_mini_axi_write_read_memory_stress_test`、`core_mini_axi_rand_instr_test`、`core_mini_axi_burst_types_test` 标记为 `large`，suite 整体 `size=enormous`）。全量冒烟属长耗时项，本任务做法二选一并记录选择：
  - 方案 A（全量冒烟）：timeout ≥ 6h，分段执行（首次 bazel 构建含 RISC-V 工具链，4 核 11G 内存环境预计数小时）；
  - 方案 B（固定单个快速用例）：选 1 个默认 `medium` size 的快速 case（如 `core_mini_axi_riscv_tests` 或 `core_mini_axi_csr_test`）作为冒烟，剩余 case 由 T006 子集选择覆盖。
- 约束：不改 coralnpu/ 内文件（如需修复按 ADR-003 流程）；执行前检查磁盘空间（bazel 外部仓库缓存 + 工具链构建，预留 ≥ 30G 可用），不足则先清理再执行

## 验收标准
1. 按所选方案执行：方案 A 跑完整 meta target（20 case），方案 B 跑单个快速 case——退出码 0，运行日志出现 Cocotb 通过标志（如 `Passed` / 0 failures / `All tests passed`）
2. 记录执行方案选择（A/B）与对应运行日志片段；若选方案 B，明确说明剩余 case 的覆盖计划（由 T006 子集执行）
3. 记录关键依赖下载清单（chisel、opentitan、riscv 工具链、hermetic verilator 版本等）与磁盘占用到 `.tao/knowledge/toolchain-notes.md`
4. 无对 coralnpu/ 的本地修改（`git -C coralnpu status` 干净）

## 完成区
**状态**：待开始
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：

## 审阅记录

#### 第 1 轮 engineer 自审
（工程师自审 subagent 的意见、问题、判决及 finding 处置）

#### 第 1 轮 reviewer 验收
（审查者独立验证的重跑记录、约束核验、判决；Needs Revision 返工后，下一轮标 `第 2 轮`）
