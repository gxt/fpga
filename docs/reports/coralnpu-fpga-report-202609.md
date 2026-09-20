---
title: "coralnpu RISC-V NPU 上板验证与性能评估"
core: "核：Google Coral NPU（开源 RISC-V NPU IP）"
platform: "平台：S2C DualV7（Xilinx Virtex-7 XC7V2000TFLG1925-1）"
date: "2026年9月"
---

# 汇报提纲

<!-- bullets size=24 spacing=1.5 -->
- **一、coralnpu 是什么？**——代码框架（包含什么 / 不包含什么）
- **二、如何集成到 FPGA SoC**（裁剪 / 加载通路 / 时钟与流程）
- **三、如何做性能评估**（指标定义 / 测量方法 / 实测与不足）
- **四、现状、挑战与下一步**

<!-- quote top=4.8 -->
> [24] 核心问题：这个核"有什么、缺什么"，我们"怎么做、怎么评"

# 项目目标与路线

[图:roadmap]

<!-- tbl colw=2.0,8.1,2.0 -->
| 里程碑 | 内容 | 状态 |
|---|---|---|
| **M1** | 上板闭环 | 完成 |
| **M2** | 调试流程与环境 | 完成 |
| **M3** | 完整 Core + 测试向量 | 完成 |
| **M4** | 存储系统扩展 | 进行中 |
| **M5** | 矩阵计算 + benchmark | 规划 |

# coralnpu 是什么？

[图:official_block]

- ML 推理硬件加速器（NPU），Google Research 设计的**开源 IP**（非芯片产品）
- 目标产品：超低功耗可穿戴设备 SoC（hearables / AR 眼镜 / 智能手表）
- 三组件融合设计：**matrix（矩阵）+ vector（SIMD）+ scalar（标量）**

# 芯片形态与产品形态

<!-- tbl colw=2.0,10.1 -->
| 项 | 内容 |
|---|---|
| 形态 | 开源 IP 核（供集成），非芯片产品 |
| 接口 | AXI4（manager + subordinate） |
| ISA | RV32IMF_Zve32x |
| 流水 | 四阶段、in-order dispatch、out-of-order retire |
| 发射 | 四路标量 + 两路向量 |
| SIMD | 128-bit（256-bit future） |
| TCM 默认 | 8KB ITCM + 32KB DTCM（单周期 SRAM） |
| 目标产品 | 超低功耗可穿戴 SoC |
| 官方文档 | Architecture Datasheet（developers.google.com/coral） |

# 代码框架总览（包含 / 不包含）

**包含**

<!-- tbl colw=2.2,9.9 -->
| 类别 | 内容 |
|---|---|
| 核 | 标量（rv32im）+ RVV 向量（Zve32x，VLEN=128）+ FPU + LSU + TCM + Debug（**无 Cache**） |
| 总线 | TileLink-UL（Xbar / Router / Socket / Arbiter / 异步 FIFO）+ 桥（Axi2TLUL / TLUL2Axi） |
| 外设 | clint / plic / gpio / sram / rom / spi / dma |
| 软件 | clang 工具链 · litert-micro（推理算子）· cocotb 等验证框架 |

**不包含**

<!-- tbl colw=2.2,9.9 -->
| 类别 | 缺失 |
|---|---|
| 矩阵计算 | mmac/mred 指令未实现（PE 阵列硬件空置）；文档描述的 outer-product MAC 未落地 |
| 大内存 | DDR / ISP 通路未完成（io_ddr_mem_axi 悬空） |
| Cache | L1I/L1D Cache 源码存在但未实例化（核取指用 UncachedFetch） |
| 系统 | 无 OS / MMU / 多核（裸机单核 RV32）；无 Cache（取指 UncachedFetch） |

# 包含 ①：标量核（Scalar Core）

<!-- tbl size=16 colw=2.0,10.1 -->
| 特性 | 内容 |
|---|---|
| ISA | rv32im（+ Zicsr/Zifencei/Zbb） |
| 微架构 | 四阶段；in-order dispatch、out-of-order retire |
| 推测 | 无推测；后向分支取/前向不取 |
| 发射 | 四路标量 |
| 执行模型 | run-to-completion，无 OS 依赖 |
| 寄存器 | 32 位 × 31 个 + CSR |

**扩展说明**

- **Zicsr**：CSR 访问指令（控制/状态寄存器读写）
- **Zifencei**：指令流同步（fence.i，取指与数据一致性）
- **Zbb**：基础位操作扩展（bit manipulation）

# 包含 ②：向量核（RVV / SIMD）

