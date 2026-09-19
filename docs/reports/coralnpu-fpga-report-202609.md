---
title: "coralnpu RISC-V NPU 上板验证与性能评估"
core: "核：Google Coral NPU（开源 RISC-V NPU IP）"
platform: "平台：S2C DualV7（Xilinx Virtex-7 XC7V2000TFLG1925-1）"
date: "2026年9月"
---

# 汇报提纲

- **一、coralnpu 是什么？**——代码框架（包含什么 / 不包含什么）
- **二、如何集成到 FPGA SoC**（裁剪 / 加载通路 / 时钟与流程）
- **三、如何做性能评估**（指标定义 / 测量方法 / 实测与不足）
- **四、现状、挑战与下一步**

> [24] 核心问题：这个核"有什么、缺什么"，我们"怎么做、怎么评"

# 项目目标与路线

[图:roadmap]

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

> 佐证：coralnpu/README.md（定位/特性）；coralnpu/doc/overview.md（Scalar/Vector/Cache 章节）

# 芯片形态与产品形态

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

# 代码框架总览

[图:framework]

> 佐证：coralnpu/hdl/chisel/src/{coralnpu,bus,soc}、coralnpu/{sw,tests}（源码目录）

# 包含 ①：标量核（Scalar Core）

| 特性 | 内容 |
|---|---|
| ISA | rv32im（+ Zicsr/Zifencei/Zbb） |
| 微架构 | 四阶段；in-order dispatch、out-of-order retire |
| 推测 | 无推测；后向分支取/前向不取 |
| 发射 | 四路标量 |
| 执行模型 | run-to-completion，无 OS 依赖 |
| 寄存器 | 32 位 × 31 个 + CSR |

# 包含 ②：向量核（RVV / SIMD）

| 特性 | 内容 |
|---|---|
| ISA 扩展 | RV32IMF_Zve32x |
| 数据宽度 | 8 / 16 / 32 bit |
| SIMD 宽度 | 128-bit（VLEN=128） |
| 指令 | vsetvli / vle / vse / vadd 等标准 RVV |
| 发射 | 两路向量 |
| 验证 | 606 个 RVV 用例，正常 100% 通过 |

# 包含 ③：存储体系

[图:storage]

- L1 Cache（L1I 8KB + L1D 16KB）、L0 I-Cache 1KB
- TCM（ITCM/DTCM，单周期 SRAM）+ FabricArbiter 仲裁
- 外部：SRAM 256K（0x20000000）· ROM · DDR（规划）

> 佐证：coralnpu/hdl/chisel/src/coralnpu/{L1ICache,L1DCache,BankedItcm,BankedDtcm,Parameters}.scala（L165-173）

# TCM 容量需求与产品形态影响

| 内存层 | 容量 / 地址 | 说明 |
|---|---|---|
| TCM | 8K/32K 默认；1M/1M highmem | 核内单周期 SRAM（scratchpad） |
| EXTMEM | 0x20000000（4MB 窗口） | 外部内存区；我们 SoC 中是 SRAM 256K |
| DDR | 0x80000000（2GB 窗口） | 片外 DRAM（未实现） |

- 官方 MobileNet 示例：itcm/dtcm=1024（1M/1M）；**tensor_arena=4MB**
- arena 4MB 超出 1M TCM → **必须 EXTMEM/DDR**
- TCM 定位 = 高速 scratchpad（确定性延迟），**不是模型存储**

> 佐证：coralnpu/tests/npusim_examples/BUILD（L36-37）、run_full_mobilenet_v1.cc（L53）；coralnpu/toolchain/coralnpu_tcm.ld.tpl

# 包含 ④：总线与外设

[图:bus]

- 主干：**TileLink-UL（TL-UL）** 交叉开关（Xbar）
- 主机：coralnpu_core、uart_host、spi2tlul（规划）、dma（规划）
- 设备：coralnpu_device（ITCM/DTCM/CSR）、sram 256K、clint、plic、gpio、spi/dma
- 桥：Axi2TLUL（host 入口）、TLUL2Axi（核访问外部）

