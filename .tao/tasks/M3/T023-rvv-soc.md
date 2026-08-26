# T023: RVV SoC 全量验证（enableRvv=true，默认 TCM）

## 目标
在 T022 裁剪 SoC 基座上启用 RVV（CoreTlul enableRvv=true），DualV7 上板验证 RVV 用例。
**TCM 保持默认（8K ITCM + 32K DTCM）**（用户决策：T023 先不动 TCM，验证 RVV 功能；用例不够再调）。

## 执行环境
201（改 fork + 上板）+ 202（bazel 生成 + Vivado）。bazel/vivado 由用户执行。

## 改动
1. coralnpu fork `SoCChiselConfig.scala`：`enableRvv = false` → `true`（一行，其他裁剪不变）
2. 主仓库 submodule 指针 → gxt/coralnpu 新 commit

## 流程（E1-E8）
1. **E1** bazel 生成 RVV SoC SV（默认 TCM 8K/32K）
2. **E2** xsim 验证（可选，tb 复用 T022——RVV 核启动）
3. **E3-E6** 综合 20M（**RVV 核拥塞风险**，T017 教训；20M 缓解）
4. **E7-E8** 烧录 + 上板 RVV 用例（t007_rvv 起步 → 基础 RVV 用例，TCM 够的）

## 约束
- TCM 不动（默认 8K/32K）
- 若用例 ELF 段超 TCM → 记录，后续再调（新任务/变体）
- bazel/vivado 由用户执行，working.sh 在 workspace/T023-<subtask>/

## 验收标准
1. RVV SoC SV 生成（enableRvv=true 生效）
2. 综合 20M 成功（0 ERROR；若拥塞记录）
3. 上板 t007_rvv 等基础 RVV 用例 ALL PASS

## 完成区
**状态**：待开始
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：
