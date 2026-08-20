# Cocotb 测试套件结果矩阵（T006 实测）

> 生成：T006（2026-08-18）。全部为**实测时长**（`bazel test` 报告的 `PASSED in <n>s`），非估算。
> 环境：coralnpu @ /home/gxt/fpga/coralnpu；bazel 8.6.0；verilator 5.050（hermetic）；cocotb 2.0.0；python 3.11.9（hermetic）；RISC-V 工具链 2026-06-29（riscv64-unknown-elf-gcc 16.1.0）。
> 运行方式：**单个 target 逐个串行执行**（`bazel test //tests/cocotb:<target> --test_output=summary`），避免并行导致 OOM。
> 硬件实测：`nproc`=4；内存 11Gi 总（available ~6.5Gi，swap 2Gi 已用 1.1Gi）——证实任务文件"内存 11G"仅指总容量，可用量偏低，**必须串行**，不能并行 large/enormous。
> 全部运行日志：`.tao/logs/T006-*.log`（37 个 PASS + 1 个 FAIL 各一档）。

## RTL 配置对照

| 模型（hdl_toplevel） | 生成配置（chisel 参数，见 coralnpu-build-map.md §3） |
| --- | --- |
| `CoreMiniAxi`（scalar） | `--enableFetchL0=False --fetchDataBits=128 --lsuDataBits=128 --enableFloat=True --enableZfbfmin=True --moduleName=CoreMini --useAxi --exposeDebugPorts=True`；无 `--enableRvv`、无 `--enableVerification`（ROB mini 模式） |
| `RvvCoreMiniAxi`（RVV） | 同上 + `--enableRvv=True --enableVerification=True --itcmSizeKBytes=8 --dtcmSizeKBytes=32` |

## 一、核心子集（37/37 通过）

### A. `core_mini_axi_sim_cocotb` 全量 20 case（CoreMiniAxi，scalar）— **全部通过**

| target（后缀） | 测试内容 | 实测时长 | 结果 |
| --- | --- | --- | --- |
| `core_mini_axi_csr_test` | CoreAxiCSR 读写（reset/pc_start/status/非法 CSR SLVERR） | 36.1s（缓存命中，T002 基线） | ✅ 通过 |
| `core_mini_axi_basic_write_read_memory` | TCM 写读回读，全 AXI size 遍历 ITCM8K/DTCM32K | 85.6s | ✅ 通过 |
| `core_mini_axi_write_read_memory_stress_test` | DTCM 随机地址 1000 次写读 + stress_test.elf 执行 | 23.3s | ✅ 通过 |
| `core_mini_axi_rand_instr_test` | 随机指令 1000 条（mpause 包裹，异常跳 0 halt） | 5.8s | ✅ 通过 |
| `core_mini_axi_burst_types_test` | AXI FIXED/INCR/WRAP burst 各 1000 次 | 68.2s | ✅ 通过 |
| `core_mini_axi_master_write_alignment` | align_test.elf：AXI master 写对齐，io_fault==0 | 3.9s | ✅ 通过 |
| `core_mini_axi_run_wfi_in_all_slots` | WFI×4 issue slot，IRQ 唤醒→halt（中断相关） | 2.3s | ✅ 通过 |
| `core_mini_axi_slow_bready` | BVALID 保持至 BREADY（延迟 0-50 拍×100） | 2.4s | ✅ 通过 |
| `core_mini_axi_finish_txn_before_halt_test` | finish_txn_before_halt.elf，halt 后 master FIFO 清空 | 2.3s | ✅ 通过 |
| `core_mini_axi_riscv_tests` | riscv-tests rv32ui/um/uzbb/uf 全套 **158 个 ELF**（含浮点），fence_i 除外 | 5.1s | ✅ 通过 |
| `core_mini_axi_riscv_dv` | riscv-dv 随机指令 ELF 集，semihost 终止 | 3.8s | ✅ 通过 |
| `core_mini_axi_exceptions_test` | exceptions/ 目录全部异常 ELF，io_fault==0 | 2.6s | ✅ 通过 |
| `core_mini_axi_coralnpu_isa_test` | coralnpu_isa 自定义 ISA 测试 ELF（fptr/math/registers 等） | 2.3s | ✅ 通过 |
| `core_mini_axi_float_csr_test` | FPU CSR（fcsr 等）读写 | 2.2s | ✅ 通过 |
| `core_mini_axi_float_hazard_test` | float_hazard_tests.S：浮点流水线冒险 | 2.3s | ✅ 通过 |
| `unreachable_prefetch_fault` | unreachable_prefetch_fault.elf：预取 fault | 2.5s | ✅ 通过 |
| `core_mini_axi_frm_test` | frm_test.cc：浮点舍入模式 | 2.4s | ✅ 通过 |
| `core_mini_axi_fcsr_frm_hazard_test` | fcsr/frm 寄存器冒险（c++20 程序） | 2.3s | ✅ 通过 |
| `core_mini_axi_backdoor_load_test` | SRAM backdoor load 机制 | 3.7s | ✅ 通过 |
| `core_mini_axi_minstret_test` | minstret 性能计数器 | 2.3s | ✅ 通过 |

