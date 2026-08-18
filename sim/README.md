# sim/：自定义测试程序（T007）

本目录存放 T007 任务（Phase2：编写自定义测试程序并运行验证）的产出：
在 coralnpu Verilator C++ sim 上运行的自定义 RISC-V 测试程序源码、构建脚本、运行脚本与结果记录。

## 文件清单

| 文件 | 说明 |
|------|------|
| `t007_scalar_fp_test.c` | 标量测试：整数乘法（RV32M）+ 标量浮点加法（RV32F）+ ZBB clz + DTCM 回读自校验 |
| `t007_rvv_add_test.c` | RVV 测试：int32 向量加法（vadd.vv）+ fp32 向量加法（vfadd.vv）+ 标量浮点 + DTCM 回读自校验 |
| `t007_tcm.ld` | 链接脚本（由 coralnpu `toolchain/coralnpu_tcm.ld.tpl` 生成：ITCM 8K@0x0 / DTCM 32K@0x10000 / stack 128B） |
| `build_t007.sh` | 构建脚本：直接调用 `riscv64-unknown-elf-gcc` 交叉编译（不改 coralnpu/ 内任何文件） |
| `run_t007.sh` | 运行脚本：跑两个 Verilator C++ sim 并留存日志 |

## 前置条件

1. coralnpu bazel 缓存已含 `@toolchain_coralnpu_v2`（先跑过 `cd coralnpu && bazel build //examples:coralnpu_v2_hello_world_add_floats`）
2. 已构建两个 sim：
   ```bash
   cd coralnpu
   bazel build //tests/verilator_sim:core_mini_axi_sim --linkopt=-latomic
   bazel build //tests/verilator_sim:rvv_core_mini_axi_sim --linkopt=-latomic
   ```

## 可复现命令

```bash
# 1. 构建两个测试 ELF（产物在 sim/build/）
./sim/build_t007.sh

# 2. 运行（日志留存 .tao/logs/T007-run-scalar.log 与 T007-run-rvv.log）
./sim/run_t007.sh
```

或手动运行（注意用 bazel-out 完整路径，见 toolchain-notes.md）：

```bash
# 标量（scalar-only 配置）
./coralnpu/bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim \
  --binary ./sim/build/t007_scalar_fp_test.elf --instr_trace --debug_axi

# RVV（enableRvv=True 配置）
./coralnpu/bazel-out/k8-fastbuild/bin/tests/verilator_sim/rvv_core_mini_axi_sim \
  --binary ./sim/build/t007_rvv_add_test.elf --instr_trace --debug_axi
```

## 判定机制

- 程序内部自校验：计算结果写回 DTCM（.data 段）后读回，与编译期常量预期逐项比对。
- **全部一致 → main 返回 0** → crt0 success 分支执行 `mpause`（0x08000073）→ core halted →
  sim 读 STATUS CSR（0x30008）= 1 → sim **exit 0**。
- **任一不一致 → main 返回非 0** → crt0 failure 分支执行 `ebreak` → usage fault → core fault →
  sim **exit 1**（已用故意改错预期值的反向验证确认，见下文）。
- 浮点判定：选取可精确表示的值，要求 **bit-exact（0 ULP）**；整数要求按位精确。

## 结果记录（2026-08-18 实测）

### 1. 标量测试 `t007_scalar_fp_test.elf`（core_mini_axi_sim）

| 项 | 预期 | 实测 | 判定 |
|----|------|------|------|
| sim 退出码 | 0 | 0 | ✅ |
| STATUS CSR 0x30008（HALTED） | 1 | 1 | ✅ |
| 指令 trace trap | 全 no | 273 条全 no | ✅ |
| int 乘法 out_mul = {100×7, 200×8, 300×9, 400×10} | {700, 1600, 2700, 4000} | 程序自校验通过（返回 0） | ✅ 按位精确 |
| 浮点加法 fout = {1.5+0.5, 2.25+0.75, 3.125+1.875, 4.5+2.5} | {2.0, 3.0, 5.0, 7.0} | 程序自校验通过 | ✅ 0 ULP |
| clz(0x0000F000) | 16 | 程序自校验通过 | ✅ |

### 2. RVV 测试 `t007_rvv_add_test.elf`（rvv_core_mini_axi_sim）

| 项 | 预期 | 实测 | 判定 |
|----|------|------|------|
| sim 退出码 | 0 | 0 | ✅ |
| STATUS CSR 0x30008（HALTED） | 1 | 1 | ✅ |
| 指令 trace trap | 全 no | 475 条全 no | ✅ |
| int 向量加 out_add[i] = in_a[i]+in_b[i] | {101,202,...,1616} | 程序自校验通过（返回 0） | ✅ 按位精确 |
| fp 向量加 fout_add[i] = fin_a[i]+fin_b[i] | {1.5,3.0,...,24.0} | 程序自校验通过 | ✅ 0 ULP |
| 标量浮点 sout = {1.5+0.5,...} | {2.0,3.0,5.0,7.0} | 程序自校验通过 | ✅ 0 ULP |

### 3. instr_trace 中的数值级证据（来自 `T007-run-rvv.log`，retire 写回端口直接可见）

