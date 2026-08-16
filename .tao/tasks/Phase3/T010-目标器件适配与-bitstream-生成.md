# T010: 目标器件适配与 bitstream 生成（core_mini_axi + AXI 桥接）

## 执行环境
**执行环境**：远端（综合服务器）＋ 本地

## 接口规范
- 输入：目标器件已确认 = `xc7v2000tflg1925-1`（S2C Dual Virtex-7 TAI Logic Module，见 `.tao/knowledge/board-notes.md`，无需再以 PDF 确认）；bazel 生成的 `core_mini_axi` SystemVerilog（`//hdl/chisel/src/coralnpu:core_mini_axi_cc_library`）；T008 执行拓扑；T009 官方器件（xcvu13p）综合基线报告
- 输出：**面向上板的 AXI 桥接顶层 + S2C 引脚/时钟适配的 Vivado 工程**；实现（place&route）完成；**直接产出上板用 bitstream（`.bit`/`.bin` 路径明确）**
- 范围：**不做 chip_nexus 完整 SoC 移植**（与 ADR-004 一致）；工作内容 = core_mini_axi 的 AXI 桥接顶层（含 host 侧接口、外设或调试口引出，方案与 T013 对齐）+ S2C 板卡引脚约束（XDC）+ 时钟源/复位适配
- 约束：适配覆盖层与自建顶层放主仓库 `synth/`（XDC、时钟约束、IP 覆盖、tcl 补丁），不改上游 core 文件（确需改按 ADR-003 走 fork）；时钟/IP 变更需评估是否引入新 IP 及 license（全功能 license 已确认覆盖 xc7v2000t，验证能识别即可）；**本任务工作量大，允许跨会话分段执行，每段记录 checkpoint（阶段、已完成项、产物、下一步）到任务完成区**

## 验收标准
1. 目标器件确认记录已存在（board-notes.md 中 `xc7v2000tflg1925-1`），Vivado 支持情况已验证
2. 工程目标器件为 `xc7v2000tflg1925-1`，综合/实现无 ERROR
3. 适配内容说明：AXI 桥接顶层设计（接口、host 侧方案）、引脚约束（XDC）、时钟约束/时钟 IP、任何需要替换或禁用的 IP，全部沉淀到 `.tao/knowledge/synth-notes.md`
4. bitstream 成功生成（`.bit`/`.bin` 路径明确）；**对实现中的 critical warning 逐条分类记录**（类别、数量、是否影响功能、处置结论），不笼统表述为"无 critical warning 导致的失败"
5. 资源/时序报告生成（供 T011 分析与 T012 上板），并标注与 T009 官方基线（xcvu13p）的对比位置
6. 若分段执行，完成区记录各段 checkpoint，每段结束时状态与产物可追溯

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
