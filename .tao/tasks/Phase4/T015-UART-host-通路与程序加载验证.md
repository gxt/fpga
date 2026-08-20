# T015: UART host 通路与程序加载验证

## 执行环境
**执行环境**：机器201（板卡连接 + 串口终端）＋ 机器202（如需要产物）

## 接口规范
- 输入：T012 已烧录的 T010 修正后 bitstream（core_mini_axi + UART 状态机 host）；T007 自定义测试程序 ELF（`sim/` 下 t007 程序）；**子板 UART 通路（uart_rx=AV42 / uart_tx=AU42，1.8V，对应 J8 → CH341 `/dev/ttyUSB2`，硬件工程师 2026-08-20）**；串口终端工具（minicom/picocom）
- 输出：UART host 命令通路验证记录（`W/R/S/Q/?` 协议）；加载 T007 ELF 到 TCM 并运行、回读结果与 RTL 仿真对照记录（`.tao/knowledge/board-notes.md`）
- 约束：串口参数 115200 8N1（T010 `host_cmd_fsm` 协议）；host 侧方案已定 = UART 状态机主控（T010 决策，synth-notes.md）；不改 bitstream/上游代码

## 验收标准
1. 串口连通：`?` 返回帮助文本，`Q` 可读状态
2. `S` 引导核启动、`Q` 轮询 CSR_STATUS(0x30008) bit0=HALTED=1 确认核正常停止
3. `W`/`R` 命令读写 DTCM(0x10000)/CSR(0x30000 区域) 一致；**写 ITCM(0x0) 后 S 启动可执行新内容**（若程序从 ITCM 运行则证 ITCM 可改）
4. 加载 T007 ELF（`W` 逐字写 ITCM/DTCM + 数据段）→ `S` 启动 → 回读结果**与机器202 Verilator/Cocotb 仿真位精确一致**（记录预期 vs 实测数值）
5. 记录完整命令序列/脚本（可复现，放主仓库 `sim/` 或 `synth/` 下）

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