```
PC        INST      REG  DATA（128 位 retire 数据，v0 位于最低 32 位）
0x1d4   vle32.v   v1   0x00000004000000030000000200000001   ← 读入 in_a[0..3]={1,2,3,4}
0x1d8   vle32.v   v2   0x000001900000012c000000c800000064   ← 读入 in_b[0..3]={100,200,300,400}
0x1dc   vadd.vv   v1   0x000001940000012f000000ca00000065   ← {101,202,303,404} ✅
0x20c   vle32.v   v1   0x4080000040400000400000003f800000   ← fin_a[0..3]={1.0,2.0,3.0,4.0}
0x210   vle32.v   v2   0x400000003fc000003f8000003f000000   ← fin_b[0..3]={0.5,1.0,1.5,2.0}
0x214   vfadd.vv  v1   0x40c0000040900000404000003fc00000   ← {1.5,3.0,4.5,6.0} ✅
0x24c   fadd.s    f7   0x00000000000000000000000040000000   ← 标量 1.5+0.5=2.0 ✅
```

- int vadd 另两可见组：`0x00000328000002c30000025e000001f9`={505,606,707,808}（i=4..7）、
  `0x000004bc00000457000003f20000038d`={909,1010,1111,1212}（i=8..11）✅
- 第 4 组（i=12..15）vadd.vv 未直接出现在 trace 的 retire 数据列，但其结果
  在程序自校验循环的 `lw`（PC 0x270/0x274，读回 DTCM）数据列可见：
  `0x521`=1313、`0x586`=1414、`0x5eb`=1515、`0x650`=1616 ✅
- 综合：trace 中每组可见数据与 `exp_add`/`exp_fadd` 逐字一致（整数按位精确、
  浮点 bit-exact），全部 16 元素由**程序自校验**（main 返回 0）覆盖确认。

### 4. 反向验证（证明自校验真实有效，防造假）

| 实验 | 修改 | sim 退出码 | 预期 |
|------|------|-----------|------|
| scalar 负例 | 把 exp_mul[0] 从 700 改为 701 | 1 | 非 0（失败）✅ |
| rvv 负例 | 把 exp_add[0] 从 101 改为 102 | 1 | 非 0（失败）✅ |

## 覆盖的 ISA/模块特性（对 T004 架构理解的反向验证）

| 测试 | 覆盖特性 | 对应架构知识（T004） |
|------|---------|----------------------|
| 标量 int 乘法 | RV32M `mul`（标量乘法单元 MLU，3 段流水） | microarch.md：MLU 延迟 2 |
| 标量浮点加法 | RV32F `flw/fadd.s/fsw`（标量 FPU） | 指令延迟表：LSU 2+ |
| ZBB `clz` | RV32 位操作扩展（Decode.scala 支持 ZBB 全集） | §2.4：标量解码支持 ZBB |
| RVV int 向量加 | zve32f `vsetvli/vle32.v/vadd.vv/vse32.v` | §5.2：RvvCore 前端 RvvFrontEnd + 后端 ALU |
| RVV fp 向量加 | zve32f `vfadd.vv`（rvv_backend FALU） | §5.2：rvv_backend FALU |
| 向量 load/store | LSU uop 经标量 LSU 访 DTCM | §5.4：LSU 向量 store 打包 |
| DTCM 回读 | .data 段在 DTCM 0x10000；程序读写 + AXI slave 写后读回 Expect | §3.1/§6：TCM 布局与加载 |
| CSR 启动序列 | 0x30004 PC_START → 0x30000 时钟门控/复位 → 0x30008 STATUS=1 | §6.2：ELF 加载执行流程 |
| 退出语义 | `mpause` → halted；`ebreak` → fault | crt0 的 success/failure 分支 |

## 坑 / 记录

- **mini ROB 模式的 instr_trace DATA 列**：`core_mini_axi_sim`（scalar-only，无 `--enableVerification`）下 ROB 跑 mini 模式，`rb_inst_*_bits_data` 不输出有效写回数据（scalar 日志 DATA 恒 0）；`rvv_core_mini_axi_sim` 的 retire 端口能看到真实向量/标量写回数据。因此**数值证据以 rvv 日志的 retire 写回 + 程序自校验退出码为准**。
- **工具链直接调用**：无需修改 coralnpu/ 内 BUILD 文件。用 `riscv64-unknown-elf-gcc -march=rv32imf_zve32f_zicsr_zifencei_zbb_zfbfmin_zvfbfmin_zvfbfwma -mabi=ilp32 -mcmodel=medany -nostdlib` + `--specs=nano.specs` + 复用 crt 源文件即可复现 bazel `coralnpu_v2_binary` 的产物。
- **rvv_core_mini_axi_sim 构建耗时**：约 7.3 分钟（RVV 模型 Chisel→SV→verilator 编译），但 action cache 命中后秒级。
- **链接脚本**：默认配置（8K ITCM / 32K DTCM / 128B stack）从模板直接 sed 替换 `@@` 占位符生成，与 `rules/linker.bzl` 逻辑一致（DTCM 堆用"余量减栈"逻辑）。
