# T024: RVV 用例评测框架 + 第一轮（现有 M3 bit，20MHz）

## 目标
完成 RVV 测试用例评测 + 实际性能分析（官方 MACs/Cycle 指标 + 理论对比，方案 B）。

## 评测框架（已建立）
- **构建**：621 个 RVV ELF（bazel，`//tests/cocotb/rvv/...`，coralnpu_v2_binary）
- **段统计**：606/621 默认 TCM(8K/32K) 能跑；15 超限（gemma/highmem/itcm512kb——需 TCM 扩容）
- **自动分流**：有 `csr_cycle_count` 符号 → 性能模式（matmul），无 → smoke 模式（wfi 类）
- **判定**：性能 = HALTED + cycles 回读；smoke = 加载 + S 启动 + 无 fault
- **复位方案**：加载时核**保持复位**（CTRL=1 不释放），S 释放启动——避免核运行占用 TCM 仲裁

## 第一轮结果（2026-08-26，8 个 matmul 全 PASS）
`workspace/T024-first/bench_result.md`（性能报告）

| matmul | 类型 | MACs | cycles | MACs/Cycle | 理论 | 效率 |
| --- | --- | --- | --- | --- | --- | --- |
| rvv_bf16_matmul | bf16 | 12288 | 21958 | 0.56 | 8 | 7.0% |
| rvv_float_matmul | f32 | 12288 | 25982 | 0.47 | 4 | 11.8% |
| rvv_float_matmul_assembly | f32 | 12288 | 27276 | 0.45 | 4 | 11.3% |
| rvv_float_matmul_optimized | f32 | 12288 | 12141 | 1.01 | 4 | **25.3%** |
| rvv_matmul | i8 | 131072 | 66726 | 1.96 | 16 | 12.3% |
| rvv_matmul_assembly | i8 | 131072 | 71972 | 1.82 | 16 | 11.4% |
| float_matmul_16x48x16 | f32 | 12288 | 25980 | 0.47 | 4 | 11.8% |
| int_matmul_16x48x16 | i8 | 12288 | 10848 | 1.13 | 16 | 7.1% |

**初步结论**：
- 实测 MACs/Cycle 7-25%（远低于理论）——数据加载（vle/vse）/循环开销 + RVV 流水线效率
- optimized 版效率最高（25.3%）；int8 效率低（7-12%）

## 关键发现/坑
1. **wfi 类用例**（rvv_add.S 等汇编）用 `wfi` 结束（无 HALTED）——不能用 HALTED 判定，需 smoke
2. **reset 释放后核立即运行**（占用 TCM 仲裁）→ 加载下个程序卡 → 改"加载时保持复位"
3. **wfi 类用例后核时钟门控**（cg disable，CoreAxi L109）→ host 写卡
4. **wfi 唤醒方案（已验证）**：host 写 CLINT MTIMECMP（0x02004000，触发 timer_irq）→ 核时钟恢复 → host 写正常 → **wfi 类连续评测可行**（混合批量 6 个全 PASS）
5. matmul（HALTED 类）连续评测可行（return 0 → mpause）

## 遗留问题
- wfi 类（598 个）通过性：待决策（cocotb 已验证 / 上板抽样每用例重烧）
- 15 个超限用例（gemma/highmem）：需 TCM 扩容（第二轮 T025）
- 执行时间 wall 测量受 0.1s 轮询粒度影响（cycles 准确）

## 完成区
**状态**：✅ 第一轮完成（2026-08-26）
**Commit**：
**测试结果**：606 个全测，**604 PASS + 2 FAIL（均故意 fault 测试）**，正常用例 100% 通过
**修改文件**：`tests/rvv_bench/`（bench_rvv.py/seg_analysis.py/elf_segments.json 评测工具）
**验收结果**：
- 评测框架建立：构建 621 ELF + 段统计 + 自动分流（性能/smoke）+ wfi 唤醒 + 周期回读
- 全量 606 个：604 PASS + 2 预期 FAIL（load_store8_fault/vill_test，故意 fault）
- matmul 性能：8 个 cycles → MACs/Cycle 7-25%（optimized 25.3% 最高）
- wfi 类连续评测解决（CLINT MTIMECMP 唤醒）
**新发现/坑**：
- wfi 类用例用 wfi 结束（无 HALTED）→ smoke 模式
- wfi 后核时钟门控 → CLINT MTIMECMP 触发定时器中断唤醒
- 加载时核保持复位（CTRL=1），S 释放启动
- 2 个 FAIL 是故意 fault 测试（load_store8_fault/vill_test），预期
**遗留问题**：15 个超限用例（gemma 11 + highmem 4）待 T025（TCM 扩容）；可选扩展 tests/cocotb 顶层核级测试
