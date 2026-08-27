# T025: TCM 扩容 + CSR 适配（评测 7 个无 DDR 超限用例）

## 目标
SoC 切 highmem 布局（DTCM 1M @0x100000），评测 7 个无 DDR 超限用例，为 M4 内存扩展打基础。

## 背景（已查证）
- 15 超限用例链接到 **highmem 布局**（ITCM@0x0 + DTCM@0x100000 + CSR@0x200000）
- **SoC 自动布局**（SoCChiselConfig.scala L132-135）：`dtcm ≠ 32K` → 自动 MemoryRegions.highmem
- **配置决定（2026-08-26）：保持 1M/1M**（itcm=1024, dtcm=1024）——与 highmem 缺省常量一致（Parameters.scala L61-62），配置简单、与用例链接布局完全匹配；ITCM 1M 虽浪费（代码只用 1-6K）但资源够用（BRAM ~530 RAMB36/41% + SRAM 74 ≈ 46%，DualV7 共 1292 余量充足）

## 7 个目标用例（无 DDR）

| 用例 | 组 | DTCM 需求 |
| --- | --- | --- |
| rvv_rms_norm | gemma | 1M（memsz，filesz 147K） |
| rvv_bf16_rms_norm | gemma | 1M |
| rvv_int8_matmul | gemma | 1M |
| rvv_matmul_highmem | highmem | 1M |
| rvv_matmul_assembly_highmem | highmem | 1M |
| rvv_matmul_itcm512kb_dtcm512kb | highmem | 512K |
| rvv_matmul_assembly_itcm512kb_dtcm512kb | highmem | 512K |

## 修改清单

| # | 修改 | 内容 |
| --- | --- | --- |
| 1 | fork SoCChiselConfig | `itcmSizeKBytes=1024, dtcmSizeKBytes=1024`（1M/1M）→ 自动 highmem 布局 |
| 2 | 评测框架 bench_rvv.py | CSR 基址：0x30000/0x30008 → **0x200000/0x200008**（highmem 布局，chip_nexus 一致）；DTCM 段判断 0x10000-0x18000 → 0x100000 |
| 3 | 评测框架加载前清内存 | 对齐 chip_nexus `sram_clear()`：DTCM 1M 的 bss 区（如 rms_norm 877K）需加载前清零 |
| 4 | 生成 SV + 综合 | build_top（RVV 宏 VLEN_128/ZVE32F_ON/TB_SUPPORT、20MHz）；route ~3.7h 长任务 |
| 5 | 上板评测 | 只跑 7 个无 DDR 用例（新增 cfg：elite list） |

## 与 chip_nexus 对齐确认（2026-08-26 查证）

- **核配置 1M/1M**：chip_nexus fpga/BUILD L202-203 `dtcm/itcm_size_kbytes=1024` ✓
- **CSR 基址 0x200000**：fpga/sw/flash_tool_ftdi.py L73 `csr_base_addr=0x200000  # Required highmem` ✓；内部偏移固定（+0 CTRL/clock gate+reset、+4 PC、+8 STATUS）——评测框架 0x30008（default 基址+8）→ 0x200008
- **bss 清零**：上游加载 ELF 前 `sram_clear()`（fpga/main.cc L48）——加载器清全部内存，评测框架需对齐
- **Xbar 窗口**：CrossbarConfig(itcm,dtcm) 自动生成（SoCChiselConfig L139）——chip_nexus 1M/1M 已验证，无需自研

## 风险/注意
- 改 SoC 配置 = 新布局（highmem）——**与 T024 的 default SoC 是两套独立 bit**，不冲突
- CSR 基址变化影响：评测框架（0x30008）、可能的测试向量脚本
- DTCM 1M 的 BRAM：~530 RAMB36（41%）+ SRAM 256K（74）= ~604（46%）——余量充足（DualV7 共 1292）
- 8 个含 DDR 用例**本任务不做**（T026）

## 完成区
**状态**：待开始
**Commit**：
**综合资源**（utilization rpt）：
**测试结果**：
**验收结果**：
**新发现/坑**：
**遗留问题**：