<!-- tbl size=16 colw=2.0,10.1 -->
| 特性 | 内容 |
|---|---|
| ISA 扩展 | RV32IMF_Zve32x |
| 数据宽度 | 8 / 16 / 32 bit |
| SIMD 宽度 | 128-bit（VLEN=128） |
| 指令 | vsetvli / vle / vse / vadd 等标准 RVV |
| 发射 | 两路向量 |
| 验证 | 606 个 RVV 用例，正常 100% 通过 |

**Zve32x 说明**

- RISC-V **嵌入式向量扩展**（32 位元素）——coralnpu 实现的标准向量子集（VLEN=128）

# 包含 ③：存储体系

[图:storage fs=16]

- **无 Cache**：取指用 UncachedFetch；L1 Cache 源码存在但**未实例化**（未接入核）
- TCM（ITCM/DTCM，单周期 SRAM）+ FabricArbiter 仲裁
- 外部：SRAM · ROM · DDR（规划）

> 佐证：coralnpu/hdl/chisel/src/coralnpu/{L1ICache,L1DCache,BankedItcm,BankedDtcm,Parameters}.scala（L165-173）

# TCM 容量需求与产品形态影响

<!-- tbl size=16 colw=2.0,5.05,5.05 -->
| 存储层 | 容量 / 地址 | 说明 |
|---|---|---|
| TCM | 8K/32K 默认；1M/1M highmem | 核内单周期 SRAM（scratchpad） |
| EXTMEM | 0x20000000（4MB 窗口） | 外部内存区；我们 SoC 中是 SRAM |
| DDR | 0x80000000（2GB 窗口） | 片外 DRAM（未实现） |

- **tensor_arena**：TFLite Micro 推理的工作内存区（中间张量），官方示例 4MB
- 官方 MobileNet 示例：itcm/dtcm=1024（1M/1M）；arena 4MB 超出 1M TCM → **必须 EXTMEM/DDR**
- TCM 定位 = 高速 scratchpad（确定性延迟），**不是模型存储**

> 佐证：coralnpu/tests/npusim_examples/BUILD（L36-37）、run_full_mobilenet_v1.cc（L53）；coralnpu/toolchain/coralnpu_tcm.ld.tpl

# 包含 ④：总线与外设

[图:bus fs=16]

- **Backbone**: TileLink-UL (Xbar)
- **Hosts**: coralnpu_core、uart_host、spi2tlul（规划）、dma（规划）
- **Devices**: coralnpu_device（ITCM/DTCM/CSR）、sram、clint、plic、gpio、spi/dma
- **Bridges**: Axi2TLUL（host 入口）、TLUL2Axi（核访问外部）

