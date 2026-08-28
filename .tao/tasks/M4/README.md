# M4（Milestone 4）

第四阶段。目标：**内存系统扩展**——扩容 TCM、CSR 适配、增加 DDR，评测 M3 遗留的 15 个 highmem/gemma 超限用例。

## 背景（2026-08-26 重组）
- **M3 结束 = T024**：默认 SoC（8K/32K）完成 606 用例评测（100% 通过率）+ matmul 性能分析
- M4 承接 M3 遗留：15 个超限用例（gemma 11 + highmem 4）需更大内存
- **关键认知**：
  - 超限原因 = DTCM 需 1M（0x100000）或 DDR（0x80000000）；ITCM 都小（1-6K）
  - SoC 自动布局规则（SoCChiselConfig）：`dtcm≠32K` → 自动切 **highmem 布局**（ITCM@0x0 + DTCM@0x100000 + CSR@0x200000）
  - highmem 布局 CSR 从 0x30000 **移到 0x200000** → 评测框架需适配
  - DDR 数据来源 = ELF `.ddr_data` 段（编译时嵌入，如 flashattention 10MB @115200 ≈ 15min 加载）

## 任务划分

| 任务 | 内容 | 状态 |
| --- | --- | --- |
| T025 | TCM 扩容 + CSR 适配：SoC 切 highmem 布局（64K/1M）→ 评测 7 个无 DDR 用例（gemma 3 + highmem 4） | 进行中（route 拥塞攻坚） |
| T026 | SPI 加载（方案 B：host 实时 SPI 灌入）：spi2tlul → Xbar → 内存，大用例加载 15min→秒级 | 待开始 |
| T027 | DDR 增加：上游规划（ddr_ctrl/ddr_mem + clockDomain=ddr）+ MIG + TLUL2Axi → 评测 8 个 DDR 用例 | 待开始 |

## 15 超限用例分布

- **无 DDR 7 个**（T025 目标）：rvv_rms_norm、rvv_bf16_rms_norm、rvv_int8_matmul（gemma）；rvv_matmul_highmem、rvv_matmul_assembly_highmem、rvv_matmul_itcm512kb_dtcm512kb、rvv_matmul_assembly_itcm512kb_dtcm512kb（highmem）
- **含 DDR 8 个**（T026 目标）：rvv_matmul、rvv_residual_add、rvv_tanh_gelu_mul、rvv_bf16_matmul、rvv_bf16_residual_add、rvv_bf16_tanh_gelu_mul、rvv_flashattention_test、rvv_bf16_flashattention

## 关键结论（已固化）
- **VME 暂缓**：coralnpu 未实现 mmac/mred 矩阵计算指令（PE 阵列硬件空置）——当前无性能加速价值（见 knowledge/vme-analysis.md）
- **TCM 资源**：1M DTCM ≈ 265 RAMB36（21%），8K/1M 比 1M/1M 省一半 BRAM（ITCM 实际只用 1-6K）
- **SRAM 与 DDR 无依赖**：评测用例无链接到 SRAM（0x20000000）

## 完成区
- M3/T024：606 默认用例评测（见 M3/T024-rvv-benchmark.md）
