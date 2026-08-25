# T017: 环境验证（Ubuntu 升级后 bazel/clang 兼容性）

## 目标
验证 Ubuntu 大版本升级（22.04→24.04）+ coralnpu 覆盖上游 2290a286c 后的构建环境可用性。
M2 的 E0 环境基础，一切后续任务的前提。

## 执行环境
**201**（bazel 宿主）。命令由用户 terminal 执行，脚本由 agent 生成到 `workspace/T017-first/working.sh`。

## 输入
1. coralnpu submodule = 上游 2290a286c（wrapper 已恢复 `exec clang`）
2. .bazelrc：`CC="clang"`（系统默认 clang-18，Ubuntu 24.04）

## 输出
1. `workspace/T017-first/working.log`：bazel build 完整日志
2. **环境验证结论**：clang-18 主机构建是否可用；工具链是否下载成功

## 验证项
1. `bazel build //examples:coralnpu_v2_hello_world_add_floats`（clang-18 实测）
2. 上游 2290a286c 的 WORKSPACE 依赖下载是否正常（toolchain_coralnpu_v2 版本）
3. 工具链可用性（riscv64-unknown-elf-gcc）

## 约束
1. 不改 coralnpu 上游源码（保持纯净）
2. 若 clang-18 失败：记录真实错误 → 评估方案（.bazelrc 环境指定 clang-14 / 试 clang-17 / 上游推荐）→ 用户决策
3. 命令脚本由 agent 生成 working.sh，用户执行 bash working.sh

## 验收标准
1. `bazel build` 成功（`Build completed successfully` + hello ELF 产物）
2. 失败则记录完整错误 + 提出方案，等用户决策

## 完成区
**状态**：待执行
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：

## 审阅记录
（engineer 自审 + reviewer 验收）
