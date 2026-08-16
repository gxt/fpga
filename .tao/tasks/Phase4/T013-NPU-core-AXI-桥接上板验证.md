# T013: NPU core + AXI 桥接上板验证

## 执行环境
**执行环境**：本地（本机直接连接板卡）＋ 远端（综合产物）

## 接口规范
- 输入：T010 bitstream（NPU core + AXI 桥接版本）；T012 验证的板卡环境；T007 自定义测试程序（同一 ELF 上板对照）
- 输出：上板运行 NPU 程序并回读/观察结果；与 RTL 仿真结果对照记录（`.tao/knowledge/board-notes.md`）
- 约束：集成方式遵循 ADR-004（NPU core + AXI 桥接，不做完整 SoC）；host 侧驱动方式视板卡能力（Zynq PS / MicroBlaze / JTAG 驱动 / 状态机主控）在任务内细化并记录

## 验收标准
1. 板卡上 NPU core 成功执行自定义测试程序（T007 的 ELF 或等价程序），结果通过 AXI 读回（或 UART/LED 等板载外设输出）
2. 上板结果与 Verilator/Cocotb 仿真结果一致（数值级），记录对照表
3. 记录完整验证链路：ELF → TCM 加载 → 运行 → 结果读回的命令/脚本（主仓库 `sim/` 或 `synth/` 下可复现）
4. 说明与上游 SoC 验证的差异（ADR-004 影响）与覆盖范围

## 完成区
**状态**：待开始
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：

## 审阅记录

#### 第 1 轮 engineer 自审
（工程师自审 subagent 的意见、问题、判决及 finding 处置）

#### 第 1 轮 reviewer 验收
（审查者独立验证的重跑记录、约束核验、判决；Needs Revision 返工后，下一轮标 `第 2 轮`）
