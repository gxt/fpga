# T028: DDR 用例评测 + 全面评测（621 全量）

## 目标
在 DDR SoC（T027 完成）上评测 8 个 DDR 用例 + **全量 621 用例全面评测**。

## 8 个 DDR 用例（0x80000000 数据）

| 用例 | DDR 数据量 |
| --- | --- |
| rvv_matmul | 3.5MB |
| rvv_residual_add | 1.9MB |
| rvv_tanh_gelu_mul | 6MB |
| rvv_bf16_matmul | 2MB |
| rvv_bf16_residual_add | 96K |
| rvv_bf16_tanh_gelu_mul | 96K |
| rvv_flashattention_test | **10MB** |
| rvv_bf16_flashattention | 5MB |

## 全面评测（621 全量）

M3/T024 只测默认 606；T025 测 7 个无 DDR 超限；T028 测 8 个 DDR——**DDR SoC 上全量 621 覆盖**：

| 批次 | 用例 | 状态 |
| --- | --- | --- |
| 默认 606 | T024 已测（604 PASS + 2 预期 fault） | ✅ |
| 无 DDR 7 个 | T025（rms_norm/int8_matmul/highmem matmul 等） | T025 |
| **DDR 8 个** | T028 本轮 | 本轮 |

**全面评测含义**：DDR SoC（64K/1M + DDR）上跑**全量 621**（含默认 606 回归 + 15 超限）——确认 DDR 加装不破坏已有功能 + 15 超限全部覆盖。

## 工作清单
1. bench_rvv.py：段判断加 0x80000000（DDR 段）+ 加载超时适配（10MB/15min 或 SPI）
2. 8 个 DDR 用例评测（性能模式，matmul 周期回读）
3. 全量 621 回归（默认 606 + 超限 15）
4. 性能分析更新（含 DDR 用例 matmul/attention MACs/Cycle）

## 加载方式
- UART（慢，15min/10MB）或 T026 SPI（秒级，推荐）

## 完成区
**状态**：待开始（依赖 T027）
**Commit**：
**测试结果**：
**验收结果**：
**新发现/坑**：
**遗留问题**：
