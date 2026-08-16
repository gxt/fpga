# T002: 跑通官方 Cocotb 快速开始（core_mini_axi_sim_cocotb）

## 执行环境
**执行环境**：本地

## 接口规范
- 输入：coralnpu 源码（HEAD d93b5550）；bazel 8.6.0（T001 完成）
- 输出：官方 Cocotb 快速开始 target 构建并运行通过；首次构建拉取的依赖缓存于 bazel 外部仓库缓存
- 约束：不改 coralnpu/ 内文件（如需修复按 ADR-003 流程）；构建超时预留充足（首次构建含 RISC-V 工具链，4 核 11G 内存环境预计数小时，建议 timeout ≥ 6h 分段执行）

## 验收标准
1. `bazel run //tests/cocotb:core_mini_axi_sim_cocotb` 运行完成且退出码 0
2. 运行日志出现 Cocotb 测试通过结果（如 `Passed` / 0 失败）
3. 记录关键依赖下载清单（如 chisel、opentitan、riscv 工具链、verilator hermetic 版本）到 `.tao/knowledge/` 工具链笔记
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
