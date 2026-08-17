# CoralNPU 架构知识笔记

> 来源：T004 任务。本文基于 coralnpu 子模块文档与 RTL 源码研读，用于本仓库后续仿真/综合/板级集成工作。
> 约定：**「事实」** = 文档或源码明文可查证；**「推断」** = 由 RTL/上下文推导，未经官方文档确认。所有引用给出仓库内路径（相对 `coralnpu/`）。
> 创建日期：2026-08-17

---

## 1. 总体架构：scalar + vector(RVV) + matrix 三类组件

### 1.1 官方描述（事实）

CoralNPU 是 32 位 RISC-V 指令集的 ML 推理加速器，包含三个协作的处理组件：

> "Coral NPU includes three distinct processor components that work together:
> matrix, vector (SIMD), and scalar."
> —— `coralnpu/README.md` L12-13

> "CoralNPU is a RISCV CPU built with custom SIMD instructions and microarchitectural
> decisions that align with the dataplane properties of an ML accelerator. The design
> of CoralNPU starts with domain and matrix capabilities; vector and scalar
> capabilities are then added for a fused design."
> —— `coralnpu/doc/overview.md` L3-5

### 1.2 数据流（事实 + 推断）

- **Scalar 前端**（`coralnpu/doc/overview.md` L14-23）：
  - 简单的 RISC-V 标量前端（rv32im）驱动 ML+SIMD 后端的命令队列。
  - run-to-completion 执行模型（无 OS、无中断），控制任务卸载到 SMC。
  - C 扩展编码被回收（按 RISC-V 规范）用于 SIMD 寄存器索引（6b）、类型编码与指令压缩（stripmining）。
  - 标量核是 in-order、无推测的机器。
  - 寄存器：标量 31 个（zero, x1..x31，32 位）+ CSR。
- **Vector 后端**（`coralnpu/doc/overview.md` L34-44）：
  - SIMD/vector 通用称呼，指"无变长行为"的简单实用 SIMD 指令集。
  - 标量前端与后端通过 FIFO 结构解耦：vector 指令在向量寄存器依赖解析后才投递到相关命令队列。
  - 支持 8/16/32 位数据宽度。
  - 寄存器：向量 64 个 v0..v63（256 位，如 int32×8）+ 累加器 acc<8><8>（8×8×32 位）。
  - **注意**：README 说 256-bit，但当前 RTL 参数 `rvvVlen = 128`（见 §5.2），128 位向量寄存器 + 未来 256 位。overview.md 的 v0..v63 与 RTL 的 `rvvRegCount = 32`（v0..v31）不一致。
- **Matrix（MAC）**（`coralnpu/doc/overview.md` L47-60）：
  - 核心是量化外积乘加引擎（quantized outer product multiply-accumulate engine）。
  - 一个轴为并行广播（"wide"，卷积权重），另一轴为转置平移的多 batch 输入（"narrow"，如 MobileNet XY batching）。
  - 垂直排列多个 VDOT opcodes：每 VDOT 用 4×8bit 乘法归约到 32 位累加器，每周期 256 次 MAC。
  - RTL 对应 `coralnpu/hdl/verilog/rvv/design/rvv_backend_mac_unit.sv`（mac8 单元，VLEN/2 个 tile、每个 4×4 元素，见 §5.3）。
- **Stripmining**（`coralnpu/doc/overview.md` L62-71）：
  - 折叠数组级并行以适配硬件并行度；指令编码显式包含 stripmine 机制：一次前端 dispatch 事件 → 4 个串行 issue 事件进 SIMD 单元。
  - 例："vadd v0" 在 Dispatch 产生 "vadd v0 : vadd v1 : vadd v2 : vadd v3"，作为 4 个离散事件处理。
  - （推断：该机制对应 RTL 中 RvvCore 前端 RvvFrontEnd 的指令展开，见 §5.2。）

### 1.3 RTL 顶层结构（事实）

`coralnpu/hdl/chisel/src/coralnpu/Core.scala` L63-66：

```scala
val score   = SCore(p)                       // 标量核（Chisel）
val rvvCore = Option.when(p.enableRvv)(RvvCore(p))  // 向量/矩阵后端（SV）
```