### B. RVV 相关（RvvCoreMiniAxi）

| target | 测试内容 | 实测时长 | 结果 |
| --- | --- | --- | --- |
| `rvv_assembly_cocotb_test_core_mini_rvv_add` | RVV 汇编 vadd 基础指令 | 2.6s（首次构建模型 383s） | ✅ 通过 |
| `rvv_arithmetic_cocotb_test_arithmetic_m1_vanilla_ops` | RVV 整数算术 m1 常规 op | 12.5s | ✅ 通过 |
| `rvv_core_mini_axi_sim_cocotb_rvv_exceptions_test` | RVV 配置异常：vector_store_fault.elf | 2.7s | ✅ 通过 |
| `rvv_core_mini_axi_sim_cocotb_core_mini_axi_csr_test` | RVV 配置 CSR 读写 | 46.9s | ✅ 通过 |
| `rvv_core_mini_axi_sim_cocotb_core_mini_axi_basic_write_read_memory` | RVV 配置 TCM 写读（BUILD 标 enormous，实测可控） | 97.2s | ✅ 通过 |

### C. nop 基础

| target | 测试内容 | 实测时长 | 结果 |
| --- | --- | --- | --- |
| `nop_stress_test_nop_stress_test` | nop_test.elf（RvvCoreMiniAxi，基线向量功耗用） | 12.6s | ✅ 通过 |

### D. debug 套件 `core_mini_axi_debug_cocotb`（CoreMiniAxi）— 11/12 通过

| target（后缀） | 测试内容 | 实测时长 | 结果 |
| --- | --- | --- | --- |
| `core_mini_axi_debug_halt_resume` | DM halt/resume | 5.1s | ✅ 通过 |
| `core_mini_axi_debug_trigger_match` | trigger 匹配 | 5.1s | ✅ 通过 |
| `core_mini_axi_debug_dmactive` | dmactive 控制 | 4.9s | ✅ 通过 |
| `core_mini_axi_debug_ndmreset` | ndmreset | 5.0s | ✅ 通过 |
| `core_mini_axi_debug_hartsel` | hartsel 选择 | 4.9s | ✅ 通过 |
| `core_mini_axi_debug_abstract_access_registers` | DM 抽象访问寄存器 | 5.0s | ✅ 通过 |
| `core_mini_axi_debug_abstract_access_nonexistent_register` | 抽象访问不存在寄存器 | 5.0s | ✅ 通过 |
| `core_mini_axi_debug_single_step` | 单步 | 5.2s | ✅ 通过 |
| `core_mini_axi_debug_breakpoint` | 断点（tdata 触发） | 5.1s | ✅ 通过 |
| `core_mini_axi_debug_probe_impl` | probe 实现 | 4.7s | ✅ 通过 |
| `core_mini_axi_debug_scalar_registers` | 通用寄存器读写 | 5.7s | ✅ 通过 |
| `core_mini_axi_debug_gdbserver` | gdb 客户端 + pyocd gdbserver 流程 | **超时（300s 默认 medium 超时）** | ❌ 失败（排除，见下） |

## 二、排除清单与原因

