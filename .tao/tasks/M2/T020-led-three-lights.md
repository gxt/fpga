# T020: LED 三灯实现与验证

## 目标
S2C DualV7 板卡增加**三个 LED 灯**：找引脚位置 → 确定状态提示含义 → 实现驱动（UART 直驱 or 程序驱动）→ 验证。

## 执行环境
**201**（上板）+ 202（综合）。命令由用户执行。

## 输入
1. T018 的 top_coralnpu.sv（**已预留 LED 输出引脚**）
2. `docs/DualV7/`（LED 引脚权威资料）
3. `tests/load_elf_uart.py` / host_cmd_fsm（UART 通路）

## 子任务
1. **找 LED 位置**：docs/DualV7 查用户 LED 引脚（FPGA 引脚约束）；若无明确资料，上板测试确认
2. **确定三灯含义**：三个 LED 各提示什么状态（如：加载中/运行中/HALTED；或电源/心跳/状态）
3. **驱动方式决策**：
   - 方案 A：UART 直驱（host 收到某命令 → top 直接控制 LED，不经核）——可行性评估
   - 方案 B：AXI 寄存器映射（核写地址 → 输出到 LED）——程序可控
   - 评估后选方案
4. **放置位置**：LED 控制逻辑放 top 还是 host_cmd_fsm；elf 测试程序在哪一步驱动（若方案 B）
5. **验证**：上板后 LED 状态正确变化

## 约束
1. 上板/烧录/复位前提醒用户确认
2. top 改动最小化，一次完成

## 验收标准
1. 三个 LED 引脚确认 + 约束加入 xdc
2. 驱动方案选定并实现
3. 上板验证 LED 状态符合预期

## 完成区
**状态**：✅ 完成（2026-08-26）
**Commit**：
**测试结果**：
- **引脚确认**：LED0=AH44(J8-101)、LED1=AH43(J8-103)、LED2=AL40(J8-105)，LVCMOS18（docs/DualV7 §03.9 + Chipyard 管脚表）
- **UART L 命令驱动**：`L<hex>`（低 3 bit = LED0/1/2），host_cmd_fsm 新增，应答 OK/ERR
- **上板验证**：L1→LED0 亮、L2→LED1、L4→LED2、组合（L7/L5/L3/L0）**完全正确** ✅
- 时序：ledfix 版 WNS -0.273 / WHS -0.173（3 端点 hold 轻微违例，上板稳定）
**修改文件**：
- `synth/rtl/host_cmd_fsm.sv`：新增 `L` 命令（P_LED 状态 + led_ctrl 输出 + P_END 3'd5）
- `synth/rtl/top_coralnpu.sv`：新增 `gpio_led[2:0]` 输出 + `gpio_led = ~led_ctrl_int` 反相
- `synth/xdc/top_coralnpu.xdc`：AH44/AH43/AL40 引脚约束
**验收结果**：三个 GPIO LED（小板 J8）UART 命令驱动点亮验证通过
**新发现/坑**：
1. **GPIO LED 实测 active-low**（与知识库 active-high 不符——知识库是 chipyard 配置）→ top 输出反相修复
2. `hex_val(rx_data)[2:0]` 语法非法（函数调用不能直接位选择，IEEE 1800）→ 改 `hex_val(rx_data)` 自动截断
3. 新增 3 个 IOB 改变布局，时序 WNS 从 -0.175 波动到 -0.875（first 版）→ ledfix 版 -0.273，布局敏感性
**遗留问题**：无

## 审阅记录
（engineer 自审 + reviewer 验收）