- `SCore`（`coralnpu/hdl/chisel/src/coralnpu/scalar/SCore.scala`）：标量前端 + 4×ALU + 4×BRU + 1×MLU + 1×DVU + LSU + CSR + FaultManager + RetirementBuffer。
- `RvvCore`（`coralnpu/hdl/chisel/src/coralnpu/rvv/RvvCore.scala`）：Chisel `RvvCoreShim` → 内联生成的 `RvvCoreWrapper` → 纯 SystemVerilog `RvvCore.sv`（`coralnpu/hdl/verilog/rvv/design/RvvCore.sv`），内含 RvvFrontEnd（前端）+ rvv_backend（后端）。
- 顶层总线：`ibus`（指令）、`dbus`（数据）、`ebus`（外部）—— 见 §3。

---

## 2. ISA 配置差异（三处并列）

### 2.1 三处声明的差异（事实）

| # | 出处 | 声明 ISA | 说明 |
|---|------|---------|------|
| 1 | `coralnpu/README.md` L22 | `rv32imf_zve32x_zicsr_zifencei_zbb` | README 特征描述。**zve32x = 整数向量扩展（无 FP）** |
| 2 | `coralnpu/toolchain/cc_toolchain_config.bzl` L164（is_rv64=False 分支） | `rv32imf_zve32f_zicsr_zifencei_zbb_zfbfmin_zvfbfmin_zvfbfwma` | **实际编译 -march**。zve32f = 含 FP 向量、额外 bf16 向量扩展 |
| 3 | `coralnpu/toolchain/build_scripts/coralnpu_v2_toolchain_build.sh` L49 | `rv32imf_zicsr_zifencei_zbb-ilp32--;rv64imf_zicsr_zifencei_zbb-lp64--` | GCC **multilib 生成器**，**无向量扩展** |

### 2.2 实际 ELF 验证（事实）

对 T003 构建的 ELF `bazel-out/k8-fastbuild-ST-dd8dc713f32d/bin/examples/coralnpu_v2_hello_world_add_floats.elf` 执行 `riscv64-unknown-elf-readelf -A`（工具链位于 `~/.cache/bazel/_bazel_gxt/<outputbase>/external/toolchain_coralnpu_v2/bin/`）：

```
Tag_RISCV_arch: "rv32i2p1_m2p0_f2p2_zicsr2p0_zifencei2p0_zmmul1p0_zfbfmin1p0_zfhmin1p0_zbb1p0_zve32f1p0_zve32x1p0_zvfbfmin1p0_zvfbfwma1p0_zvl32b1p0"
```

即实际链接产物用了**第 2 处**（cc_toolchain_config.bzl）的配置，且隐含了 zmmul（乘除扩展中的 M 的一部分）、zfhmin（半精度 FP）、zvl32b。第 1/3 处声明的 ISA 与实际编译不符。

### 2.3 差异解读（推断）

- cc_toolchain_config.bzl 是编译时唯一权威（clang 显式传 `-march=`，见该文件 L164-178）；README 的 `zve32x` 与实际 `zve32f` 相差 FP 向量指令支持；multilib 的 gcc 默认 ISA 仅是用于 newlib/libgcc 库构建的基线，链接目标代码仍由 clang 的 `-march` 决定。
- 因此：**软件可用的 ISA = zve32f + bf16 向量扩展**；README 描述过时（历史为 zve32x）；multilib 仅约束运行库。

### 2.4 其他 ISA 事实

- 标量解码（`coralnpu/hdl/chisel/src/coralnpu/scalar/Decode.scala`）支持 RV32I/M + ZBB（andn/orn/xnor/clz/ctz/cpop/max/maxu/min/minu/sextb/sexth/rol/ror/orcb/rev8/zexth/rori）+ 浮点（RV32F + bf16）+ RVV + 特权指令（mret/ecall/ebreak/wfi/mpause）。
- 编译标志：`-march=<上述>`、`-mabi=ilp32`、`-mcmodel=medany`、`-nostdlib`（`cc_toolchain_config.bzl` L166-178）；链接 `--specs=nano.specs` / `--specs=htif_nano.specs`（semihosting）与 `-nostartfiles`（L180-216）。
- 工具链编译器为 clang 20（`coralnpu/toolchain/build_scripts/coralnpu_v2_toolchain_build.sh` L58）+ GCC 16.1.0 multilib + newlib + libgloss-htif（crt0.S 中 `--with-multilib-generator` 无向量，但 L125-126 为 crt0.S 补 `.option arch, +zicsr`）。

---

## 3. 存储层次

### 3.1 TCM（事实）