> 佐证：coralnpu/hdl/chisel/src/bus/*.scala；coralnpu/hdl/chisel/src/soc/{CoralNPUXbar,CrossbarConfig}.scala

# 包含 ⑤：软件栈与验证框架

[图:swstack]

| 层 | 内容 |
|---|---|
| 工具链 | RISC-V clang · crt0 · TCM 链接脚本 |
| 运行库 | **litert-micro**（conv/depthwise_conv/fully_connected）· rvv_opt.h |
| 示例 | hello_world · rvv_add_intrinsic · MobileNet V1 |
| 验证 | cocotb · npusim · systemc · uvm · vcs_sim · verilator_sim |

# 不包含 ①：矩阵计算（关键边界）

| 层面 | 文档描述 | 代码实现现状 |
|---|---|---|
| 矩阵 MAC | outer-product，256 MACs/cycle | **未实现**（无 VDOT/outer-product 代码） |
| SIMD 宽度 | 256-bit（future） | 实际 128-bit |
| VME (Zvt) | mset* + PE 阵列 | 仅 mset 配置；**mmac/mred 缺失** |
| 实际矩阵乘 | — | 标准 RVV 软件实现 |

> 结论：文档描述的"硬件矩阵加速"未落地——**实际能力 = 标准 RVV 软件算子**

# 不包含 ②：DDR / ISP 数据通路未完成

| 模块 | 规划 | 现状 |
|---|---|---|
| DDR | ddr_ctrl + ddr_mem（2GB） | io_ddr_mem_axi **悬空**（无驱动） |
| ISP | ispyocto_ctrl + AXI master | AXI 接入但 DDR 未通 |
| SPI 加载 | spi2tlul 主机桥 | chisel SoC 未实例化 |

- 上游"预留但未完成"的部分——M3 裁剪时删除
- 影响：大模型数据无法放入内存 → 产品形态不完整

# 不包含 ③：OS / MMU / 多核

| 项 | 状态 | 说明 |
|---|---|---|
| 操作系统 | 无 | run-to-completion |
| 中断 | SoC 有 clint/plic | overview 描述"no interrupts"（早期） |
| MMU | 无 | 仅物理地址 |
| 多核 | 单核 | hartId 参数 |
| 位宽 | RV32 | xlen = 32 |
| Cache | 仅 L1 | 无 L2/L3 |

> 定位：面向可穿戴的"裸机 NPU"——不追求通用计算能力

# SoC 整体架构

[图:soc_arch]

| 模块 | 说明 |
|---|---|
| **rvv_core (CoreTlul)** | **核心**：标量 + RVV + FPU + LSU + Cache + TCM |
| CoralNPUXbar | TileLink-UL 连接（路由 + 仲裁） |
| uart_host | AXI→TL-UL 桥（程序加载/回读） |
| 外设 | sram 256K、clint、plic、gpio、rom |

# 集成方法 ①：SoC 裁剪

[图:trim]

- **上游 chip_nexus**：核 + Xbar + ISP + DDR + SPI + DMA + 外设（DDR/ISP 未完成）
- **我们裁剪后**：CoreTlul + CoralNPUXbar + clint/plic/gpio/sram(256K) + uart_host
- **删除**：ISP / DDR / spi2tlul / dma / spi_master(_flash)

> 佐证：M3/E1（T022 SoC 裁剪：删 ISP/DDR/SPI/DMA）；coralnpu/hdl/chisel/src/soc/CrossbarConfig.scala

# 集成方法 ②：程序加载通路

[图:loadpath]

- 命令集：W<addr><data>（写）、R<addr><count>（读）、S（启动）、L（LED）
- 闭环：加载 → 释放核（S）→ 执行 → HALTED 检测 → 结果回读
- 加载时核保持复位（CTRL=1），S 命令释放——避免核占用总线

> 佐证：M3/E1（T022 uart_host Axi2TLUL 桥）；synth/rtl/host_cmd_fsm.sv

# 集成方法 ③：时钟 · 综合流程 · 版本管理

[图:flow]

- **时钟**：100MHz 差分 → MMCM ×12/60 → **20MHz 单时钟域**
- **SV 生成**：Chisel RTL → bazel（参数化 TCM）
- **综合**：Vivado build_top.tcl（synth → opt → place → route → bitstream）
- **版本管理**：fork 承载 SoC 改动；主仓库管理 synth/xdc/tcl

> 佐证：M2/E3（综合流程）；synth/rtl/top_coralnpu_soc.sv、synth/tcl/build_top.tcl

# 性能评估 ①：评估方案

| 要素 | 定义 / 做法 |
|---|---|
| 核心指标 | **MACs/Cycle**（每周期乘加次数） |
| 理论峰值 | VLEN / 数据类型位宽（int8=16、bf16=8、f32=4） |
| 周期测量 | 程序内 **mcycle 计数器**差值 |
| 自动分流 | 有周期符号→性能模式；无→smoke 模式 |
| 评测对象 | 8 个 matmul 用例（int8/f32/bf16） |

# 性能评估 ②：实测结果（8 个 MatMul 用例）

<!-- tbl size=16 firstcol=3.4 restcol=1.5 -->
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
- **不足（效率 7-25%）**：① vle/vse 装载开销 ② 循环控制开销 ③ 单向量寄存器（m1）流水利用率低 ④ 无矩阵 MAC 硬件
- **改进方向**：指令调度/展开、多发射、数据复用、矩阵扩展

# FPGA 资源利用率（T023，20MHz）

| 资源 | 用量 | 总数 | 利用率 |
|---|---|---|---|
| Slice LUTs | 467,150 | 1,221,600 | **38.24%** |
| Slice Registers | 70,857 | 2,443,200 | 2.90% |
| RAMB36 | 74 | 1,292 | 5.73% |
| DSP48E1 | 153 | — | — |
| MMCM | 1 | 24 | 4.17% |

- **TCM 容量**：当前 ITCM 8K + DTCM 32K（默认）；M4 扩容到 **8K/1M**（DTCM 1M）
- LUT 38.24% 主要来自 RVV 向量核；**BRAM 5.73% 余量充足**，是 TCM 扩容依据

> 佐证：M3/E3-E6（T023 综合）；workspace/T023-e3-synth/utilization_route.rpt

# 当前挑战：TCM 扩容为何耗时

<!-- tbl size=14 -->
| 轮次 | 配置 | 结果 | 轮次 | 配置 | 结果 |
|---|---|---|---|---|---|
| 1 | 1M/1M 默认 | 23087 拥塞 | 7 | 10MHz 重综合 | 4420 |
| 2 | 1M/1M Aggressive | 1410 | 8 | 10MHz 无 phys_opt | 4420 |
| 3 | 64K/1M 默认 | 1712 | 9 | 10MHz place Explore | 27739 |
| 4 | 64K/1M Aggressive | 1410 | 10 | 约束覆盖（pin 错） | 4420 |
| 5 | 8K/1M 默认 | **通过**（0 拥塞） | 11 | 约束覆盖（pin 修正） | 22331 |
| 6 | route 后 phys_opt | -17ns | 12 | 方案 A（上游约束） | 验证中 |

- **根因**：LSU deqPtr 高扇出（fo=63951）→ 路径 67ns；DTCM BRAM 挤压布局
- **方案 A**：回 20MHz（好布局）+ 借鉴上游约束（MAX_FANOUT 256 + MUXF_REMAP）

# 结论与下一步

**结论**

- coralnpu 核功能正确：606 个 RVV 用例正常通过率 100%，上板闭环验证
- 实际能力 = 标准 RVV + 标量核；文档中的硬件矩阵 MAC 未实现
- 性能基线已建立（MACs/Cycle 7-25%）
- TCM 扩容遇到 LSU 扇出时序难题，根因已定位、方案 A 验证中

**性能优化方向**

- 指令调度/展开（optimized 版已达 25.3%）、多发射、数据复用
- **自行增加矩阵运算**（实现 mmac 矩阵指令，释放 PE 阵列硬件能力）

**下一步**

| 方向 | 内容 |
|---|---|
| SPI 加载 | 大用例加载提速（秒级） |
| DDR 通路 | 补全产品形态（大模型内存） |
| 全面评测 | 8 个 DDR 用例 + 全量 621 回归 |
