# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-17）

- **阶段**：Phase0 环境搭建
- **下一步**：`/dispatch T004`（架构文档研读）或 `/dispatch T006`（Cocotb 子集）；Phase0 完成，进入 Phase1/Phase2
- 说明：T001-T003 已验证（bazelisk/bazel 8.6.0、Cocotb 冒烟、Verilator C++ sim）；Verilator sim 需 `--linkopt=-latomic`，bazel-bin 路径随配置切换需用 bazel-out 完整路径（toolchain-notes.md 已记录）

| 日期 | 项目/模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 2026-08-16 | Phase0 · T001 安装 bazelisk + bazel 8.6.0 | 已验证 | reviewer Accepted；产出 toolchain-notes.md；零代码改动，changelog 无记录 |
| 2026-08-17 | Phase0 · T002 跑通官方 Cocotb 快速开始 | 已验证 | 双模型交叉验收（reviewer Accepted + Mimo 复核确认）；方案 B csr_test PASSED；零代码改动 |
| 2026-08-17 | Phase0 · T003 跑通官方 Verilator C++ sim | 已验证 | 双模型交叉验收；hello_world ELF + sim 运行 exit 0；零代码改动 |
