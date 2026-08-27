# T025: 第二轮评测（15 超限用例 + 可选扩展）

## 目标
评测 M4 第一轮超限的 15 个用例（gemma/highmem），完成 RVV 评测完整性。

## 15 超限用例需求（已查证，ELF 段实测）

| 用例 | ITCM | DTCM（0x100000） | DDR（0x80000000） |
| --- | --- | --- | --- |
| rvv_bf16_flashattention | 6K | 1MB | 5MB |
| rvv_bf16_matmul | 1K | 1MB | 2MB |
| rvv_bf16_residual_add | 1K | 1MB | 96K |
| rvv_bf16_rms_norm | 1K | 1MB | — |
| rvv_bf16_tanh_gelu_mul | 1K | 1MB | 96K |
| rvv_flashattention_test | 6K | 1MB | **10MB** |
| rvv_int8_matmul | 1K | 1MB | — |
| rvv_matmul（gemma） | 1K | 1MB | 3.5MB |
| rvv_residual_add | 1K | 1MB | 1.9MB |
| rvv_rms_norm | 1K | 1MB | — |
| rvv_tanh_gelu_mul | 1K | 1MB | 6MB |
| rvv_matmul_assembly_highmem | 1K | 1MB | — |
| rvv_matmul_assembly_itcm512kb | 1K | 512K | — |
| rvv_matmul_highmem | 1K | 1MB | — |
| rvv_matmul_itcm512kb_dtcm512kb | 1K | 512K | — |

**结论**：
- ITCM 都小（1-6K，8K 够）——**ITCM 无需扩容**（highmem 配置 1M/1M 是统一参数，实际 ITCM 用不到）
- **TCM 扩容到 1M/1M**：能评测 8 个纯 1MB DTCM 用例（rms_norm/int8_matmul/matmul_highmem 等）
- **7 个含 DDR 数据段**（0x80000000，5-10MB）——**必须 DDR** 才能评测

## TCM 扩容资源影响（BRAM）

| 配置 | RAMB36（共 1292） |
| --- | --- |
| 当前（8K+32K + SRAM 256K） | 74（5.73%） |
| 512K/512K | ~300（23%） |
| **1M/1M（highmem）** | ~530（41%） |

- BRAM 余量充足；LUT/FF 几乎不变
- 与 VME（LUT）资源类型不同，可叠加

## DDR 依赖分析

- **DDR 数据来源**：ELF 的 `.ddr_data` 段（0x80000000）——**编译时嵌入的初始数据**（gemma q/k/v/o_buf 大数组）
- 加载量：flashattention 10MB @115200 ≈ **15min**（慢）
- 需：DDR 存在 + load_elf 支持写 0x80000000 段
- **SRAM 与 DDR 无依赖**：评测用例无一个链接到 SRAM（0x20000000）——SRAM 256K 对评测非必需（完整 SoC 可保留）

## 方向顺序建议（2026-08-26 评估）

1. **TCM 扩容（1M/1M）**：评测 8 个 1MB 用例——改动小、低风险、M4 收尾
2. **DDR**：评测 7 个 DDR 用例——架构改动大（MIG/CDC），且 10MB 加载慢
3. **VME 已评估暂缓**：coralnpu 未实现 mmac/mred 矩阵计算指令——当前无性能加速价值（见 vme-analysis.md）

## 可选扩展
- tests/cocotb 顶层核级测试（vector_store_fault 等）
- fpga/sw 外设测试（clint/gpio，借鉴外设库+测试分离模式）
- litert-micro 推理算子（conv/pooling）

## 完成区
**状态**：待开始
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：
