# T027: DDR 增加（评测 8 个 DDR 超限用例）

## 目标
SoC 增加 DDR 通路（0x80000000），评测 8 个 gemma DDR 用例（matmul/attention 大算子）。

## 8 个目标用例（含 DDR 数据）

| 用例 | DDR 数据量 |
| --- | --- |
| rvv_matmul | 3.5MB |
| rvv_residual_add | 1.9MB |
| rvv_tanh_gelu_mul | 6MB |
| rvv_bf16_matmul | 2MB |
| rvv_bf16_residual_add | 96K |
| rvv_bf16_tanh_gelu_mul | 96K |
| rvv_flashattention_test | 10MB |
| rvv_bf16_flashattention | 5MB |

## 背景（已查证）
- **DDR 数据来源**：ELF `.ddr_data` 段（0x80000000）——编译时嵌入的初始数据（q/k/v/o_buf 大数组）
- **加载成本**：10MB @115200 ≈ **15min**（最慢的 flashattention）
- 需扩展 load_elf 支持写 0x80000000 段
- **SRAM 与 DDR 无依赖**：评测用例无链接到 SRAM（0x20000000）

## 待细化方案（2026-08-26 占位）
- MIG（DDR3 内存控制器）生成 + TLUL2Axi 桥（0x80000000 → DDR）+ 多时钟域 CDC
- 地址映射：Xbar 增加 ddr 端口（0x80000000），host 可写 + 核可读写
- load_elf 支持 DDR 段（W 命令写到 0x80000000）
- 评测框架：CSR 地址（highmem 布局 0x200008）+ 加载超时适配（10MB 15min）

## 风险
- 多时钟域 CDC 复杂（DualV7 DDR3 引脚/时钟资源需查 docs）
- 加载慢（15min/大用例）——评测时间成本高
- MIG 综合/实现复杂度高

## 完成区
**状态**：待开始（T025 完成后细化）
**Commit**：
**测试结果**：
**验收结果**：
**新发现/坑**：
**遗留问题**：