| 区域 | 地址范围 | 大小 | 对齐 | 出处 |
|------|---------|------|------|------|
| ITCM | `0x0000 - 0x1FFF` | 8KB | 4 字节 | `coralnpu/doc/integration_guide.md` L159 |
| DTCM | `0x10000 - 0x17FFF` | 32KB | 1 字节 | 同上 L160 |
| CSR | `0x30000 - TBD` | TBD | 4 字节 | 同上 L161 |

- RTL 参数一致：`coralnpu/hdl/chisel/src/coralnpu/Parameters.scala` L44-48（MemoryRegions.default：ITCM 0x0/8KB、DTCM 0x10000/32KB、Peripheral 0x30000/4KB）；`itcmSizeKBytesDefault=8`、`dtcmSizeKBytesDefault=32`（L59-60）。
- highmem 变体：ITCM/DTCM 各 1024KB，DTCM 基址改 0x100000、CSR 改 0x200000（L49-55；`Core.scala` L158-165 当尺寸非默认时自动切 highmem 布局）。
- TCM 是单周期 SRAM（README L29："Both memories are single-cycle-latency SRAM"）。RTL：`TCM.scala` 的 TCM128（128 位宽 SRAM）；CoreAxi 中 ITCM/DTCM 用 3 端口仲裁（core ibus/dbus、AXI slave、debug 模块），见 `coralnpu/hdl/chisel/src/coralnpu/CoreAxi.scala` L150-241。

### 3.2 L1 Cache（事实 + 重要差异）

- 文档：`coralnpu/doc/overview.md` L73-90：
  - L1Icache **8KB**（256b 块 × 256 slots，4-way 组相联）。
  - L1Dcache **16KB**（SIMD256b），4-way，**双 bank**（每 bank 8KB，类似 L1Icache），支持下一行预取；兼作标量与 SIMD 指令的对齐缓冲。
- RTL 参数：`Parameters.scala` L162-174：`l1islots=256`、`l1iassoc=4`；`l1dslots=256`、`l1dassoc=4`；`axi0DataBits=fetchDataBits`、`axi1DataBits=lsuDataBits`。
- **重要事实**：`L1ICache.scala` / `L1DCache.scala` **只定义接口，未在任何 Core/CoreAxi/CoreTlul 模块中被实例化**（grep 结果仅 Parameters.scala 引用）。它们是为 Chipyard/TLUL 类集成预留。当前 `core_mini_axi` 配置（T002/T003 使用的）用 `enableFetchL0=False` → `UncachedFetch`（`SCore.scala` L56-57），**不使用 L1 cache，指令/数据直接走 TCM 或 AXI**。
- 结论：README/overview 描述的 L1 cache 是官方完整 SoC 集成形态；`core_mini_axi`（scalar-only AXI 配置）没有 L1 cache 参与。

### 3.3 AXI master / slave（事实）

`coralnpu/doc/integration_guide.md` 定义：

- **s_axi（slave）**：AXI4 slave，可写 TCM、访问 CoralNPU CSR（L25）。RTL 路径：AxiSlave → FabricMux → TCM/CSR（`CoreAxi.scala` L243-253）。
  - AR/AW：`prot` 忽略、`id` 需在响应中回显、`len` 突发减 1、`size` 1/2/4/8/16、`burst` 0/1/2(FIXED/INCR/WRAP)（L80-91）。
  - R 通道 resp：0/OKAY 或 2/SLVERR（L99）。
  - 不支持 USER 信号。
- **m_axi（master）**：CoralNPU 读写外部内存/CSR（L26）。RTL 路径：
  - 写：仅 ebus 用（DBus2Axi id=0）→ `io.axi_master.write`（`CoreAxi.scala` L260-262）。
  - 读：ebus（id=0）与 ibus 出 ITCM 后的 IBus2Axi（id=1）经 CoralNPURRArbiter 仲裁，读数据按 ID 回路由（L264-282）。
  - 信号语义：`addr`、`prot` 恒 2（unprivileged/insecure/data）、`id` 恒 0、`burst` 恒 1(INCR)、`lock=0`、`cache=0`（device non-bufferable）、`qos=0`、`region=0`；`size` 1/2/4 字节（L36-74）。
