# T012: 板卡加载 bitstream 与连通性验证

## 执行环境
**执行环境**：机器201（机器201直接连接板卡）

## 接口规范
- 输入：T010 生成的 bitstream（core_mini_axi + AXI 桥接版）；板卡（机器201连接）；Vivado Hardware Manager（机器201 Vivado 辅助角色）或板卡厂商烧录工具
- 输出：bitstream 成功加载到板卡；器件识别、时钟/复位基本功能验证记录（`.tao/knowledge/board-notes.md`）
- 约束：**板卡配置/复位机制以 `.tao/knowledge/board-notes.md` 为准**（S2C TAI LM：JTAG 走 J24 标准 Xilinx 14-pin；配置方式为 JTAG / USB（TAI Player）/ SD card / Ethernet，由 Spartan-6 控制器管理电源、时钟与配置；状态指示 LED1=F1_DONE、LED11=F2_DONE）；不使用官方 Nexus 专用配置机制；操作遵循板卡上电/复位流程并记录板卡配置（JTAG 链、时钟源、供电）

## 验收标准
1. Vivado Hardware Manager（或 TAI Player 等等效工具）识别器件并成功加载 T010 bitstream，无错误
2. 加载后基本连通性验证通过，判定具体化：**读取器件 IDCODE 正确（与 xc7v2000t 对应），且观察到可验证行为（LED1/F1_DONE 点亮、或时钟/DONE 引脚状态符合预期）**；记录实测现象，不泛泛写"正常"
3. 记录 bitstream 加载方式（JTAG J24 / TAI Player / 其他）、耗时、所需外部连接（如复位按钮、时钟源）
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
