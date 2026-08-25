# T017: EDA 流程梳理

## 目标
在 M1 基础上，把 fpga/EDA 硬件相关的流程梳理清楚，形成**对新生友好的阶段化流程规范**，并验证覆盖后的环境可用性。

## 执行环境
**201**（仓库/git/上板）+ **202**（Vivado 宿主）。bazel/vivado 命令由用户 terminal 执行，agent 只准备命令与分析日志。

## 输入
1. M1 审核矩阵 `.tao/knowledge/m1-audit.md`（T001-T016 × 保留/适配/重做）
2. 当前目录结构（tests/ synth/ scripts/ + 202 workspace/）
3. AGENTS.md（已含核心规范草案）

## 输出
1. **EDA 流程文档**（E0-E8 阶段）：每阶段目的/工具/命令/产物/目录规范
2. **目录结构规范**：tests/、synth/{rtl,xdc,tb,tcl,out}、scripts/ 职责定义
3. **Vivado 运行规范**：`workspace/<task>-<subtask>/`（首次 first）、保留/清理清单、sync.sh pull 过滤
4. **环境验证结果**：bazel 兼容上游 2290a286c、**clang-18 主机构建实测**、工具链可用、SV 生成正常

## 约束
1. bazel/vivado 命令由用户在 terminal 执行；agent 准备命令文本 + 分析日志
2. 每步改动可见：先给流程/命令 → 用户执行 → 读 log → 下一步
3. 不改 coralnpu 上游源码（保持 2290a286c 纯净）；环境问题用环境层解决（如 .bazelrc 而非 fork 仓库）
4. 命令缺失必须告知用户，不自行换命令

## 验收标准
1. EDA 流程文档覆盖 E0-E8 全阶段，每阶段含命令示例与产物说明
2. 目录规范文档化并落地（引用已同步）
3. 环境验证通过：`bazel build //examples:coralnpu_v2_hello_world_add_floats`（clang-18）成功；SV 生成目标确认
4. 若 clang-18 失败：记录真实错误 → 提出并评估解决方案（.bazelrc 指定 clang-14 / 试 clang-17 / 上游推荐）→ 用户决策后实施

## 完成区
**状态**：进行中
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：

## 审阅记录
（engineer 自审 + reviewer 验收）
