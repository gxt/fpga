# T012: 板卡加载 bitstream 与连通性验证

## 执行环境
**执行环境**：机器201（机器201直接连接板卡）

## 接口规范
- 输入：**T010 修正后 bitstream**（`synth/out/T010-fix-clk/top_coralnpu.bit`，md5 `35624576...`，时钟 L4/L3 + UART AV42/AU42 修正版，2026-08-20 硬件工程师确认）；板卡（机器201连接）；Vivado Hardware Manager（机器201）或板卡厂商烧录工具
- 输出：bitstream 成功加载到板卡；器件识别、时钟/复位基本功能验证记录（`.tao/knowledge/board-notes.md`）
- 约束：**板卡配置/复位机制以 `.tao/knowledge/board-notes.md` 为准**（S2C TAI LM：JTAG 走 J24 标准 Xilinx 14-pin；配置方式为 JTAG / USB（TAI Player）/ SD card / Ethernet，由 Spartan-6 控制器管理电源、时钟与配置；状态指示 LED1=F1_DONE、LED11=F2_DONE）；不使用官方 Nexus 专用配置机制；操作遵循板卡上电/复位流程并记录板卡配置（JTAG 链、时钟源、供电）
- **上板前置确认（2026-08-20 硬件工程师信息）**：① 时钟源 = **s2cclk_1（L4/L3，JG1/JG2 连接器）100MHz 差分**，需确认 S2C 可编程时钟已输出 100MHz；② 复位 = **SW1（AP31，低有效）**；③ UART 走子板 AV42/AU42（本任务不涉及，T015 用）

## 验收标准
1. Vivado Hardware Manager（或 TAI Player 等等效工具）识别器件并成功加载 **T010 修正后 bitstream**（`T010-fix-clk/top_coralnpu.bit`），无错误
2. 加载后基本连通性验证通过，判定具体化：**读取器件 IDCODE 正确（与 xc7v2000t 对应），且观察到可验证行为（LED1/F1_DONE 点亮、或时钟/DONE 引脚状态符合预期）**；记录实测现象，不泛泛写"正常"
3. 记录 bitstream 加载方式（JTAG J24 / TAI Player / 其他）、耗时、所需外部连接（复位按钮 SW1、时钟源 s2cclk_1 L4/L3 100MHz、供电）
4. 若加载失败，记录排查过程与根因，返回 T010 调整

## 完成区
**状态**：待验收（烧录与连通性验证完成）
**Commit**：无（脚本 `synth/tcl/program_top.tcl` 待主会话提交）
**测试结果**：
- Vivado Hardware Manager（机器201，batch）连接 cable `Digilent SULEE2211346A`，识别器件 `xc7v2000t_0`（PART xc7v2000t）
- IDCODE `00100011011010110011000010010011`（有效）
- `program_hw_devices` 加载 `T010-fix-clk/top_coralnpu.bit` 成功（32s），**`End of startup status: HIGH`（DONE 拉高）**
- **LED1（F1_DONE）点亮**（用户人工观察确认）
**修改文件**：
- 新建 `synth/tcl/program_top.tcl`（Hardware Manager 烧录/识别脚本，probe/program 两模式）
**验收结果**：
1. ✅ 识别器件并成功加载 T010 修正后 bit，无错误（DONE HIGH）
2. ✅ IDCODE 正确（xc7v2000t）+ LED1/F1_DONE 点亮
3. 加载方式 JTAG J24（Digilent cable）、耗时 32s、外部连接：SW1 复位 / s2cclk_1(L4/L3) 100MHz 时钟 / 供电
4. ✅ 无失败
**新发现/坑**：
- `verify_hw_devices` 需 `.msk` mask 文件（build_top.tcl 未生成），已加 catch 容错（烧录本身成功，verify 可选）
- `get_property STATE` 在烧录前不可用（已移到烧录后 catch）
- **LED 引脚待修正（T013 前）**：设计内 led_halted/fault/locked（K25/K28/J28，高电平点亮）与硬件工程师子板 GPIO LED（AH44/AH43/AL40，低电平点亮）不符
**遗留问题**：
- LED 引脚修正（XDC → AH44/AH43/AL40 + 极性反相，机器202 重综合）留待 T013 前执行

## 审阅记录

#### 第 1 轮 engineer 自审
（工程师自审 subagent 的意见、问题、判决及 finding 处置）

#### 第 1 轮 reviewer 验收
（审查者独立验证的重跑记录、约束核验、判决；Needs Revision 返工后，下一轮标 `第 2 轮`）
