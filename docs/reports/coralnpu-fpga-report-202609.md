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

> 核心问题：这个核"有什么、缺什么"，我们"怎么做、怎么评"

# 项目目标与路线

[图:roadmap]

| 里程碑 | 内容 | 状态 |
|---|---|---|
| **M1** | 从零到上板闭环（T001-T014） | 完成 |
| **M2** | **EDA 流程梳理**（50MHz 学习 → 20MHz 定版；规范/目录/环境） | 完成 |
| **M3** | 完整 SoC（TL-UL 主干 + RVV）+ 606 用例评测 | 完成 |
| **M4** | 内存系统扩展（TCM 扩容 / SPI / DDR） | 进行中 |

目标：在 DualV7 上构建含 RVV 向量核的完整 SoC，完成功能验证 + 性能评估

# coralnpu 是什么？

[图:official_block]

- ML 推理硬件加速器（NPU），Google Research 设计的**开源 IP**（非芯片产品）
- 目标产品：超低功耗可穿戴设备 SoC（hearables / AR 眼镜 / 智能手表）
- 三组件融合设计：**matrix（矩阵）+ vector（SIMD）+ scalar（标量）**
- 官方定位："hardware accelerator for ML inferencing"

> 佐证：README.md（定位/特性）、doc/overview.md

# 芯片形态与产品形态

| 项 | 内容 | 佐证 |
|---|---|---|
| 形态 | 开源 IP 核（供集成），非芯片产品 | README.md |
| 接口 | AXI4（manager + subordinate） | README.md |
| ISA | RV32IMF_Zve32x | README.md |
| 流水 | 四阶段、in-order dispatch、out-of-order retire | README.md |
| 发射 | 四路标量 + 两路向量 | README.md |
| SIMD | 128-bit（256-bit future） | README.md |
| TCM 默认 | 8KB ITCM + 32KB DTCM（单周期 SRAM） | README.md |
| 目标产品 | 超低功耗可穿戴 SoC | README.md |
| 官方文档 | Architecture Datasheet（developers.google.com/coral） | README.md 链接 |

# 代码框架总览

[图:framework]

> 佐证：hdl/chisel/src/{coralnpu,bus,soc} · sw/ · tests/

# 包含 ①：标量核（Scalar Core）

| 特性 | 内容 | 佐证 |
|---|---|---|
| ISA | rv32im（+ Zicsr/Zifencei/Zbb） | Core.scala |
| 微架构 | 四阶段；in-order dispatch、out-of-order retire | overview.md |
| 推测 | 无推测；后向分支取/前向不取 | overview.md |
| 发射 | 四路标量 | README.md |
| 执行模型 | run-to-completion，无 OS 依赖 | overview.md |
| 寄存器 | 32 位 × 31 个 + CSR | overview.md |

> 标量核是"驱动后端命令队列"的前端，设计目标是最小化开销

# 包含 ②：向量核（RVV / SIMD）

| 特性 | 内容 | 佐证 |
|---|---|---|
| ISA 扩展 | RV32IMF_Zve32x | README.md |
| 数据宽度 | 8 / 16 / 32 bit | overview.md |
| SIMD 宽度 | 128-bit（VLEN=128） | README.md |
| 指令 | vsetvli / vle / vse / vadd 等标准 RVV | RvvDecode.scala |
| 发射 | 两路向量 | README.md |
| 验证 | 606 个 RVV 用例，正常 100% 通过 | T024 评测 |

> 实际可用的是**标准 RVV**（RvvCore），非仅文档描述的自定义 SIMD

# 包含 ③：存储体系

[图:storage]

- **L1I Cache 8KB**（4-way，256 slots）+ **L1D Cache 16KB**（4-way，双 bank 8KB×2）
- **L0 I-Cache 1KB**（fetch unit）
- **ITCM / DTCM**（指令/数据紧耦合存储，可配置 8K~1M）
- **FabricArbiter**（TCM 与外部访问仲裁）
- 外部：SRAM 256K（0x20000000）· ROM · DDR（规划）

> 佐证：L1ICache/L1DCache.scala、BankedItcm/Dtcm.scala、Parameters.scala L165-173

# TCM 容量需求与产品形态影响

| 内存层 | 容量 | 用途 | 佐证 |
|---|---|---|---|
| TCM | 8K/32K 默认；1M/1M highmem | 高速 scratchpad | README / Parameters |
| EXTMEM | 4MB（0x20000000） | 中间 buffer | coralnpu_tcm.ld.tpl |
| DDR | 2GB 窗口（0x80000000） | 大模型权重/数据 | coralnpu_tcm.ld.tpl |

- 官方 MobileNet 示例：itcm/dtcm=1024（1M/1M）；**tensor_arena=4MB**
- arena 4MB 超出 1M TCM → **必须 EXTMEM/DDR**
- TCM 定位 = 高速 scratchpad（确定性延迟），**不是模型存储**
- 产品影响：TCM 容量 → 片上驻留率 → 性能/功耗/面积权衡

> 佐证：tests/npusim_examples/BUILD L36-37、run_full_mobilenet_v1.cc L53

# 包含 ④：总线与外设

