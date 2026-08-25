# M2（Milestone 2）

第二阶段（M1 之后，上板闭环已完成）。

**新 M2 目标**：在 M1 基础上，**把 fpga/EDA 等硬件相关的各种事情梳理一遍**——流程、目录、规范、环境，让后续工作对新生友好、透明、可复现。

**背景（2026-08-25 复盘）**：
- M1 完成从零到上板闭环（T001-T016），但过程中积累了大量黑盒流程、命名混乱、残留产物
- coralnpu submodule 已覆盖为**上游 2290a286c**（清除 fork 改动：clang-14 wrapper、CoreAxi 拆分）
- 目录已重组：`tests/`（测试+上板脚本）、`synth/`（综合工程：rtl/xdc/tb/tcl/out）、`scripts/`（通用工具）
- 202 工作目录 `work/` → **`workspace/`**（`workspace/<task>-<subtask>/`，首次 `first`）
- 新增核心规范：**bazel/vivado 命令由用户在 terminal 执行**，log 落任务目录，用户通知后 agent 读 log 分析
- M1 审核矩阵见 `.tao/knowledge/m1-audit.md`（T001-T016 × 保留/适配/重做）

**任务划分**（延续全局递增 T###，按依赖顺序）：

| 任务 | 内容 | 阶段 |
| --- | --- | --- |
| T017 | 环境验证：Ubuntu 升级后 bazel/clang-18 兼容性 + 工具链 | E0 |
| T018 | 新核 top 适配 + 50MHz 完整 EDA 流程（学习全流程，LED 引脚预留） | E1-E8 |
| T019 | UART 加载 elf 时间评测 + 真实执行时间 | E8 |
| T020 | LED 三灯：找引脚/定含义/驱动方式（UART 直驱 vs 程序）/验证 | E3-E8 |
| T021 | 时钟树分析 + 降频实验（50M→20M→10M） | E3-E5 |

工作方式：bazel/vivado 命令由用户执行，agent 生成 `workspace/<task>-<subtask>/working.sh`（log 统一 `working.log`），用户执行后 agent 读 log 分析。

**里程碑定义**：M1 = 从零到上板闭环（T001-T014 验收通过）。