- **复位**：同步复位策略，复位有效时需跑一个时钟周期再放开内部时钟门控（L164-165）。
- **外部调试/状态信号**：`irqn`（低有效中断）、`wfi`（高有效=等待中断且时钟门控）、`debug`（4 条 fetch lane 的 en/addr/inst + cycles + dbus + dispatch + regfile + float + rb）、`halted`、`fault`（`integration_guide.md` L21-31、L119-151；其中 `debug.rb` 为 RTL 端口，见 `hdl/chisel/src/coralnpu/SCore.scala` L599）。

### 3.4 外部内存映射

- 链接脚本（`coralnpu/toolchain/coralnpu_tcm.ld.tpl` L5-10）：ITCM 0x0/8K、DTCM 0x10000/32K、EXTMEM 0x20000000/4096K、DDR 0x80000000/2048M。
- 实际生成的 .ld（T003 产物 `.../examples/coralnpu_v2_hello_world_add_floats.ld`）：`ITCM ORIGIN=0x0 LENGTH=8K`、`DTCM ORIGIN=0x10000 LENGTH=32K`（默认 8/32KB 时）；非默认尺寸时 DTCM 基址切 0x100000（`coralnpu/rules/linker.bzl` L26-30）。

---

## 4. 微架构

### 4.1 流水线级数：**文档两处不一致，并列记录**

- **README（事实）**：`coralnpu/README.md` L24：**"Four-stage processor, in-order dispatch, out-of-order retire"**。
- **microarch 文档（事实）**：`coralnpu/doc/microarch/microarch.md` L7-8：**"The CoralNPU base processor is an in-order three-stage pipeline capable of dispatching up to 4 instructions per cycle."** 三阶段：
  1. **Instruction fetch**：从内存取指令进指令缓冲。
  2. **Decode/Dispatch**：解码指令缓冲前 4 条；interlock 与 scoreboard 决定哪些可派发；指令转发到各自执行单元。
  3. **Execute/Writeback**：执行单元读寄存器文件、计算、同周期写回。
- **差异**：README 声称 Four-stage，microarch.md 明确 three-stage。两处均未在文档内互相引用或解释。

**RTL 侧证据（推断）**：
- `SCore.scala` L54-65 的实例化顺序：`regfile → fetch → csr → dispatch(DispatchV2) → lsu → fault_manager → retirement_buffer`。宏观可划分四段：Fetch → Decode/Dispatch → Execute（ALU/BRU/MLU/DVU/LSU/FPU/RvvCore）→ Retire（RetirementBuffer）。
- `dispatch.md` L15-16："All execution units read their operands from the register file **the cycle after** the instructions are dispatched"——dispatch 与执行至少差一拍。
- `microarch.md` L27-30 的执行延迟表：Alu 1、Csr 1、Bru 1、Mlu 2、Dvu 可变、Lsu 2+。
- **推断**：README 的 "Four-stage" 很可能是将 RetirementBuffer 的 retire 视为独立第四阶段（对应 README 的 out-of-order retire 描述）；microarch.md 的 "three-stage" 将 writeback 并入 Execute。**无法从文档确认 README 的 four-stage 具体指什么**，标注为推断。任务要求"核实引导而非断言"：对 stage 数无单一定论，两处权威文档冲突。

### 4.2 指令延迟（事实，microarch.md L23-30）

| 指令类型 | 延迟（周期） | 说明 |
|---------|-------------|------|
| ALU | 1 | add, sub, xor, ... |
| CSR | 1 | |
| BRU | 1 | bge, jal, ebreak, ... |
| MLU | 2 | mul, mulh, ... |
| DVU | 可变 | div, rem, ... |
| LSU | 2+ | lw, sw, ... |

- RTL 佐证：`Mlu.scala` 有 Stage1（选择/解码）→ Stage2（乘法）→ Stage3（输出）三段流水；`Dvu.scala` 每周期 1 bit、支持提前终止。

### 4.3 Dispatch（事实）

`coralnpu/doc/microarch/dispatch.md`：

- **In-order**：地址 n 的指令不可派发，n+4 也不考虑（L7-10）。
- **Hazard**：scoreboard 追踪依赖，阻止 RAW 与 WAW；所有执行单元在派发后一拍读寄存器文件 → WAR 永不发生（L13-17）。
- **执行单元约束**：每 lane 有足够 ALU/BRU；**仅 1 个 MLU**（每周期最多 1 条乘法）；非流水单元（DVU）反压；**内存每周期仅 1 条**（L19-28）。
- **控制流**：保守地不越过 `jal/jalr/ebreak/ecall/mret/wfi`（L30-33）。
- **特殊指令**：影响 PC/寄存器文件以外状态的指令只从第一个 slot 执行，且当周期不得派发其他指令：`csrrw/csrrs/csrrc/ebreak/ecall/mret/fence/fenci/wfi`（L35-41）。
- RTL 佐证：`DispatchV2`（`Decode.scala` L316+）实现 4-lane 解码、标量 scoreboard（rdScoreboard/readAfterWrite/writeAfterWrite，L344-381）、浮点 scoreboard（L384-412）、分支交错（L338-341）、特殊指令 slot0 限制。