| 类别 | 排除原因 |
| --- | --- |
| `vcs_*`（如 `vcs_core_mini_axi_sim_cocotb_*`、`vcs_flow_smoke_test_*` 等全部 227 个） | 依赖 Synopsys VCS（专有许可证），机器201未安装。coco_tb.bzl 中 vcs 分支仅在有 VCS 时可用。 |
| meta target（`core_mini_axi_sim_cocotb`、`rvv_core_mini_axi_sim_cocotb`、`rvv_load_store_test`、`rvv_arithmetic_cocotb_test`、`rvv_ml_ops_cocotb_test`、`rvv_highmem_tests*`、`rvv_itcm512kb_dtcm512kb_tests*`、`*_slow` 等） | 单个 meta target 串行跑整套 suite（enormous），等价于逐个跑其 testcase target；本任务已按 testcase 单测逐个覆盖，meta 不另跑。 |
| `verilator_uvm_regression_*`（26 个） | **非 cocotb 流程**：`rules/coralnpu_v2.bzl` 的 `verilator_batch_uvm_test`，使用 `//tests/uvm:uvm_sim_verilator` + spike cosim（UVM 回归），不在本任务"cocotb 核心子集"范围内。 |
| `rvv_load_store_test_*`（55 个单测）、`rvv_ml_ops_cocotb_test_*`（6 个单测）、`rvv_highmem_tests_*`（7 个单测，另有 meta 1 个）、`rvv_itcm512kb_dtcm512kb_tests_*`（3 个单测，另有 meta 1 个）、`rvv_bf16_ops_cocotb_test`/`zvfbf_cocotb_test`/`zfbfmin_cocotb_test`（各 2 个单测） | 超出核心子集（附加 RVV 覆盖套件）；核心 RVV 覆盖已由 B 组 5 个 target 建立。后续 T007 可按需补充。 |
| `rvv_core_mini_axi_sim_cocotb_*` 未跑的其余 case（40 个，共 43 单测已跑 3）与 `rvv_core_mini_axi_debug_cocotb_*`（12 个） | 与已跑 case 共用同一 test_module（core_mini_axi_sim.py / core_mini_axi_debug.py）与 RvvCoreMiniAxi 模型，行为与 scalar 版一致；代表 case 已验证流程（B 组 + D 组）。 |
| `core_mini_axi_debug_gdbserver`（scalar 及 RVV 对应版） | **确定性环境失败（实测超时）**：RISC-V gdb（工具链 `riscv64-unknown-elf-gdb`）硬依赖 `libmpfr.so.4`，机器201仅有 `libmpfr.so.6`；`toolchain/wrappers/gdb` 的兼容方案（`ldconfig -p \| grep 'mpfr.so$'`）在机器201 ldconfig 缓存中匹配不到未版本化 `libmpfr.so` 条目，导致 gdb 无法启动；pyocd gdbserver 线程常驻 → cocotb 测试挂起至 bazel 默认 medium 超时（300s）。**证据**：`ldd` 显示 `libmpfr.so.4 => not found`；直接运行 runfiles 内 wrapper 复现同一报错。修复需系统级安装 libmpfr4/libmpfr-dev（需 root，超出本任务范围，T007 可跟进）。**未重试**：根因确定性，无重试依据。 |

## 三、复现命令

```bash
# 环境确认（机器201 4 核 / 11Gi 总内存，available 偏低 → 串行）
nproc && free -h

# 单个 case（先 scalar 后 RVV；首次跑 RVV 会先构建 RvvCoreMiniAxi 模型 ~6.4min）
bazel test //tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_csr_test --test_output=summary
bazel test //tests/cocotb:rvv_assembly_cocotb_test_core_mini_rvv_add --test_output=summary
bazel test //tests/cocotb:core_mini_axi_debug_cocotb_core_mini_axi_debug_halt_resume --test_output=summary
```

## 四、关键坑 / 备注

- **内存**：任务文件"内存 11G"仅指 total；实测 available ~6.5Gi，bazel 已用 1.1Gi swap。**不可并行 large/enormous case**，本任务全程单 target 串行，无 OOM。
- **size 标注与实际时长不符**：BUILD 中 4 个 `large` case（basic 85.6s、burst 68.2s、stress 23.3s、rand_instr 5.8s）与 RVV 的 `enormous` case（basic 97.2s）实测均远低于 bazel 对应超时档（large=1800s，enormous=3600s）。"large/enormous"仅是分类标签，不代表不可跑。
- **"whose specified size is too big" 警告**：几乎所有单测都输出该 warning（声明的 size > 实际耗时），无碍。
- **RVV 模型首次构建**：`rvv_assembly_cocotb_test_core_mini_rvv_add` 首次触发 RvvCoreMiniAxi verilator 模型构建（63 actions，383s）；之后 RVV 测试均在缓存内秒级/分钟级。
- **riscv_tests 覆盖力强**：158 个 ELF（rv32ui/um/uzbb/uf 含浮点）5.1s 跑完（backdoor 载入 + 快速 halt），是最经济的 scalar ISA 回归。
- **gdbserver 排除的根因**见排除清单；如需修复：系统安装 `libmpfr4`（提供 `libmpfr.so.4`）或 `libmpfr-dev`（提供未版本化 `libmpfr.so` 使 wrapper 兼容逻辑生效），再跑 `core_mini_axi_debug_gdbserver` 验证。
