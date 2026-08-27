# M4（Milestone 4）

第四阶段。目标：**完成所有 RVV 测试用例评测 + 实际性能分析**（官方 MACs/Cycle 指标 + 理论对比）。

## 背景
- M3 已完成：完整 SoC（CoreTlul + CoralNPUXbar + RVV）在 DualV7 上板跑通，20MHz
- M4 对 RVV 核做系统性评测

## 任务划分

| 任务 | 内容 | 状态 |
| --- | --- | --- |
| T024 | 评测框架 + 第一轮（现有 bit）：621 ELF 构建、606 全测（604 PASS + 2 预期 fault FAIL）、matmul 性能（MACs/Cycle 7-25%）、wfi 唤醒方案 | ✅ |
| T025 | TCM 扩容 + 第二轮：15 超限用例（gemma/highmem）评测 | 待开始 |

## 关键成果
- 评测框架：tests/rvv_bench/（bench_rvv.py/seg_analysis.py/elf_segments.json）
- wfi 唤醒方案（CLINT MTIMECMP 触发定时器中断）
- 全量 606 评测：正常用例通过率 100%
