# coralnpu RISC-V SoC 上板验证与 RVV 评测报告

日期：2026-08-26
平台：S2C DualV7（Xilinx Virtex-7 XC7V2000TFLG1925-1）
核：coralnpu（Google 开源 RISC-V NPU 核，上游 2290a286c）

---

## 1. 概述

本项目将 Google coralnpu RISC-V 核集成到 S2C DualV7 FPGA 板卡，构建了包含 TileLink-UL 总线、RVV 向量扩展核、片上外设的完整 SoC，并完成了上板验证与 606 个 RVV 测试用例的评测。

---

## 2. SoC 整体架构

### 2.1 系统结构

```
                 ┌────────────────────────────────────────────┐
   PC 串口       │          CoralNPUChiselSubsystem            │
      │          │                                            │
   UART host     │   ┌──────────────┐                          │
   (host_cmd_fsm)│   │  rvv_core    │    ┌──────────────────┐  │
      │ AXI      │   │ (CoreTlul)   │    │   CoralNPUXbar   │  │
      ▼          │   │  TL-UL host  │───►│   (TileLink-UL)  │  │
  Axi2TLUL 桥     │   │  TL-UL dev   │◄───│                  │  │
  (uart_host)    │   └──────────────┘    └──┬──────┬──────┬─┘  │
      │          │                          │      │      │    │
      ▼          │            ┌─────────────┼──────┼──────┼─┐  │
   TL-UL         │            ▼             ▼      ▼      ▼ │  │
      │          │     coralnpu_device   sram    clint   plic │
      │          │     (ITCM/DTCM/CSR)   (256K)  (timer)(int)│
      ▼          │            gpio（8bit）             rom │  │
                 └────────────────────────────────────────────┘
```

### 2.2 模块说明

| 模块 | 说明 | 时钟域 |
| --- | --- | --- |
| **rvv_core**（CoreTlul） | RISC-V 核：标量乱序 + RVV 向量 + FPU，TL-UL 接口 | main |
| **CoralNPUXbar** | TileLink-UL 交叉开关（主机/从设备路由 + 仲裁） | main |
| **uart_host** | AXI→TL-UL 桥（host_cmd_fsm 命令 → Xbar），程序加载/回读 | main |
| **coralnpu_device** | 核内从端口（ITCM 8K / DTCM 32K / CSR） | main |
| **sram** | 片内 SRAM（256KB，0x20000000） | main |
| **clint** | 定时器/软中断（0x02000000） | main |
| **plic** | 中断控制器（31 中断，0x0c000000） | main |
| **gpio** | 8 位 GPIO（0x40030000） | main |

### 2.3 时钟

- 输入：板载 100MHz 差分时钟（s2cclk_1）
- MMCM：100MHz × 12 / 1 / 60 = **20MHz 核时钟**（单时钟域，无跨时钟域）
- 20MHz 下时序完全收敛（setup WNS +0.754ns）

---

## 3. Core 内部架构

### 3.1 核结构（CoreAxi 体系）

```
                ┌────────────────── CoreAxi ──────────────────┐
                │                                             │
  IBus ────────►│  ┌──────────── SCore（乱序执行）────────┐   │
  DBus ────────►│  │  Fetch → Dispatch → Issue(多发射)     │   │
                │  │   → ALU/MLU/DUV/LSU/FPU               │   │
                │  │   → RetirementBuffer（ROB，按序提交）   │   │
                │  └───────────────────────────────────────┘   │
                │  ┌──────────── RvvCore（向量后端）────────┐   │
                │  │  RvvFrontEnd → rvv_backend             │   │
                │  │  （向量 ALU/乘累加/装载存储）            │   │
                │  └───────────────────────────────────────┘   │
                │  ┌──────────── FloatCore（标量 FPU）──────┐   │
                │  │  fpnew（浮点运算单元）                   │   │
                │  └───────────────────────────────────────┘   │
                │                                             │
                │  ITCM（8K）/ DTCM（32K）— FabricArbiter      │
                │  CoreCSR / DebugModule / 时钟门控            │
                └─────────────────────────────────────────────┘
```

### 3.2 关键部件

| 部件 | 说明 |
| --- | --- |
| **SCore** | 标量乱序执行流水（取指/解码/发射/执行/退休），含 RetirementBuffer（ROB）按序提交 |
| **RvvCore** | RVV 向量扩展后端（vsetvli/vle/vse/vadd 等），VLEN=128，支持 ZVE32F |
| **FloatCore** | 标量浮点（RV32F，fpnew 生成） |
| **TCM** | 指令/数据紧耦合存储（ITCM 8KB + DTCM 32KB），核内 fast-path + 外部 AXI 访问仲裁 |
| **Debug** | RISC-V Debug 模块 + 外部调试端口 |
| **时钟门控** | wfi 时核时钟门控（低功耗） |

### 3.3 加载通路

- **host_cmd_fsm**（核外）：UART 命令解析（W/R/S/L），AXI master
- **Axi2TLUL 桥**：AXI → TileLink-UL
- 加载路径：PC 串口 → UART → Xbar → 核 TCM/CSR

---

## 4. FPGA 资源利用率

器件：**XC7V2000TFLG1925-1**（Virtex-7，1,221,600 LUT / 1,292 RAMB36）

### 4.1 RVV SoC（T023，20MHz）

