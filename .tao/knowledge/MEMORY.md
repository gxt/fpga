# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-17）

- **阶段**：Phase0 环境搭建
- **下一步**：`/dispatch T003`（跑通官方 Verilator C++ sim hello world；bazel 缓存已热，二次构建秒级）
- 说明：T002 已验证（方案 B：csr_test 冒烟 PASSED）；依赖清单已沉淀 toolchain-notes.md；首次全量构建约 22 分钟，缓存 8.9G

| 日期 | 项目/模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 2026-08-16 | Phase0 · T001 安装 bazelisk + bazel 8.6.0 | 已验证 | reviewer Accepted；产出 toolchain-notes.md；零代码改动，changelog 无记录 |
| 2026-08-17 | Phase0 · T002 跑通官方 Cocotb 快速开始 | 已验证 | 双模型交叉验收（reviewer Accepted + Mimo 复核确认）；方案 B csr_test PASSED；零代码改动 |
