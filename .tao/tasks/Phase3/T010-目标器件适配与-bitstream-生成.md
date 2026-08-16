# T010: 目标器件适配与 bitstream 生成

## 执行环境
**执行环境**：远端（待确认 · 综合服务器）＋ 本地

## 接口规范
- 输入：板卡已确认 = S2C Dual Virtex-7 TAI Logic Module（器件具体型号见 `.tao/knowledge/board-notes.md`，待 PDF 确认）；T009 跑通的官方器件工程；coralnpu fpga/ 参考 XDC（pins_nexus.xdc）
- 输出：适配目标器件的 Vivado 工程；实现（place&route）完成；生成 bitstream
- 约束：适配覆盖层放主仓库 `synth/`（XDC、时钟约束、IP 覆盖、tcl 补丁），不改上游 core 文件（确需改按 ADR-003 走 fork）；时钟/IP 变更需评估是否引入新 IP 及 license

## 验收标准
1. 目标器件已确认并记录（板卡型号 → 器件型号 → Vivado 支持情况）
2. 工程目标器件切换为目标器件，综合/实现无 ERROR
3. 适配内容说明：引脚约束（XDC）、时钟约束/时钟 IP、任何需要替换或禁用的 IP（如与 Nexus 专用外设相关的），全部沉淀到 `.tao/knowledge/synth-notes.md`
4. bitstream 成功生成（`.bit`/`.bin` 路径明确），实现无 critical warning 导致的失败
5. 资源/时序报告生成（供 T011 分析与 T012 上板）

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
