# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-16）

- **阶段**：Phase0 环境搭建
- **下一步**：`/dispatch T002`（跑通官方 Cocotb 快速开始，首次构建含依赖下载与 RISC-V 工具链拉取，预计数小时，timeout≥6h）
- 说明：bazelisk 已装于 `~/.local/bin/`，`~/.bazeliskrc` 全局兜底 bazel 8.6.0

| 日期 | 项目/模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 2026-08-16 | Phase0 · T001 安装 bazelisk + bazel 8.6.0 | 已验证 | reviewer Accepted；产出 toolchain-notes.md；零代码改动，changelog 无记录 |
