# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-18）

- **阶段**：Phase2 模拟深化
- **下一步**：`/dispatch T007`（编写自定义测试程序，gdbserver 环境问题可跟进：libmpfr4 需 root 安装）
- 说明：Phase0/Phase1 完成；T006 已验证（37/37 子集全过，矩阵 cocotb-test-matrix.md 已沉淀）；gdbserver 因 libmpfr.so.4 缺失排除

| 日期 | 项目/模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 2026-08-16 | Phase0 · T001 安装 bazelisk + bazel 8.6.0 | 已验证 | reviewer Accepted；产出 toolchain-notes.md；零代码改动，changelog 无记录 |
| 2026-08-17 | Phase0 · T002 跑通官方 Cocotb 快速开始 | 已验证 | 双模型交叉验收；方案 B csr_test PASSED；零代码改动 |
| 2026-08-17 | Phase0 · T003 跑通官方 Verilator C++ sim | 已验证 | 双模型交叉验收；hello_world ELF + sim 运行 exit 0；零代码改动 |
| 2026-08-17 | Phase1 · T004 架构文档研读与知识沉淀 | 已验证 | 双模型交叉验收；产出 coralnpu-architecture.md；零代码改动 |
| 2026-08-17 | Phase1 · T005 构建链路与验证体系梳理 | 已验证 | 双模型交叉验收；产出 coralnpu-build-map.md；零代码改动 |
| 2026-08-18 | Phase2 · T006 Cocotb 测试套件核心子集 | 已验证 | 三轮 reviewer 验收 + Mimo 复核；37/37 通过，产出 cocotb-test-matrix.md；零代码改动 |