### 4.4 Retire：RetirementBuffer.scala 与文档 retired 机制的对应/差异

**文档侧**：microarch.md / dispatch.md / overview.md **均未描述 retire 机制**（"retired" 一词仅在 README L24 出现：out-of-order retire）。文档层面的 retire 机制描述缺失。

**RTL 侧**（`coralnpu/hdl/chisel/src/coralnpu/RetirementBuffer.scala`）：

- 是一个 16 项（`retirementBufferSize=16`）循环 ROB，每周期最多 enqueue 4 条（instructionLanes）、最多 dequeue/retire **8 条**（`retirementLanes=8`）（Parameters.scala L124-125）。
- 指令生命周期注释（L44-52）：Dispatched（派发入队）→ Completed（副作用提交）→ Retired（按序出队）。
- 用途：跟踪派发指令的写目标（标量/浮点/向量寄存器 + store 标记），匹配执行单元的乱序写回结果；当条目数据就绪（dataReady）且控制流连续（cfDone）后允许出队。
- **关键差异 1（retire 序）**：README 声称 **"out-of-order retire"**，但 RTL 注释与逻辑均为 **in-order retire**：
  - L50-51："Instructions are dequeued from the buffer **in-order** when they and all preceding instructions are completed."
  - L517-528：`blockRetire` 要求前一条 valid+cfDone，否则阻塞后序退休；`deqReady = Ctz(blockRetire)`。
  - **推断**：README 的 "out-of-order" 更可能指**执行完成乱序**（ROB 用途本即如此），或文档措辞不严谨。此处以 RTL 为准记录为差异。
- **关键差异 2（启用条件）**：`useRetirementBuffer = enableVerification`（Parameters.scala L106）。**默认配置（core_mini_axi_sim）下 ROB 跑 mini 模式**（`SCore.scala` L64：`new RetirementBuffer(p, mini = !p.useRetirementBuffer)`），mini 模式不存指令位（inst 宽度 0），仅输出 `nRetired`（供 CSR 指令计数）与 debug 端口。完整 ROB 模式仅 `core_mini_verification_axi_cc_library`（`--enableVerification=True`）启用（`coralnpu/hdl/chisel/src/coralnpu/BUILD` L578-595）。
- **已知坑（事实，源码注释）**：Parameters.scala L82-87 注明——在 RVV 禁用但 Float 启用的配置（如 core_mini_axi_sim）下，完整 ROB 模式有硬件 bug/hang（"vector store waits and reset oscillations"），因此这些目标必须用 mini 模式；debug 端口与 ROB 模式解耦。
- mini 模式下仍产生 `nRetired` 供 CSR 计数器（`SCore.scala` L190：`csr.io.counters.nRetired := rob_io.nRetired`）。

### 4.5 分支策略（事实）

- `overview.md` L25-27 与 `Fetch.scala` L15-17：fetch 阶段**后向分支假定跳转（taken）、前向分支假定不跳（not-taken）**；若执行结果与 fetch 决策不符则罚一个周期。
- RTL：`Fetch.scala` 含部分解码器识别 JAL/分支（Predecode L108-118），`FetchControlSpec.scala` 有对应测试。

---

## 5. Matrix / Vector 单元关键结构

### 5.1 标量 MLU（mlu.md）

`coralnpu/doc/microarch/mlu.md`：
- 只执行 MUL/MULH/MULHSU/MULHU。
- 单个 MLU 服务 4 个指令 lane，但每周期只派发 1 条（L8-11）。
- 三段流水：Dispatch（接受第一个有效 MLU 指令，下周期处理）→ Compute（用 rs1/rs2 计算）→ Writeback（写回寄存器文件）（L46-55）。
- RTL：`coralnpu/hdl/chisel/src/coralnpu/scalar/Mlu.scala`（Stage1/Stage2/Stage3）。

### 5.2 RVV 前端与后端结构（事实）