| 资源 | 用量 | 总数 | 利用率 |
| --- | --- | --- | --- |
| Slice LUTs | 467,150 | 1,221,600 | **38.24%** |
| Slice Registers | 70,857 | 2,443,200 | 2.90% |
| F7 Muxes | 15,000 | 610,800 | 2.46% |
| F8 Muxes | 2,705 | 305,400 | 0.89% |
| RAMB36 | 74 | 1,292 | 5.73% |
| DSP48E1 | 153 | — | — |
| Bonded IOB | 11 | 1,200 | 0.92% |
| BUFGCTRL | 5 | 128 | 3.91% |
| MMCM | 1 | 24 | 4.17% |

### 4.2 资源分析

- **LUT 利用率 38.24%**（主要来自 RVV 向量核逻辑）——资源余量充足，可支撑更大配置（如 TCM 扩容）
- 寄存器利用率低（2.9%），说明逻辑以组合为主（向量运算）
- BRAM 5.73%（TCM + SRAM 256K）——可扩展空间大
- 20MHz 下时序完全收敛，无拥塞

---

## 5. 实际测试结果

### 5.1 RVV 测试用例评测（606 个）

| 分类 | 数量 | 通过 | 说明 |
| --- | --- | --- | --- |
| 向量算术（arithmetics） | 521 | 521 | 整数/浮点/BF16 向量运算 |
| 向量装载/存储（load_store） | 56 | 55 | 1 个故障注入测试预期 FAIL |
| 基础 RVV（rvv/顶层） | 19 | 18 | 1 个 vill 故障测试预期 FAIL |
| 矩阵乘（ml_ops） | 8 | 8 | 性能评测（见 §6） |
| 向量优化（rvv_opt） | 2 | 2 | |
| **合计** | **606** | **604** | **正常用例通过率 100%** |

- **2 个 FAIL 均为故障注入测试**（load_store8_fault / vill_test）——按设计触发核故障路径，属预期行为
- 加载/回读通路：UART 加载 928 字节约 1.6 秒，核执行微秒级

### 5.2 功能验证

- UART host 通路（W/R/S/L 命令）经 TileLink-UL 总线访问核 TCM/CSR/外设，全部正常
- 程序加载 → 核执行 → HALTED 检测 → 结果回读比对，全链路闭环

---

## 6. 矩阵乘（MatMul）性能对比分析

### 6.1 实测数据（20MHz，VLEN=128）

| 用例 | 数据类型 | MACs | 执行周期 | MACs/Cycle | 理论峰值 | 效率 |
| --- | --- | --- | --- | --- | --- | --- |
| rvv_matmul | int8 | 131,072 | 66,726 | 1.96 | 16 | 12.3% |
| rvv_matmul_assembly | int8 | 131,072 | 71,972 | 1.82 | 16 | 11.4% |
| int_matmul_16x48x16 | int8 | 12,288 | 10,848 | 1.13 | 16 | 7.1% |
| rvv_float_matmul_optimized | f32 | 12,288 | 12,141 | 1.01 | 4 | **25.3%** |
| rvv_float_matmul | f32 | 12,288 | 25,982 | 0.47 | 4 | 11.8% |
| rvv_float_matmul_assembly | f32 | 12,288 | 27,276 | 0.45 | 4 | 11.3% |
| float_matmul_16x48x16 | f32 | 12,288 | 25,980 | 0.47 | 4 | 11.8% |
| rvv_bf16_matmul | bf16 | 12,288 | 21,958 | 0.56 | 8 | 7.0% |

（理论峰值 = VLEN 128 / 数据类型位宽，即每周期可并行 MAC 数）

### 6.2 分析

- **实测 MACs/Cycle 为理论值 7%-25%**——差距主要来自：
  1. 向量装载/存储（vle/vse）与循环控制开销
  2. 单向量寄存器（m1）粒度下的流水线利用率
- **优化版（rvv_float_matmul_optimized）效率最高（25.3%）**——指令调度/展开优化效果显著
- **int8 大矩阵（32×128×32）MACs/Cycle 最高（1.96）**——规模大、数据复用好
- 结论：RVV 核功能正确，性能优化空间大（指令调度/多发射/数据复用），实测数据为后续优化提供了量化基准

---

## 7. 重要内容

### 7.1 架构特点

1. **完整 SoC**：TileLink-UL 总线连接核/存储/外设，与 Google 官方芯片架构一致
2. **UART 加载保留**：host_cmd_fsm → Axi2TLUL 桥 → Xbar → 核（命令兼容 W/R/S/L）
3. **单时钟域 20MHz**：无跨时钟域问题，时序完全收敛
4. **RVV 向量核**：VLEN=128，支持整数/浮点/BF16 向量运算

### 7.2 评测方法

- **指标**：MACs/Cycle（每周期乘加次数，coralnpu 官方指标）+ 理论峰值对比
- **周期测量**：程序内 `mcycle` 计数器差值（精确执行周期）
- **自动分流**：有周期计数的 matmul 类测性能，其余测功能通过

### 7.3 测试范围与状态

- **已完成**：606 个 RVV 用例评测（正常用例 100% 通过）+ matmul 性能分析
- **待扩展**：15 个大数据用例（gemma 核函数/highmem，需 TCM 扩容）将作为第二轮评测

---

## 8. 结论

coralnpu RISC-V 核已成功集成到 S2C DualV7 板卡并构建完整 SoC（TileLink-UL 总线 + RVV 向量核 + SRAM + 外设），20MHz 下时序完全收敛、资源利用率 38%。606 个 RVV 测试用例评测通过率 100%（正常用例），矩阵乘实测性能为理论值 7-25%，功能正确性已验证，性能优化空间明确。
