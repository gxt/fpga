# T018: 新核 top 适配 + 50MHz 完整 EDA 流程（学习）

## 目标
coralnpu 已覆盖为上游 2290a286c（核 RTL 变化：RV64 参数化等），M1 的 bit（旧核 8225240f）失效。
本任务：适配 top_coralnpu.sv 到新核端口，**完整走一遍 EDA 流程（E1-E8）**，时钟目标 **50MHz**（M1 T010-clean 是 40M）。
过程中完整学习 EDA 流程各阶段。

## 执行环境
**201**（bazel 生成 SV）+ **202**（Vivado 综合/仿真）。命令由用户执行，脚本由 agent 生成 working.sh。

## 输入
1. coralnpu 上游 2290a286c（含 CoreMiniAxi）
2. `synth/rtl/top_coralnpu.sv` + wrapper/host_cmd_fsm/uart（M1 的，需适配新核端口）
3. `synth/xdc/top_coralnpu.xdc`（时钟 40M→50M）
4. `tests/`（t007 测试程序 + 上板脚本）
5. **LED 引脚调研**（docs/DualV7）：本任务预留 LED 输出引脚（T020 实现）——一次改 top 避免二次综合

## 输出
1. 适配新核的 `synth/rtl/top_coralnpu.sv`（含核端口对接 + LED 引脚预留）
2. 50MHz XDC
3. 完整流程产物：xsim 仿真 PASS → post_synth.dcp → post_route.dcp → 时序报告 → `.bit`/`.bin`
4. **EDA 流程学习记录**（E1-E8 每阶段：命令/产物/报告解读）
5. 上板：t007 程序（scalar）跑通 HALTED

## EDA 流程（E1-E8）
1. **E1 构建**：bazel 生成 CoreMiniAxi.sv（2290a286c）+ 编译 t007 ELF
2. **E2 仿真**：xsim 验证新核（AXI 直写 tb）
3. **E3 综合**：synth_design → post_synth.dcp + utilization_synth.rpt
4. **E4 实现**：place + route → post_route.dcp
5. **E5 签核**：timing（WNS/WHS ≥0）+ DRC
6. **E6 比特流**：write_bitstream → top_coralnpu.bit/.bin
7. **E7 烧录**：上板配置
8. **E8 上板验证**：load_elf t007 → HALTED

## 约束
1. bazel/vivado 命令由用户执行；working.sh 在 workspace/<task>-<subtask>/ 生成
2. 每阶段先看流程/命令 → 用户执行 → 读 log → 下一步（不黑盒）
3. 不改 coralnpu 上游源码

## 验收标准
1. 新核 50MHz 综合成功、WNS/WHS ≥0（若不收敛，记录并评估降频）
2. 上板 t007_scalar_fp_test.elf 跑通 HALTED（STATUS=1）
3. EDA 流程学习记录完成（每阶段产物 + 报告解读）
4. LED 引脚调研完成（docs/DualV7 位置确认 + top 预留输出）

## 完成区
**状态**：待开始
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：

## 审阅记录
（engineer 自审 + reviewer 验收）