- Chisel 侧 `RvvCoreShim`（`coralnpu/hdl/chisel/src/coralnpu/rvv/RvvCore.scala` L705-791）把 SV 接口翻译成 Chisel 接口；SV 核心 `RvvCore.sv`：
  - `RvvFrontEnd`（`coralnpu/hdl/verilog/rvv/design/RvvFrontEnd.sv`）：接收 N=4 条指令（`inst_valid[3:0]`），产生命令队列（CMD_BUFFER_MAX_CAPACITY=16，`RvvCore.sv` L15-16, L104-131）。
  - `rvv_backend`（`coralnpu/hdl/verilog/rvv/design/rvv_backend.sv`）：dispatch → 处理单元（ALU、PMTRDT、MULMAC、DIV、FALU、ZVT）→ ROB → retire → VRF（向量寄存器文件 `rvv_backend_vrf.sv`）。LSU uop 经 `rvv_backend_lsu_remap` 送往标量 LSU（rvv2lsu/lsu2rvv 接口）。
- 参数（Parameters.scala）：`rvvVlen=128`、`rvvRegCount=32`、`rvvRegfileBaseAddr=64`（向量寄存器在 ROB idx 空间从 64 起）。
- **推断**：overview.md 所述 stripmine（1 dispatch → 4 issue）由 RvvFrontEnd 展开，uvop 粒度在 ROB 中记录（`rd_rob2rt_o` 带 `uop_pc`/`last_uop_valid` 字段，见 `RvvCore.scala` 的 GenerateCoreShimSource 与 `RetirementBuffer.scala` L336-361 的 vectorReady 匹配）。

### 5.3 MAC / MULMAC（事实）

- `coralnpu/hdl/verilog/rvv/design/rvv_backend_mulmac.sv`：MUL/MAC 顶层 wrapper，内实例化 `rvv_backend_mac_unit`。
- `rvv_backend_mac_unit.sv` L64-70：mac8 输入（VLEN 字节×字节），`mac8_out` 每个 tile 4×4 元素、共 VLEN/2=64 个 32 位输出；支持 vv/vx、符号扩展、widen、饱和等（对应 VDOT/vwmacc 类指令）。
- 与 overview.md L58-60（"4x 8bit multiplies reduced into 32 bit accumulators and performing 256 MACs per cycle"）对应。
- 软件侧用法：`coralnpu/tests/cocotb/rvv/ml_ops/rvv_matmul.cc` 用标准 RVV intrinsic（`__riscv_vwmacc_vv_i32m8`、`__riscv_vredsum_vs` 等）做 8bit→32bit 累加矩阵乘法——编译器生成指令后由后端 MAC 单元执行。

### 5.4 LSU（lsu.md）与 RTL 对应

`coralnpu/doc/microarch/lsu.md`：
- **Slots**：slot 数据结构管理单条 LSU 操作的内存事务，表内逐字节 active/address/data；TCM 或 AXI 总线逐项清零 active。生命周期：Idle →（Vector Update，仅向量）→ Transfer Memory（scatter/gather 打包）→ Writeback（向量 store 向 RvvCore 应答）→ 回 Idle（LMUL=1）或 Vector Update（LMUL>1）。当前仅用 1 个 slot（L11-54）。
- RTL：`coralnpu/hdl/chisel/src/coralnpu/scalar/Lsu.scala`：
  - 当前实现 `LsuV3`（L66-67，L3210+）：保留站（CircularBufferMulti，容量≥4）接收 4 lane 的 LSU 指令 → `LsuSuperSlot`（L1479）执行 slot 生命周期 → 内存区域判定（ITCM/DTCM/Peripheral/External，L3246-3260）→ 总线（ibus/dbus/ebus）。
  - `LsuSlot`（L449-744）：active/addrs/data 表 + slotIdle()/vectorUpdate()/loadUpdate()，与文档一致。
- 接口（lsu.md L56-143）：LSU 命令接口（req.valid/op/addr/pc/elemWidth/ready）、ibus/dbus/ebus 总线接口（dbus 128 位数据、16 字节掩码、fault 上报）、写回接口（标量 rd / 浮点 rd_flt）、RVV 接口（rvv2lsu 的 idx/vregfile/mask、lsu2rvv 的 addr/data/last）。
- ebus 信号语义（L91-105）：`ebus.fault.valid/write/addr/epc` 供外部总线故障上报；`ebus.internal` 未用。
- RTL 注：`io.dbus.size` 恒为 `lsuDataBytes`（整行），`ebus` 侧再按掩码收窄 size（L3298-3342）。