> 佐证：coralnpu/hdl/chisel/src/bus/*.scala；coralnpu/hdl/chisel/src/soc/{CoralNPUXbar,CrossbarConfig}.scala

# 包含 ⑤：软件栈与验证框架

[图:swstack fs=18]

# 不包含 ①：矩阵计算（关键边界）

<!-- tbl size=16 colw=2.0,5.05,5.05 -->
| 层面 | 文档描述 | 代码实现现状 |
|---|---|---|
| 矩阵 MAC | outer-product，256 MACs/cycle | **未实现**（无 VDOT/outer-product 代码） |
| SIMD 宽度 | 256-bit（future） | 实际 128-bit |
| VME (Zvt) | mset* + PE 阵列 | 仅 mset 配置；**mmac/mred 缺失** |
| 实际矩阵乘 | — | 标准 RVV 软件实现 |

**术语说明**

- **mset**：矩阵配置指令（设置 tile）；**mmac/mred**：矩阵计算指令——**未实现**
- **VDOT / outer-product**：硬件矩阵 MAC 引擎（文档描述）——**无实现**
- **Zvt**：RISC-V 矩阵扩展（仅 mset 配置 + PE 阵列，缺计算指令）

> [24] 结论：文档描述的"硬件矩阵加速"未落地——实际能力 = 标准 RVV 软件算子

# 不包含 ②：DDR / ISP / SPI / DMA 通路未完成

<!-- tbl size=16 colw=2.0,5.05,5.05 -->
| 模块 | 规划 | 现状 |
|---|---|---|
| DDR | ddr_ctrl + ddr_mem（2GB） | io_ddr_mem_axi **悬空**（无驱动） |
| ISP | ispyocto_ctrl + AXI master | AXI 接入但 DDR 未通 |
| SPI 加载 | spi2tlul 主机桥 | chisel SoC 未实例化 |
| DMA | dma（0x40050000） | DmaEngine 实现存在，M3 未接入 |

- 上游"预留但未完成"的部分——M3 裁剪时删除
- 影响：大模型数据无法放入内存 → 产品形态不完整

# 不包含 ③：OS / MMU / 多核

<!-- tbl size=16 colw=2.0,2.0,8.1 -->
| 项 | 状态 | 说明 |
|---|---|---|
| 操作系统 | 无 | run-to-completion |
| 中断 | SoC 有 clint/plic | overview 描述"no interrupts"（早期） |
| MMU | 无 | 仅物理地址 |
| 多核 | 单核 | hartId 参数 |
| 位宽 | RV32 | xlen = 32 |
| Cache | **无** | 取指 UncachedFetch；仅 TCM（L1 源码未接入） |

> [24] 定位：面向可穿戴的"裸机 NPU"——不追求通用计算能力

# SoC 整体架构

[图:soc_arch fs=16]

<!-- tbl colw=3.0,9.1 -->
| 模块 | 说明 |
|---|---|
| **rvv_core (CoreTlul)** | **核心**：标量 + RVV + FPU + LSU |
| CoralNPUXbar | TileLink-UL 连接（路由 + 仲裁） |
| uart_host | AXI→TL-UL 桥（程序加载/回读） |
| 外设 | sram、clint、plic、gpio、rom |

# 集成方法 ①：SoC 裁剪

[图:trim fs=18]

- **上游 chip_nexus**：核 + Xbar + ISP + DDR + SPI + DMA + 外设
- **我们裁剪后**：CoreTlul + CoralNPUXbar + clint/plic/gpio/sram + uart_host
- **删除**：ISP / DDR / spi2tlul / dma / spi_master(_flash)

> 佐证：M3/E1（T022 SoC 裁剪：删 ISP/DDR/SPI/DMA）；coralnpu/hdl/chisel/src/soc/CrossbarConfig.scala

# 集成方法 ②：程序加载通路

[图:loadpath]

- 命令集：W<addr><data>（写）、R<addr><count>（读）、S（启动）、L（LED）
- 闭环：加载 → 释放核（S）→ 执行 → HALTED 检测 → 结果回读
- 加载时核保持复位（CTRL=1），S 命令释放——避免核占用总线

> 佐证：M3/E1（T022 uart_host Axi2TLUL 桥）；synth/rtl/host_cmd_fsm.sv

# 集成方法 ③：时钟 · 综合流程 · 版本管理

[图:flow fs=18]

- **时钟**：100MHz 差分 → MMCM ×12/60 → **20MHz 单时钟域**
- **SV 生成**：Chisel RTL → bazel（参数化 TCM）
- **综合**：Vivado build_top.tcl（synth → opt → place → route → bitstream）
- **版本管理**：fork 承载 SoC 改动；主仓库管理 synth/xdc/tcl

> 佐证：M2/E3（综合流程）；synth/rtl/top_coralnpu_soc.sv、synth/tcl/build_top.tcl

# 性能评估 ①：评估方案

<!-- tbl size=16 colw=3.0,9.1 -->
| 要素 | 定义 / 做法 |
|---|---|
| 核心指标 | **MACs/Cycle**（每周期乘加次数） |
| 理论峰值 | VLEN / 数据类型位宽（int8=16、bf16=8、f32=4） |
| 周期测量 | 程序内 **mcycle 计数器**差值 |
| 自动分流 | 有周期符号→性能模式；无→smoke 模式 |
| 评测对象 | 8 个 matmul 用例（int8/f32/bf16） |

- **自动分流**：评测框架按用例类型自动选择判定方式
- **有周期符号**：程序内定义了 `csr_cycle_count`（可回读执行周期）→ **性能模式**（等 HALTED + 回读周期数）
- **无周期符号**：仅验证能否正常运行 → **smoke 模式**（加载 + 启动 + 无 fault 即通过）

# 性能评估 ②：实测结果（8 个 MatMul 用例）

<!-- tbl size=16 colw=3.4,1.5,2.25,1.5,1.5 -->
| 用例 | 数据类型 | MACs/Cycle | 理论峰值 | 效率 |
|---|---|---|---|---|
| rvv_matmul | int8 | 1.96 | 16 | 12.3% |
| rvv_matmul_assembly | int8 | 1.82 | 16 | 11.4% |
| int_matmul_16x48x16 | int8 | 1.13 | 16 | 7.1% |
| rvv_float_matmul_optimized | f32 | 1.01 | 4 | **25.3%** |
| rvv_float_matmul | f32 | 0.47 | 4 | 11.8% |
| rvv_float_matmul_assembly | f32 | 0.45 | 4 | 11.3% |
| float_matmul_16x48x16 | f32 | 0.47 | 4 | 11.8% |
| rvv_bf16_matmul | bf16 | 0.56 | 8 | 7.0% |

# 性能评估 ③：606 用例评测与不足

- **606 用例评测：正常用例 100% 通过**（2 个故障注入测试预期 FAIL）
- 分类：向量算术 521 + load_store 56 + rvv 19 + ml_ops 8 + rvv_opt 2

**不足分析（效率 7-25%）**

- ① vle/vse 装载开销大
- ② 循环控制开销
- ③ 单向量寄存器（m1）粒度导致流水利用率低
- ④ 无矩阵 MAC 硬件（文档描述的加速引擎未实现）

**改进方向**：指令调度/展开、多发射、数据复用、矩阵扩展

# FPGA 资源利用率（T023，20MHz）

<!-- tbl size=16 -->
| 资源 | 用量 | 总数 | 利用率 |
|---|---|---|---|
| Slice LUTs | 467,150 | 1,221,600 | **38.24%** |
| Slice Registers | 70,857 | 2,443,200 | 2.90% |
| RAMB36 | 74 | 1,292 | 5.73% |
| DSP48E1 | 153 | — | — |
| MMCM | 1 | 24 | 4.17% |

- **TCM 容量**：当前 ITCM 8K + DTCM 32K（默认）；M4 **拟扩容**到 8K/1M（DTCM 1M）
- LUT 38.24% 主要来自 RVV 向量核；**BRAM 5.73% 余量充足**，是 TCM 扩容依据

> 佐证：M3/E3-E6（T023 综合）；workspace/T023-e3-synth/utilization_route.rpt

# 当前挑战：TCM 扩容的尝试

<!-- tbl size=14 colw=0.67,2.52,2.86,0.67,2.52,2.86 -->
| 轮次 | 配置 | 结果 | 轮次 | 配置 | 结果 |
|---|---|---|---|---|---|
| 1 | 1M/1M 默认 | 23087 信号拥塞 | 7 | 10MHz 重综合 | 4420 信号拥塞 |
| 2 | 1M/1M Aggressive route | 1410 信号拥塞 | 8 | 10MHz 无 phys_opt | 4420 信号拥塞 |
| 3 | 64K/1M 默认 | 1712 信号拥塞 | 9 | 10MHz place Explore | 27739 信号拥塞 |
| 4 | 64K/1M Aggressive route | 1410 信号拥塞 | 10 | 约束覆盖（pin 错） | 4420 信号拥塞 |
| 5 | 8K/1M 默认 | **通过**（0 拥塞）；时序 -20.7ns | 11 | 约束覆盖（pin 修正） | 22331 信号拥塞 |
| 6 | route 后 phys_opt | -17ns（仍违例） | 12 | 方案 A（上游约束） | 验证中 |

<!-- bullets size=16 -->
- **第 12 轮发现的问题**：LSU deqPtr 高扇出（fo=63951）→ 路径 67ns；DTCM BRAM 挤压布局
- **方案 A**（进行中）：回 20MHz + 借鉴上游约束（MAX_FANOUT 256 + MUXF_REMAP）
- **方案 B**（待验证）：DTCM 降容至 512K + 重编译用例（减小 BRAM 挤压）
- **方案 C**（待验证）：改核 RTL 拆分 LSU 高扇出门控

# 结论与挑战

**结论**

- coralnpu 核功能正确：606 个 RVV 用例正常通过率 100%，上板闭环验证
- 实际能力 = 标准 RVV + 标量核；文档中的硬件矩阵 MAC 未实现
- 性能基线已建立（MACs/Cycle 7-25%）

**TCM 扩容遇到的问题**（M4）

- DTCM 扩到 1M 后，route 阶段出现严重布线拥塞（最高 27739 个信号无法布线）
- 同时时序违例（WNS -20.7ns）——LSU deqPtr 高扇出（fo=63951，路径 67ns）+ DTCM BRAM 阵列挤压 LSU 布局
- 拥塞与时序交织：改布局修拥塞→时序变差；降频修时序→布局变差
- 已尝试 12 轮（累计 ~90 机器小时）

# 优化方向与下一步

**性能优化方向**

- 指令调度/展开（optimized 版已达 25.3%）、多发射、数据复用
- **自行增加矩阵运算**（实现 mmac 矩阵指令，释放 PE 阵列硬件能力）

**下一步**

- SPI 加载提速（秒级）
- DDR 通路（补全产品形态）
- 全面评测（15 个超限用例：8 DDR + 7 无 DDR；+ 全量 621 回归）