[图:bus]

- 主干：**TileLink-UL（TL-UL）** 交叉开关（Xbar）
- 主机：coralnpu_core、uart_host、spi2tlul（规划）、dma（规划）
- 设备：coralnpu_device（ITCM/DTCM/CSR）、sram 256K、clint、plic、gpio、spi/dma
- 组件：Router / Socket1N / SocketM1 / Arbiter / WidthBridge / **FifoAsync（跨时钟）**
- 桥：Axi2TLUL（host 入口）、TLUL2Axi（核访问外部）

> 佐证：bus/*.scala、soc/{CoralNPUXbar,CrossbarConfig}.scala

# 包含 ⑤：软件栈与验证框架

[图:swstack]

| 层 | 内容 |
|---|---|
| 工具链 | RISC-V clang · crt0 · TCM 链接脚本 |
| 运行库 | **litert-micro**（conv/depthwise_conv/fully_connected）· rvv_opt.h |
| 示例 | hello_world · rvv_add_intrinsic · MobileNet V1 |
| 验证 | cocotb · npusim · systemc · uvm · vcs_sim · verilator_sim |

> 佐证：toolchain/、sw/opt/litert-micro/、tests/、examples/

# 不包含 ①：矩阵计算（关键边界）

| 层面 | 文档描述 | 代码实现现状 | 佐证 |
|---|---|---|---|
| 矩阵 MAC | outer-product，256 MACs/cycle | **未实现**（无 VDOT/outer-product 代码） | overview.md L47-62 |
| SIMD 宽度 | 256-bit（future） | 实际 128-bit | README.md |
| VME (Zvt) | mset* + PE 阵列 | 仅 mset 配置；**mmac/mred 缺失** | RvvDecode.scala L119-135 |
| 实际矩阵乘 | — | 标准 RVV 软件实现 | sw/opt/ |

> 结论：文档描述的"硬件矩阵加速"未落地——**实际能力 = 标准 RVV 软件算子**

# 不包含 ②：DDR / ISP 数据通路未完成

| 模块 | 规划 | 现状 | 佐证 |
|---|---|---|---|
| DDR | ddr_ctrl + ddr_mem（2GB） | io_ddr_mem_axi **悬空**（无驱动） | coralnpu_soc.sv |
| ISP | ispyocto_ctrl + AXI master | AXI 接入但 DDR 未通 | coralnpu_soc.sv |
| SPI 加载 | spi2tlul 主机桥 | chisel SoC 未实例化 | CrossbarConfig.scala |

- 上游"预留但未完成"的部分——M3 裁剪时删除
- 影响：大模型数据无法放入内存 → 产品形态不完整
- **T027（DDR）正是补全这条通路**

# 不包含 ③：OS / MMU / 多核

| 项 | 状态 | 说明 | 佐证 |
|---|---|---|---|
| 操作系统 | 无 | run-to-completion | overview.md |
| 中断 | SoC 有 clint/plic | overview 描述"no interrupts"（早期） | CoreTlul.scala |
| MMU | 无 | 仅物理地址 | grep 无 MMU |
| 多核 | 单核 | hartId 参数 | Parameters.scala |
| 位宽 | RV32 | xlen = 32 | Parameters.scala L71 |
| Cache | 仅 L1 | 无 L2/L3 | L1*.scala |

> 定位：面向可穿戴的"裸机 NPU"——不追求通用计算能力

# SoC 整体架构

[图:soc_arch]

| 模块 | 说明 | 时钟域 |
|---|---|---|
| rvv_core (CoreTlul) | RISC-V 核：标量 + RVV + FPU，TL-UL 接口 | main |
| CoralNPUXbar | TileLink-UL 交叉开关（路由 + 仲裁） | main |
| uart_host | AXI→TL-UL 桥（程序加载/回读） | main |
| coralnpu_device | 核内从端口（ITCM/DTCM/CSR） | main |
| sram / clint / plic / gpio / rom | 外设（SRAM 256K、定时器、中断、GPIO、ROM） | main |

# 集成方法 ①：SoC 裁剪

[图:trim]

- **上游 chip_nexus**：核 + Xbar + ISP + DDR + SPI + DMA + 外设（DDR/ISP 未完成）
- **我们裁剪后**：CoreTlul + CoralNPUXbar + clint/plic/gpio/sram(256K) + uart_host
- **删除**：ISP / DDR / spi2tlul / dma / spi_master(_flash)
- **理由**：先打通已验证主干（UART 加载 + RVV 核）

> 佐证：fork commit ac01a545（T022 裁剪）、CrossbarConfig.scala

# 集成方法 ②：程序加载通路

[图:loadpath]

```
PC 串口 → UART 收发 → host_cmd_fsm(命令解析) → Axi2TLUL 桥 → Xbar → 核 TCM/CSR/SRAM
```

- 命令集：W<addr><data>（写）、R<addr><count>（读）、S（启动）、L（LED）
- 闭环：加载 → 释放核（S）→ 执行 → HALTED 检测 → 结果回读
- 加载时核保持复位（CTRL=1），S 命令释放——避免核占用总线

> 佐证：synth/rtl/host_cmd_fsm.sv、fork T022（uart_host Axi2TLUL 桥）

# 集成方法 ③：时钟 · 综合流程 · 版本管理

[图:flow]

- **时钟**：100MHz 差分 → MMCM ×12/60 → **20MHz 单时钟域**
- **SV 生成**：Chisel RTL → bazel（参数化 TCM，emitter 传 --itcmSizeKBytes/--dtcmSizeKBytes）
- **综合**：Vivado build_top.tcl（synth → opt → place → route → bitstream）
- **版本管理**：fork（gxt/coralnpu）承载 SoC 改动；主仓库管理 synth/xdc/tcl + 任务记录
- **分工**：201 = 维护/bazel/上板；202 = Vivado 综合/仿真

> 佐证：top_coralnpu_soc.sv、synth/tcl/build_top.tcl、hdl/chisel/src/soc/BUILD

# 性能评估 ①：方法论

| 要素 | 定义 / 做法 | 佐证 |
|---|---|---|
| 核心指标 | **MACs/Cycle**（每周期乘加次数） | 报告 §7.2 |
| 理论峰值 | VLEN / 数据类型位宽（int8=16、bf16=8、f32=4） | 报告 §6.1 |
| 周期测量 | 程序内 **mcycle 计数器**差值 | csr_cycle_count |
| 自动分流 | 有周期符号→性能模式；无→smoke 模式 | bench_rvv.py |
| 评测对象 | 8 个 matmul 用例（int8/f32/bf16） | T024 |

> 方法可复现：脚本化 + 段分析 + 结果归档（elf_segments.json）

# 性能评估 ②：实测结果（8 个 MatMul 用例）

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

> 佐证：docs/coralnpu-fpga-report.md §6.1

# 性能评估 ③：606 用例评测与不足

- **606 用例评测：正常用例 100% 通过**（2 个故障注入测试预期 FAIL）
- 分类：向量算术 521 + load_store 56 + rvv 19 + ml_ops 8 + rvv_opt 2
- **不足（效率 7-25%）**：① vle/vse 装载开销 ② 循环控制开销 ③ 单向量寄存器（m1）流水利用率低 ④ 无矩阵 MAC 硬件
- **改进方向**：指令调度/展开（optimized 版已达 25.3%）、多发射、数据复用、未来矩阵扩展

> 佐证：docs/coralnpu-fpga-report.md §5.1/§6.2

# FPGA 资源利用率（T023，20MHz）

| 资源 | 用量 | 总数 | 利用率 |
|---|---|---|---|
| Slice LUTs | 467,150 | 1,221,600 | **38.24%** |
| Slice Registers | 70,857 | 2,443,200 | 2.90% |
| RAMB36 | 74 | 1,292 | 5.73% |
| DSP48E1 | 153 | — | — |
| MMCM | 1 | 24 | 4.17% |
| BUFGCTRL | 5 | 128 | 3.91% |

- LUT 38.24% 主要来自 **RVV 向量核逻辑**；寄存器利用率低（2.9%）说明逻辑以组合为主
- **BRAM 5.73%**（TCM + SRAM 256K）——**资源余量充足**，是 M4 TCM 扩容的依据；20MHz 时序收敛（标量 +15.410 / RVV +0.754）

> 佐证：docs/coralnpu-fpga-report.md §4、workspace/T023-e3-synth/utilization_route.rpt

# 当前挑战：T025（TCM 扩容）为何耗时

| 项 | 内容 |
|---|---|
| 现象 | DTCM 1M 后：route 拥塞（4420~27739 信号）+ 时序违例（WNS -20.7ns） |
| 根因 | **LSU deqPtr 高扇出（fo=63951）** → 路径 67ns；DTCM BRAM 挤压 LSU 布局 |
| 为何久 ① | 拥塞/时序交织：改布局修拥塞→时序差；降频修时序→布局差 |
| 为何久 ② | 每轮综合 6~18h，共 ~12 轮（~90 机器小时） |
| 为何久 ③ | 未及早对照上游：上游早有 MAX_FANOUT 256 针对同一问题 |
| 方案 A | 回 20MHz（好布局）+ 借鉴上游约束（MAX_FANOUT 256 + MUXF_REMAP） |

> 佐证：timing_route.rpt、workspace 日志、coralnpu/fpga/vivado_pre_opt_hooks.tcl

# 结论与下一步


**结论**

- coralnpu 核功能正确：606 个 RVV 用例正常通过率 100%，上板闭环验证
- 实际能力 = 标准 RVV + 标量核；文档中的硬件矩阵 MAC 未实现
- 性能基线已建立（MACs/Cycle 7-25%），优化方向明确
- TCM 扩容遇到 LSU 扇出时序难题，根因已定位、方案 A 验证中

**下一步**

| 方向 | 内容 |
|---|---|
| SPI 加载 | 大用例加载提速（秒级） |
| DDR 通路 | 补全产品形态（大模型内存） |
| 全面评测 | 8 个 DDR 用例 + 全量 621 回归 |

> 产品形态：TCM（1M）+ DDR（2GB）补齐后，可支撑 MobileNet/gemma 级模型