---

## 6. ELF 加载与执行（与 T002/T003 对照）

### 6.1 链接脚本与 TCM 布局（事实）

- 链接流程：`coralnpu_v2_binary` 宏（`coralnpu/rules/coralnpu_v2.bzl` L219-336）用 `generate_linker_script` 从 `coralnpu/toolchain/coralnpu_tcm.ld.tpl` 生成 .ld，再以 `-Wl,-T,<script>` 链接（L111-123），随后 objcopy 出 `.bin`、srec_cat 出 `.vmem`（L125-178）。
- 默认参数：itcm=8KB、dtcm=32KB、stack=128B、heap 在 DTCM（用"DTCM 余量减栈"逻辑，`coralnpu/rules/linker.bzl` L26-47）。
- 布局（.ld）：`.text/.init.array/.fini.array/.rodata` → ITCM（0x0 起）；`.tdata/.tbss/.htif/.data/.bss/.noinit/.heap/.stack` → DTCM（0x10000 起）；`.extdata/.extbss` → EXTMEM（0x20000000）；`.ddr_data/.ddr_bss` → DDR（0x80000000）；`ENTRY(_start)`。
- `.data` 中保留 `_ret` 4 字节存 main 返回值供外部核检查（.ld L101-103）；`__global_pointer$` 设于 .data+0x800 供 gp 寻址（L91-92）。
- **T003 实测 ELF**（`bazel-out/k8-fastbuild-ST-dd8dc713f32d/bin/examples/coralnpu_v2_hello_world_add_floats.elf`）readelf 节头：`.text` Addr 0x0、`.crt` 0x260、`.data` Addr 0x10000、`.bss` 0x10070、`.heap` 0x100c0、`.stack` 0x17f80；程序头两个 LOAD：`0x0(ITCM, 0x2d0 字节 R E)` 与 `0x10000(DTCM, MemSiz 0x8000 RW)`；Entry point 0x0。
- 反汇编 main（0x144）：`flw/fadd.s/fsw` 循环 8 轮（PC 0x158-0x174），input1@0x10000、input2@0x10020、output@0x10040，全部 trap=no（与 T003 `--instr_trace` 记录一致）。

### 6.2 ELF 如何被加载执行（事实）

sim 端（`coralnpu/tests/verilator_sim/coralnpu/core_mini_axi_sim.cc` L66-81）：

1. `LoadElfSync(binary)`：`elf.cc::LoadElf` 遍历 PT_LOAD 段，按 `p_paddr` 复制到 TCM（`coralnpu/tests/verilator_sim/elf.cc` L20-36）；testbench 对每段生成 AXI slave 的 Write+Read+Expect 事务（写后回读校验，`core_mini_axi_tb.cc` L316-390）。
2. 写 CSR `0x30004`（PC_START）= `e_entry`（=0x0，ITCM 起点；与 integration_guide 的 boot 步骤 2 一致）。
3. `ClockGateSync(false)`：写 CSR `0x30000`=1（bit0 RESET=1 保持复位、bit1 CLOCK_GATE=0 开时钟）。
4. `ResetAsync(false)`：写 CSR `0x30000`=0（释放复位，core 从 PC_START 开始执行）。
5. 等待 `halted` 回调；`CheckStatusSync()` 读 CSR `0x30008` 期待 `1`（STATUS.HALTED=1）。

- 对应 integration_guide.md Booting 流程（L167-218）：初始化 ITCM → 写 PC_START（0x30004）→ 释放时钟门控（0x30000=1）→ 释放复位（0x30000=0）→ 轮询 STATUS（0x30008）。RTL 中 `CoreCSR`（`CoreAxiCSR.scala` L31-163）默认 resetReg=3（RESET=1 且 CLOCK_GATE=1，上电门控+复位），pcStartReg 首拍捕获 `boot_addr` 输入，之后可通过 0x4 覆写。
- 外部（AXI master 写）与内部（core dbus/ebus）访问 TCM/CSR 通过 Fabric 仲裁统一（`CoreAxi.scala` L150-253）；AxiSlave 命中 ITCM/DTCM/CSR 区域即内部响应，否则透传到 AXI master（见 integration_guide 的 Memory Map）。
- 程序结束：main `ret` 回 crt，`mpause`（0x08000073）令 core halted（STATUS.HALTED=1）；semihosting 变体走 `.htif`/tohost 协议（`core_mini_axi_tb.cc` L363-380 查找 tohost 符号）。
- 非 ELF 时（L381-387）：把整个文件按裸二进制从地址 0 写入 ITCM（T002/T003 均为 ELF 路径）。

