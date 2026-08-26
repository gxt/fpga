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
**状态**：✅ 完成（2026-08-26，E1-E8 通过）
**Commit**：
**测试结果**：
- E1 ✅ RVV SoC SV 生成（14.9MB，enableRvv=true）；顶层端口 68 与 T022 一致（top 复用）
- E3-E6 ✅ 综合 20M 成功（~5.5h：synth 1h05m/place 38m/**route 3h42m**/bit 4m；**WNS +0.754 收敛**，WHS -0.253 轻微 hold；资源 LUT 467K/38.2%、RAMB36 74）
  - **T017 的 RVV route 拥塞未复现**（20M + 上游 2290a286c + 默认配置）
- E7 ✅ 烧录成功
- E8 ✅ 上板 **t007_rvv HALTED（自校验 PASS）**——RVV 核在裁剪 SoC 上跑通
**修改文件**：
- coralnpu fork：SoCChiselConfig enableRvv false→true（46389411）
- `synth/tcl/build_top.tcl`：top_coralnpu_soc 注入 RVV 宏（VLEN_128/ZVE32F_ON/TB_SUPPORT，与 chip_nexus 一致）
**验收结果**：
- RVV 核（CoreTlul enableRvv=true）在 DualV7 上跑通 t007_rvv（RVV 指令自校验）
- RVV 宏与 chip_nexus.core 对齐（VLEN_128/ZVE32F_ON/TB_SUPPORT true；RVVI_ON 未定义一致；USE_GENERIC/FPGA_XILINX false 一致）
**新发现/坑**：
1. RVV 模块 ifdef：ZVE32F_ON(140)/TB_SUPPORT(118) 需定义；ZVT_ON/ZVFBFWMA_ON/ZVTI16I32_ON 未定义（与 chip_nexus 一致，走 else）
2. RVV 核 LUT 38%（467K）——逻辑密集但 20M route 成功
3. route 3h42m（RVV 核布线慢但成功）
**遗留问题**：仅验证 t007_rvv；更多 RVV 用例（默认 TCM 8K/32K 够的）可按需加测；TCM 扩容待需要时
