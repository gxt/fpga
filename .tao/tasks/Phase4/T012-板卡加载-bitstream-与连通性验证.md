# T012: 板卡加载 bitstream 与连通性验证

## 执行环境
**执行环境**：本地（本机直接连接板卡）

## 接口规范
- 输入：T010 生成的 bitstream；板卡（本机连接）；Vivado Hardware Manager（本机 Vivado 辅助角色）或板卡厂商烧录工具
- 输出：bitstream 成功加载到板卡；器件识别、时钟/复位基本功能验证记录（`.tao/knowledge/board-notes.md`）
- 约束：操作遵循板卡上电/复位流程（参考官方 fpga/README 的 reset 概念：区分硬复位/软复位）；记录板卡配置（JTAG 链、时钟源、供电）

## 验收标准
1. Vivado Hardware Manager（或等效工具）识别器件并成功加载 T010 bitstream，无错误
2. 加载后基本连通性验证通过：读取器件状态/IDCODE 正确；时钟输出或已知寄存器/引脚行为符合预期（视板卡能力，至少验证 FPGA 已配置）
3. 记录 bitstream 加载方式（JTAG/SPI/其他）、耗时、所需外部连接（如复位按钮、时钟源）
4. 若加载失败，记录排查过程与根因，返回 T010 调整

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