### 6.3 cocotb 教程视角（事实）

`coralnpu/doc/tutorials/writing_coralnpu_programs.md`（与 6.2 同一加载流程，面向 cocotb testbench）：

1. `load_elf(f)` 复制 ELF 所有可加载段到内存（返回 entry_point，L104-123）。
2. `lookup_symbol(f, "input1_buffer")` 从 `.symtab` 查符号地址（对应 `elf.cc::LookupSymbol`，L38-90），`write(addr, data)` 通过 AXI slave 写入 DTCM（L125-152）。
3. `execute_from(entry_point)` 设置 PC 并启动（对应写 PC_START CSR），`wait_for_halted()` 等待 core 停止（L154-184）。
4. `read(outputs_addr, ...)` 读回 DTCM 结果（L186-214）。
- 程序骨架约定：输入/输出 buffer 用 `__attribute__((section(".data")))` 定义在 `.data`（即 DTCM），链接脚本自动分配地址；host 在程序运行前写 DTCM、程序完成后读 DTCM（L30-38, L44-57）。

---

## 7. 其他要点（供后续工作参考）

- **配置矩阵**（`coralnpu/hdl/chisel/src/coralnpu/BUILD` L557-600）：
  - `core_mini_axi_cc_library`（T002/T003 用）：`--enableFetchL0=False --fetchDataBits=128 --lsuDataBits=128 --enableFloat=True --enableZfbfmin=True --moduleName=CoreMini --useAxi --exposeDebugPorts=True`（**无 enableVerification → ROB mini 模式**）。
  - `core_mini_verification_axi_cc_library`：同上 + `--enableVerification=True`（完整 ROB + RvviTrace）。
  - `rvv_core_mini_axi_cc_library`：+ `--enableRvv=True`（BUILD L710-726）。
  - highmem 变体：`--itcmSizeKBytes=1024 --dtcmSizeKBytes=1024`。
- **RVV 相关已知缺陷**（`coralnpu/rules/coralnpu_v2.bzl` L339-387 DENYLIST）：vmsif/vmsbf/vmsge_vx、masked load/store、部分 fdiv 舍入、fence_i 等被排除回归。
- **时钟门控**：core 空闲（wfi）或 CSR CLOCK_GATE 置位时 `ClockGate`（`ClockGate.scala`）门控核心时钟（CoreAxi L109）。
- **Debug 模块**（`coralnpu/doc/microarch/debug.md`）：实现 RISC-V Debug 规范子集；外部经 AXI CSR 0x30800-0x30814 访问内部寄存器（dmcontrol/dmstatus/abstractcs/command/data0）；支持抽象命令读写 GPR/FP GPR/CSR（regno 0x1000-0x101F 标量、0x1020-0x103F FP）。
- **RVVI 跟踪**：`enableVerification` 下 `RvviTrace`（`RvviTrace.scala`）消费 ROB debug 端口生成 RVVI 迹（SCore L600-603）。

## 8. 文档与 RTL 差异汇总（快速索引）

| 主题 | 文档说法 | RTL/实测 | 判定 |
|------|---------|---------|------|
| 流水线级数 | README Four-stage（L24）vs microarch.md three-stage（L7） | 逻辑四段（Fetch/Dispatch/Execute/Retire） | 文档冲突，无定论；README 与 microarch 并列记录 |
| retire 序 | README "out-of-order retire"（L24） | RetirementBuffer 按序出队（L50-51, L517-528） | RTL 为 in-order retire；差异 |
| ROB 启用 | 文档未提 | 仅 enableVerification 时完整模式，否则 mini | 文档缺失；RTL 行为 |
| ISA | README `zve32x`；multilib 无向量 | 实际编译 `zve32f+bf16`（ELF attributes 证实） | README/multilib 与实际不符 |
| 向量寄存器 | overview v0..v63 256 位 | RTL rvvRegCount=32、rvvVlen=128 | 文档超前（256 位为未来） |
| L1 cache | overview 8KB I / 16KB D 双 bank | 仅在 Parameters 定义，CoreAxi 不实例化 | core_mini_axi 无 L1 cache |
