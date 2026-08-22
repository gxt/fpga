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
**状态**：已验证（reviewer 第 1 轮 Accepted + Mimo 交叉复核确认）
**Commit**：83202ff（`scripts/program_top.tcl` 已提交）
**测试结果**：
- Vivado Hardware Manager（机器201，batch）连接 cable `Digilent SULEE2211346A`，识别器件 `xc7v2000t_0`（PART xc7v2000t）
- IDCODE `00100011011010110011000010010011`（有效）
- `program_hw_devices` 加载 `T010-fix-clk/top_coralnpu.bit` 成功（32s），**`End of startup status: HIGH`（DONE 拉高）**
- **LED1（F1_DONE）点亮**（用户人工观察确认）
**修改文件**：
- 新建 `scripts/program_top.tcl`（Hardware Manager 烧录/识别脚本，probe/program 两模式）
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

**验证范围与证据等级**：本任务为**真实上板任务**。审查中发现本机（fpga201）实际连接板卡（hw_server 在 localhost:3121 可访问，cable `Digilent SULEE2211346A`），因此**验收命令被我真实重跑**（非仅读日志），证据等级为"独立重跑"；唯一不可重跑项为 LED1 点亮（用户人工观察），采信用户反馈并以 DONE HIGH（同源信号）佐证。

**代码 review `scripts/program_top.tcl`**（74 行，commit 83202ff 已提交）：
- probe/program 两模式参数解析正确（`-tclargs <bit> [probe]`）
- cable 未找到（`get_hw_targets` 空）→ exit 1；JTAG 链无器件 → exit 1；bit 文件不存在 → exit 1，错误处理完整
- verify 用 `catch` 容错（无 `.msk` 时跳过不阻断烧录）——**真实重跑证实**：`ERROR: [Labtools 27-3124] No maskfile assigned to hw_bitstream` 被 catch，脚本继续且 exit=0
- STATE 属性读取移入烧录后 `catch`——**真实重跑证实**：烧录后 STATE 仍不可读，被 catch 为非致命
- tcl 语法 + mock 逻辑检查（tclsh）两模式均 exit=0

**重跑记录（本 reviewer 独立执行，真实 Vivado 2025.1）**：

1. probe 模式（`vivado -mode batch -source program_top.tcl <bit> probe`）：
   ```
   ==> 器件 NAME: xc7v2000t_0
   ==> 器件 PART: xc7v2000t
   ==> 器件 IDCODE: 00100011011010110011000010010011
   ==> probe 完成（未烧录）
   INFO: [Common 17-206] Exiting Vivado ...
   exit=0
   ```
   → 与完成区 IDCODE 记录逐位一致。

2. program 模式（烧录，`vivado -mode batch -source program_top.tcl <bit>`）：
   ```
   ==> 器件 IDCODE: 00100011011010110011000010010011
   INFO: [Labtools 27-3164] End of startup status: HIGH
   program_hw_devices: Time (s): cpu = 00:00:31 ; elapsed = 00:00:32 . Memory (MB): ...
   ==> verify 跳过（ERROR: [Labtools 27-3124] No maskfile assigned to hw_bitstream）——烧录本身已成功（End of startup status: HIGH）
   ==> STATE 属性不可读（非致命）
   ==> T012 program DONE
   INFO: [Common 17-206] Exiting Vivado ...
   exit=0
   ```
   → DONE HIGH、耗时 32s、verify 跳过原因与完成区完全一致；完整输出留存 `.tao/logs/T012-review-probe.log` / `.tao/logs/T012-review-program.log`。

3. IDCODE 对应关系独立验证：UG470 明确 XC7V2000T JTAG IDCODE 模式为 `XXXX_0011_0110_1011_XX11_0000_1001_0011`（bit31:28 版本可变、bit15:14 don't care）。实测 `0010_0011_0110_1011_0011_0000_1001_0011`（=0x236B3093）符合该模式，与 xc7v2000t 对应。✅

4. 输入产物核对：`synth/out/T010-fix-clk/top_coralnpu.bit` 存在，md5 `35624576d3a42ecc09d32bf2ee1076fb`，与接口规范 md5 前缀 `35624576...` 一致。✅

**约束核验**：
- 板卡机制以 board-notes.md 为准：JTAG 走 J24 标准 Xilinx 14-pin ✅（使用 Digilent cable，未见 Nexus 专用机制）
- 不使用官方 Nexus 专用配置机制 ✅（标准 Vivado Hardware Manager JTAG 烧录）
- 操作遵循上电/复位流程并记录板卡配置 ✅（完成区记录 SW1 复位、s2cclk_1(L4/L3) 100MHz 时钟源、12V/5V 供电）
- coralnpu 零改动 ✅（`git diff HEAD~10..HEAD -- coralnpu/` 为空）；`scripts/program_top.tcl` 为新增文件，已提交 83202ff
- 未改契约/spec/测试凑绿：本次改动为新增烧录脚本，无既有验收逻辑被弱化 ✅

**验收标准逐条判定**：
1. ✅ 识别器件（xc7v2000t_0/xc7v2000t）并成功加载 T010 修正后 bit，无错误——**真实重跑**：IDCODE 读出、program 成功、DONE HIGH、exit=0
2. ✅ IDCODE 正确（与 xc7v2000t 对应，UG470 模式匹配）+ LED1/F1_DONE 点亮——IDCODE 独立重跑验证；LED1 点亮采信用户人工反馈，DONE HIGH（同一 F1_DONE 信号）由我重跑证实
3. ✅ 加载方式 JTAG J24（Digilent cable SULEE2211346A）、耗时 32s（真实重跑 elapsed 00:00:32）、外部连接记录（SW1 / s2cclk_1 / 供电）完整
4. ✅ 无失败（真实重跑 exit=0）

**采信项（用户人工部分）**：LED1（F1_DONE）点亮为用户人工观察，reviewer 无法代看；其余全部为 reviewer 独立重跑证据。

**非阻断备注**（不影响验收，供主会话知晓）：任务完成区写"Commit：无（脚本待主会话提交）"，但实际 commit 83202ff 已包含 program_top.tcl（已提交），完成区描述滞后于 git 状态。

**判决**：**Accepted**——验收命令（probe + program）在本 reviewer 真实重跑下全部通过（exit=0），IDCODE/DONE HIGH/32s/verify 跳过与完成区记录逐项一致，四条验收标准均满足，约束无违反。可转架构师终审。

#### 第 1 轮 architect 交叉复核（Mimo）

**复核结论**：**确认 Accepted**，通过收尾。

- 验收标准 4 条全覆盖；reviewer 真实重跑烧录命令（IDCODE/DONE HIGH/32s/verify 容错与完成区逐位一致），证据等级最高
- LED1 点亮（用户人工观察）以同源信号 DONE HIGH 佐证，合理
- program_top.tcl 质量良好（probe/program 两模式、三重错误处理、verify/STATE 容错）；coralnpu 零改动、bit md5 一致
- 补充说明（已收尾处理）：完成区状态/Commit 描述滞后（已更新为已验证 + 83202ff）；LED 引脚修正留待 T013 前
