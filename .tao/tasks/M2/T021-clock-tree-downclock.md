# T021: 时钟树分析与降频实验（20M/10M）

## 目标
生成时钟树，分析各时钟域；评估是否可降到 **20MHz 甚至 10MHz**。

## 执行环境
**202**（综合）+ **201**（上板）。命令由用户执行。

## 输入
1. T018 的 50MHz 综合结果（timing 报告 + post_synth.dcp）
2. `synth/rtl/top_coralnpu.sv`（MMCM 配置 g_mmcm）
3. `synth/xdc/top_coralnpu.xdc`

## 子任务
1. **生成时钟树**：report_clocks / clock utilization rpt——核时钟、UART 时钟、各时钟域来源与关系
2. **分析各时钟域**：MMCM 输入（板上 100M？）→ 输出（核时钟 40M/50M）、UART 时钟来源；跨时钟域
3. **降频实验**：50M → 20M → 10M 变体综合
   - **注意 MMCM 约束坑**（T017 曾失败）：XDC 输入约束与 MMCM 参数（CLKIN1_PERIOD）冲突会导致 VCO 超范围——需正确处理约束方式
4. **对比**：各频率时序余量（WNS/WHS）、是否影响 UART/核功能

## 约束
1. 综合命令由用户执行；每个频率变体独立 subtask 目录（`workspace/T021-<freq>/`）
2. 上板验证降频后功能（UART 波特率是否需调整）

## 验收标准
1. 时钟树报告 + 时钟域分析完成
2. 20M/10M 综合结果（成功 or 明确失败原因）
3. 降频对功能/时序的影响结论

## 完成区
**状态**：✅ 完成（2026-08-26，20M 部分；10M 挂起待需要时）
**Commit**：
**测试结果**：
- **时钟树分析**：单时钟域 `clk_mmcm_out`（50M→20M），输入 100M（s2cclk_1），MMCM 输出经 BUFG → clk_core；无跨时钟域/CDC
- **20M 实验**：综合成功（~32min）；**WNS +13.848 / WHS +0.026，0 违例完全收敛**；上板 t007_scalar **ALL PASS**（UART 115200 正常，rx DIV=11 误差 1.4% 无影响）
- **频率对比**：50M（T018）WNS -0.175~-0.875 违例 vs **20M WNS +13.848 收敛**——降频彻底解决时序问题
**修改文件**：
- `synth/rtl/top_coralnpu.sv`：MMCM CLKOUT0_DIVIDE_F + CORE_CLK_HZ（50M→20M，DIVIDE 24→60）
**验收结果**：
- **20M 为后续默认频率**（用户决策）：时序收敛 + 功能验证 + UART 正常
**新发现/坑**：
1. **降频正确方法 = 改 MMCM 输出分频（CLKOUT0_DIVIDE_F），VCO 1200M 不变**；T017 曾错误地改 XDC 输入约束致 VCO 计算 240M 超下限失败
2. 降频对 UART 影响：rx 16x 过采样 DIV 变小（20M 时 11，误差 1.4% OK；10M 时 5，误差 8.5% 风险）
3. 时钟域为单域（UART 用 clk_core 分频），无 CDC——后续完整 SoC 加 DDR 域才引入 CDC
**遗留问题**：
- **10M 实验挂起**：10M 时 UART rx 误差 8.5% 可能不稳（除非改 uart_rx 过采样系数或调波特率）；待需要时再综合/测试
- chip_nexus 多时钟域（6 域）为 Nexus 平台设计，DualV7 按硬件裁剪（ISP 裁、SPI 视需要、DDR3 适配）——见 soc-analysis §6

## 审阅记录
（engineer 自审 + reviewer 验收）
