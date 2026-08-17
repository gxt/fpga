# CoralNPU 构建链路与验证体系地图

> 来源：T005 任务（Phase1）。本文梳理 coralnpu 子模块（`coralnpu/`）的 bazel 构建链路与验证体系，供本仓库后续仿真/综合/板级集成参考。
> 事实来源：coralnpu 仓库构建文件（WORKSPACE、rules/*.bzl、各 BUILD）+ 本机实测 bazel 命令输出（日志留存 `.tao/logs/T005-*.log`）。
> 创建日期：2026-08-17；coralnpu HEAD：`d93b5550`（`Add GetCycleCount API to CoralNPUSimulator and CoreMiniAxiSimulator`）。
> 约定：**「事实」** = 构建文件或 query 输出明文可查证；**「推断」** = 由上下文推导。目标名一律用 bazel label 完整写法。

---

## 0. 总览（两条链路 + 三套验证）

```
RTL 生成链（宿主 x86）：
  Chisel Scala (.scala)
    └─ chisel_binary（scala_binary，main_class=EmitCore）
         └─ genrule *_emit_verilog（配 llvm-firtool）→ SystemVerilog（CoreMiniAxi.sv 等）+ *_parameters.h + *.zip
              └─ verilog_library *_verilog
                   └─ verilator_cc_library（SystemC / 纯 C++ 两种模型）
                        └─ C++ testbench（cc_library）→ 可执行 sim（cc_binary）

软件链（RISC-V rv32 交叉编译，transition 到 //platforms:coralnpu_v2）：
  .cc/.S 源
    └─ coralnpu_v2_binary（_coralnpu_v2_binary，clang -march=rv32imf_zve32f...）
         ├─ 生成 linker script（coralnpu_tcm.ld.tpl → *.ld）
         ├─ cc_common.link → *.elf（ITCM/DTCM 布局）
         ├─ objcopy → *.bin
         └─ srec_cat（@srecord 自建）→ *.vmem
              └─ ELF 加载进 sim（AXI slave 写 TCM + CSR 启动）或 FPGA
```

三套验证入口（详见 §4）：

| 验证体系 | 入口 target | 运行方式 |
|---------|------------|---------|
| Cocotb | `//tests/cocotb:core_mini_axi_sim_cocotb_<testcase>`（meta: `..._sim_cocotb`） | `bazel test` |
| Verilator C++ sim（SystemC tb） | `//tests/verilator_sim:core_mini_axi_sim` | `bazel build` + 直接运行 |
| UVM（VCS + UVM 1.2） | `tests/uvm/`（Makefile 驱动，Bazel 只产出 DUT/ELF） | `make compile && make run`（VCS 环境，本机未执行） |

---

## 1. RTL 生成链：Chisel Scala → SystemVerilog → verilator 模型 → sim

### 1.1 核心规则 `chisel_cc_library`（`rules/chisel.bzl` L143-203）

一个 `chisel_cc_library(name, chisel_lib, emit_class, module_name, ...)` 展开出 **5 个 target**（事实，`rules/chisel.bzl` L153-203）：

| 生成的 target | 规则 | 用途 |
|--------------|------|------|
| `<name>_emit_verilog_binary` | `chisel_binary`（scala_binary） | 运行 Chisel 生成器（main_class=emit_class） |
| `<name>_emit_verilog` | `genrule` | **纯 SystemVerilog 导出**：跑上面的二进制 + `CHISEL_FIRTOOL_PATH` 指向 llvm-firtool，产出 `.sv` + `*_parameters.h` + `.zip` |
| `<name>_verilog` | `verilog_library`（rules_hdl） | 把生成的 `.sv` 包装成 verilog 库 |
| `<name>` | `verilator_cc_library`（rules_hdl，`systemc=True`） | **SystemC 模型**（名字不带后缀的默认是 SystemC） |
| `<name>_cc` | `verilator_cc_library`（rules_hdl，`systemc=False`） | **纯 C++ Verilator 模型** |

> **关键区分（易混淆点）**：
> - `//hdl/chisel/src/coralnpu:core_mini_axi_cc_library` 名中带 `cc_library`，但它**不是 C++ 库**，而是 `verilator_cc_library`（SystemC 模型），它**依赖** `:core_mini_axi_cc_library_verilog`（`module = "..._verilog"`）间接依赖生成的 `.sv`。真正**生成 SV 的 target 是 `:core_mini_axi_cc_library_emit_verilog`**（genrule）。
> - 若需**纯 SystemVerilog 源文件**（如交给 cocotb / VCS / 综合），应使用 `..._emit_verilog`（或 `..._verilog` verilog_library）；若需**可链接的仿真模型**，才用 `..._cc_library`（SystemC）或 `..._cc_library_cc`（纯 C++）。

### 1.2 关键生成 target（`hdl/chisel/src/coralnpu/BUILD`）

| target | 生成 flags（要点） | 产出 SV | 说明 |
|--------|------------------|---------|------|
| `//hdl/chisel/src/coralnpu:core_mini_axi_cc_library`（BUILD L557-577，经 `template_rule` 调 chisel_cc_library） | `--enableFetchL0=False --fetchDataBits=128 --lsuDataBits=128 --enableFloat=True --enableZfbfmin=True --moduleName=CoreMini --useAxi --exposeDebugPorts=True` | `CoreMiniAxi.sv` | **T002/T003 使用的 scalar-only AXI 配置**；无 `--enableRvv`、无 `--enableVerification`（ROB mini 模式，见架构笔记 §4.4） |
| `//hdl/chisel/src/coralnpu:rvv_core_mini_axi_cc_library`（BUILD L710-723 dict 条目，宏调用点 L690） | 同上 + `--enableRvv=True --enableVerification=True --itcmSizeKBytes=8 --dtcmSizeKBytes=32`（经 `RVV_CORE_MINI_AXI_COMMON_GEN_FLAGS`，flags.bzl） | `RvvCoreMiniAxi.sv` | RVV 向量后端使能 |
| `//hdl/chisel/src/coralnpu:core_mini_verification_axi_cc_library`（BUILD L578-595） | + `--enableVerification=True` | `CoreMiniVerificationAxi.sv` | 完整 ROB + RVVI 跟踪 |
| `//hdl/chisel/src/coralnpu:core_mini_highmem_axi_cc_library` | + `--itcmSizeKBytes=1024 --dtcmSizeKBytes=1024` | `CoreMiniHighmemAxi.sv` | 高密 TCM 变体 |
| `//hdl/chisel/src/coralnpu:core_mini_itcm512kb_dtcm512kb_axi_cc_library` | + 512KB TCM | `CoreMini_ITCM512KB_DTCM512KBAxi.sv` | 512KB 变体 |
| 另有 `rvv_core_mini_verification_axi_cc_library`、`rvv_core_mini_highmem_axi_cc_library`、`rvv_core_mini_itcm512kb_dtcm512kb_axi_cc_library`、`vme_core_mini_axi_cc_library`（Zvt/VME）等 | 见 BUILD L724-760、L806-849 | 对应 `.sv` | 同一模板族 |

每个 target 自动带 `_emit_verilog`（SV 导出）、`_verilog`（库）、`_cc`（纯 C++ 模型）子 target。
辅助导出 target：`//hdl/chisel/src/coralnpu:core_mini_axi_bundle`（`verilog_zip_bundle`，把 `core_mini_axi_cc_library_verilog` 的全部 SV 打成 zip，BUILD L861-864）、`//hdl/chisel/src/coralnpu:rvv_core_mini_verification_axi_cc_library_emit_verilog_single_sv`（只取 `.sv` 的 filegroup，UVM 用，BUILD L788-792）。

### 1.3 实测命令（证据，2026-08-17，缓存命中）

```bash
# 纯 SV 导出（genrule，产出 3 个文件）
bazel build //hdl/chisel/src/coralnpu:core_mini_axi_cc_library_emit_verilog
# 输出（日志 .tao/logs/T005-build-emit_verilog.log）：
#   bazel-bin/hdl/chisel/src/coralnpu/CoreMiniAxi.sv
#   bazel-bin/hdl/chisel/src/coralnpu/VCoreMiniAxi_parameters.h
#   bazel-bin/hdl/chisel/src/coralnpu/CoreMiniAxi.zip

# 产物证据：CoreMiniAxi.sv 39835 行，
#   首行 "// Generated by CIRCT firtool-1.114.0-2-g6cf2492e1"
#   L22255 "module CoreMiniAxi("
# （位于 bazel-out/k8-fastbuild/bin/hdl/chisel/src/coralnpu/CoreMiniAxi.sv）
```

生成器工具链（事实）：
- **Chisel 库**：`org.chipsalliance:chisel_2.13:7.0.0-RC1` + chisel-plugin 同版本（Maven，`coralnpu_maven`，WORKSPACE L130-161）
- **FIRRTL 编译器**：`llvm-firtool 1.114.0`（Maven jar，`coralnpu/rules/repos.bzl` L181-186 → `@llvm_firtool`），genrule 通过 `CHISEL_FIRTOOL_PATH=$$(dirname $(execpath @coralnpu_hw//third_party/llvm-firtool:firtool))` 传给生成器
- **firtool-resolver** `org.chipsalliance:firtool-resolver_2.13:2.0.0`（Maven）

### 1.4 C++ testbench → 可执行 sim（`tests/verilator_sim/BUILD`）

依赖链（query 证据见 §5.3）：
```
//tests/verilator_sim:core_mini_axi_sim            (cc_binary，模板 L219-226)
  └─ :core_mini_axi_tb                            (cc_library，模板 L110-209)
       ├─ //hdl/chisel/src/coralnpu:core_mini_axi_cc_library   (SystemC 模型)
       ├─ //hdl/chisel/src/coralnpu:VCoreMiniAxi_parameters.h  (生成头，供 tb 用)
       ├─ :elf / :util / :sim_libs                (elf 加载、fifo、SystemC 模块头)
       ├─ //hdl/verilog:sram_backdoor              (SRAM 后门 DPI)
       ├─ //tests/systemc:Xbar / :instruction_trace
       ├─ @accellera_systemc//:systemc             (SystemC 2.3.4)
       └─ @libsystemctlm_soc                       (Xilinx libsystemctlm-soc，TLM 桥)
```
实测命令（证据，日志 `.tao/logs/T005-build-core_mini_axi_sim.log`）：
```bash
bazel build //tests/verilator_sim:core_mini_axi_sim --linkopt=-latomic
# 坑：链接需 -latomic（见 toolchain-notes.md T003；系统有 /usr/lib/gcc/x86_64-linux-gnu/11/libatomic.a）
# 运行（注意 bazel-bin 符号链接随最近构建目标切换，用 bazel-out 完整路径最稳妥）：
./bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim \
  --binary ./bazel-out/k8-fastbuild-ST-<hash>/bin/examples/coralnpu_v2_hello_world_add_floats.elf
```

---

## 2. 软件链：coralnpu_v2_binary（RISC-V 交叉编译）→ ELF

### 2.1 宏 `coralnpu_v2_binary`（`rules/coralnpu_v2.bzl` L219-336）

- 对每个 `name`，宏产出：
  - `_coralnpu_v2_binary`（自定义 rule，带 `//command_line_option:platforms` transition 到 `//platforms:coralnpu_v2` 或 `..._semihosting`，L25-35）
  - `<name>.elf` / `<name>.bin` / `<name>.vmem` 三个 filegroup（output_group 分别取 elf/binary/vmem，L317-336）
- 实现（L59-196）：
  1. `cc_common.compile` + `cc_common.link`：交叉编译并链接，`linker_script` 由 `generate_linker_script` 从 `toolchain/coralnpu_tcm.ld.tpl` 生成（默认 8KB ITCM / 32KB DTCM / 128B stack；非默认尺寸生成带后缀的 `.ld`，L276-303）
  2. `objcopy -O binary` → `.bin`
  3. `srec_cat`（`@srecord//:srecord`，bazel 从 sourceforge 拉源码自建，替代系统 `srec_cat`）→ `.vmem`（32 位 word，byte-swap）
- 默认 deps：`//toolchain/crt`（crt0 等，`toolchain/crt/BUILD`；semihosting 变体 `//toolchain/crt:crt_semihosting`）
- 工具链注册：WORKSPACE L259-281 拉取 `@toolchain_coralnpu_v2`（GCS tar.xz）并 `register_toolchains("//toolchain:cc_coralnpu_v2_toolchain", "//toolchain:cc_coralnpu_v2_semihosting_toolchain")`
- 交叉编译配置：`toolchain/cc_toolchain_config.bzl`（`-march=rv32imf_zve32f_zicsr_zifencei_zbb_zfbfmin_zvfbfmin_zvfbfwma -mabi=ilp32 -mcmodel=medany -nostdlib`，链接 `--specs=nano.specs`/`htif_nano.specs` + `-nostartfiles`；详见架构笔记 §2）

### 2.2 ELF 布局（ITCM/DTCM，事实）

- 链接脚本模板 `toolchain/coralnpu_tcm.ld.tpl`：ITCM 0x0/8K、DTCM 0x10000/32K、EXTMEM 0x20000000/4096K、DDR 0x80000000/2048M
- `.text/.rodata` → ITCM；`.data/.bss/.heap/.stack` → DTCM；`.extdata` → EXTMEM；`.ddr_data` → DDR；`ENTRY(_start)`
- `.data` 保留 `_ret`（4B）存 main 返回值供外部核检查；`__global_pointer$` 设于 .data+0x800
- T003 实测 ELF：两个 LOAD 段 `0x0(ITCM, R E)` 与 `0x10000(DTCM, RW)`，Entry 0x0（详见架构笔记 §6）

### 2.3 实测命令（证据，日志 `.tao/logs/T005-build-hello_world.log`）

```bash
bazel build //examples:coralnpu_v2_hello_world_add_floats
# 产物（bazel-out/k8-fastbuild-ST-<hash>/bin/examples/ 下）：
#   coralnpu_v2_hello_world_add_floats.elf / .bin / .vmem
```
运行 ELF 的方式：交给 Verilator C++ sim（`--binary xxx.elf`）或 cocotb（`load_elf` + `execute_from`），加载流程见架构笔记 §6.2（AXI slave 写 TCM → 写 PC_START CSR 0x30004 → 开时钟/复位 0x30000 → 轮询 STATUS 0x30008）。

---

## 3. 依赖拉取与缓存

所有外部依赖由 bazel 在首次构建时拉取，缓存于本机 bazel 缓存目录（`~/.cache/bazel/_bazel_<user>/<outputbase>/external/`，磁盘占用见 toolchain-notes.md T002）。拉取方式与来源（事实，WORKSPACE / rules/repos.bzl / MODULE.bazel / rules_hdl）：

| 依赖 | 来源 | 拉取方式 | 缓存 |
|------|------|---------|------|
| **hermetic Verilator** | `https://github.com/verilator/verilator/archive/b97df914ddcbff470c5a37d3c1bd99d9813f4698.tar.gz`（rules_hdl `dependency_support/verilator/verilator.bzl` L25） | 由 `rules_hdl` 的 `rules_hdl_deps` bzlmod extension 拉取（MODULE.bazel L83-84）；所属 `rules_hdl` 仓库挂 19 个 coralnpu 本地 patch（0001-0019，repos.bzl）；verilator 自身 1 个 patch（`0001-Remove-autodetect-of-VERILATOR_ROOT`） | `external/verilator/`（**源码构建**，非系统安装；V3*.cpp 编译是首次构建耗时大头） |
| **RISC-V 工具链** | `https://storage.googleapis.com/shodan-public-artifacts/toolchain_coralnpu_v2-2026-06-29.tar.xz`（WORKSPACE L259-275，sha256 pin） | `http_archive` → `@toolchain_coralnpu_v2` | `external/toolchain_coralnpu_v2/`；bazel toolchain 方式注册，`//toolchain` BUILD 组装 cc_toolchain |
| **rules_hdl**（verilator/cocotb/verilog 规则） | `https://github.com/hdl/bazel_rules_hdl/archive/7a1ba0e8d229200b4628e8a676917fc6b8e165d1.tar.gz`（repos.bzl L133-165） | `http_archive` + 19 个 coralnpu patch（0001-0019） | `external/rules_hdl/` |
| **opentitan**（lowrisc_opentitan_gh） | `https://github.com/lowRISC/opentitan/archive/0e3cf62211004443d6d29f8f6120882376da499a.zip`（repos.bzl L300-309，`fpga_repos`） | `http_archive` + 2 patch；另在 WORKSPACE L219-257 拉其 pip 依赖（`ot_python_deps`） | `external/lowrisc_opentitan_gh/` |
| **libsystemctlm-soc**（Xilinx TLM） | `https://github.com/Xilinx/libsystemctlm-soc/archive/79d624f3c7300a2ead97ca35e683c38f0b6f5021.zip`（repos.bzl L188-196） | `http_archive` + 自建 BUILD（third_party/libsystemctlm-soc） | `external/libsystemctlm_soc/` |
| **SystemC**（accellera_systemc） | `https://github.com/accellera-official/systemc/archive/refs/tags/2.3.4.tar.gz`（deps.bzl L31-40） | `http_archive` + third_party/systemc BUILD | `external/accellera_systemc/` |
| **Chisel / firtool** | Maven Central（`coralnpu_maven` maven_install，WORKSPACE L128-161） | `rules_jvm_external` 的 maven_install + lock file `third_party/maven_install.json` | `external/coralnpu_maven/` |
| **llvm-firtool** | `https://repo1.maven.org/maven2/org/chipsalliance/llvm-firtool/1.114.0/llvm-firtool-1.114.0.jar`（repos.bzl L181-186） | `http_archive`（单 jar）→ `@llvm_firtool` | `external/llvm_firtool/` |
| **cocotb / numpy / pytest** | `coralnpu_pip_deps_cocotb`（hermetic pip，python 3.11.x） | rules_python `pip_parse` + third_party/python/requirements（含 rules_python airgap patch） | `external/coralnpu_pip_deps_cocotb/` |
| **srecord**（srec_cat） | `https://sourceforge.net/projects/srecord/files/srecord/1.65/...`（repos.bzl L217-227） | `http_archive` + BUILD + 1 patch；替代系统缺失的 `srec_cat` | `external/srecord/` |
| **riscv-tests / RVVI / mpact-riscv / riscv-isa-sim / uvm-verilator / cvfpu / common_cells / fpu_div_sqrt_mvp / rocket-chip / tflite-micro / freertos** 等 | 各自 GitHub/zip（repos.bzl / deps.bzl 全文） | `http_archive`/`git_repository` + patches | `external/<repo>/` |

**缓存机制要点**：
- bazel 以 repo 名 + sha256 pin 缓存下载；WORKSPACE 中多数 `http_archive` 带 `sha256`（事实，见上文）——首次下载后不再联网，离线可重建（验证过的：T002 全量构建 21.8 min，二次构建秒级/缓存命中）
- 磁盘位置：`~/.cache/bazel/`（output base 内 `external/` 6.1G + execroot 1.2G，8.9G 总量，2026-08-17 实测）
- bazel 本体：bazelisk 按 `.bazelversion`（= 8.6.0）下载，缓存 `~/.cache/bazelisk/`（107M）

---

## 4. 三套验证体系

### 4.1 Cocotb（`tests/cocotb/`）

- **模型**：`verilator_cocotb_model`（`rules/coco_tb.bzl` L370-418）自定义 rule，直接对**生成的 SV**（`verilog_source = "//hdl/chisel/src/coralnpu:CoreMiniAxi.sv"`，即 emit_verilog 的产物）跑 `verilator -cc --vpi` + cocotb VPI 库（`@coralnpu_pip_deps_cocotb//:cocotb_libs`），产出可执行模型（BUILD L61-116）
- **测试**：`cocotb_test_suite` 宏（L1108+）按 simulator 分派；verilator 分支生成 `<name>_<testcase>` 单测 + `<name>` meta target（tags 含 `manual` + `verilator_cocotb_test_suite`，L530-542）
- **入口**（BUILD L183-219）：
  - meta：`//tests/cocotb:core_mini_axi_sim_cocotb`（一次跑 CORE_MINI_AXI_SIM_TESTCASES 全部 20 个 case；enormous）
  - 单测：`//tests/cocotb:core_mini_axi_sim_cocotb_<testcase>`，如 `..._core_mini_axi_csr_test`
  - RVV 版：`//tests/cocotb:rvv_core_mini_axi_sim_cocotb` / `..._<testcase>`
- **运行命令**（T002 实测，日志见 toolchain-notes.md §Cocotb）：
  ```bash
  bazel test //tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_csr_test
  # 复跑留证加：--nocache_test_results --test_output=all
  ```
- 测试源码：`tests/cocotb/core_mini_axi_sim.py`（Python，test_module），testcase 在 BUILD L119-141 列表；测试程序（.cc/.S）用 `coralnpu_v2_binary` 编译后作为 data（`COCOTB_TEST_BINARY_TARGETS`）

### 4.2 Verilator C++ sim（SystemC testbench，`tests/verilator_sim/`）

- **模型**：`chisel_cc_library` 生成的 **SystemC** `verilator_cc_library`（`//hdl/chisel/src/coralnpu:core_mini_axi_cc_library`）
- **testbench**：`core_mini_axi_tb.cc`（AXI slave 模拟、ELF 加载、CSR 启动、halted 检测，模板 BUILD L110-209）+ `core_mini_axi_sim.cc`（main，absl flags）
- **入口**（BUILD L219-266）：
  - `//tests/verilator_sim:core_mini_axi_sim`（CoreMiniAxi，scalar-only）
  - `//tests/verilator_sim:rvv_core_mini_axi_sim`、`..._highmem_...`、`..._itcm512kb_...`、`..._verification_axi_sim` 等
  - 单元测试（cc_test）：`core_mini_axi_non_incr_tests`、`backdoor_load_test`、`dbus2axi_tb`、`l1dcache_tb` 等
- **运行命令**（T003 实测）：
  ```bash
  bazel build //tests/verilator_sim:core_mini_axi_sim --linkopt=-latomic
  bazel build //examples:coralnpu_v2_hello_world_add_floats
  ./bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim \
    --binary ./bazel-out/k8-fastbuild-ST-<hash>/bin/examples/coralnpu_v2_hello_world_add_floats.elf \
    [--instr_trace] [--debug_axi]
  ```

### 4.3 UVM（`tests/uvm/`，仅说明不执行）

- 位置：`tests/uvm/`（tb/common/env/tests/coralnpu_dv.f/Makefile），DUT 为 `RvvCoreMiniVerificationAxi`
- **技术栈**：Synopsys VCS + UVM 1.2（README 声明）；cocosim 用 `@coralnpu-mpact-verilator` 静态库（本地 target 为 `coralnpu_cosim_lib_static_archive`，BUILD L79-82；`coralnpu_cosim_lib_static` 是上游仓库内的 label）
- **bazel 侧 target**（BUILD L84-111）：`//tests/uvm:uvm_sim_verilator`（`verilator_model`，但 README 明确运行需 VCS；注意该 target 用了 `rvv_core_mini_verification_axi_cc_library_emit_verilog_single_sv`）；批量回归由 `collect_coralnpu_elfs()`（rules/coralnpu_v2.bzl L418-440）为每个 `coralnpu_v2_binary` 生成 `verilator_uvm_regression_<name>` 测试（tag `verilator-uvm-regression`）
- **运行流程**（README，本机未执行，无 VCS/license）：
  1. `bazel build //tests/cocotb/tutorial:coralnpu_v2_program` 生成 program.elf（Bazel 只负责 DUT SV 与 ELF）
  2. 拷贝到 `tests/uvm/bin/program.elf`
  3. `make compile`（VCS 编译，输出 sim_work/simv）
  4. `make run` 或 `make run UVM_TESTNAME=... TEST_ELF=... UVM_VERBOSITY=UVM_HIGH`
- 需要 `CORALNPU_MPACT` 环境变量或依赖 bazel 缓存解析

---

## 5. bazel query / cquery 证据（2026-08-17，coralnpu HEAD d93b5550）

选用说明：**`bazel query` 是构建图静态查询（不关心配置/平台，输出 target 定义）**；**`bazel cquery` 是配置化查询（展开到具体 configuration，可用于查 transition 后的 target）**。本任务用 `query --output=build` 看规则定义与属性，用 `query 'deps(x, n)'` 看依赖关系，`cquery` 验证配置展开。命令与原始输出原文留存于 `.tao/logs/T005-*.log`。

### 5.1 query --output=build：core_mini_axi_cc_library（SystemC verilator_cc_library）

命令：
```bash
bazel query --output=build '//hdl/chisel/src/coralnpu:core_mini_axi_cc_library'
```
输出要点（完整见 `.tao/logs/T005-query-core_mini_axi_cc_library-build.log`）：
```
# /home/gxt/fpga/coralnpu/hdl/chisel/src/coralnpu/BUILD:557:14
verilator_cc_library(
  name = "core_mini_axi_cc_library",
  visibility = ["//visibility:public"],
  generator_name = "core_mini_axi_cc_library",
  generator_function = "template_rule",
  generator_location = "hdl/chisel/src/coralnpu/BUILD:557:14",
  module = "//hdl/chisel/src/coralnpu:core_mini_axi_cc_library_verilog",
  module_top = "CoreMiniAxi",
  vopts = [...],
  systemc = True,
)
```

### 5.2 query --output=build：core_mini_axi_cc_library_emit_verilog（纯 SV 导出 genrule）

命令：
```bash
bazel query --output=build '//hdl/chisel/src/coralnpu:core_mini_axi_cc_library_emit_verilog'
```
输出要点（完整见 `.tao/logs/T005-query-emit_verilog-build.log`）：
```
# /home/gxt/fpga/coralnpu/hdl/chisel/src/coralnpu/BUILD:557:14
genrule(
  name = "core_mini_axi_cc_library_emit_verilog",
  srcs = [],
  tools = ["//hdl/chisel/src/coralnpu:core_mini_axi_cc_library_emit_verilog_binary", "//third_party/llvm-firtool:firtool"],
  outs = ["//hdl/chisel/src/coralnpu:CoreMiniAxi.sv", "//hdl/chisel/src/coralnpu:VCoreMiniAxi_parameters.h", "//hdl/chisel/src/coralnpu:CoreMiniAxi.zip"],
  cmd = "CHISEL_FIRTOOL_PATH=$$(dirname $(execpath @coralnpu_hw//third_party/llvm-firtool:firtool)) ./$(location core_mini_axi_cc_library_emit_verilog_binary) --target-dir=$(RULEDIR) --enableFetchL0=False --fetchDataBits=128 --lsuDataBits=128 --enableFloat=True --enableZfbfmin=True --moduleName=CoreMini --useAxi --exposeDebugPorts=True",
)
```

### 5.3 deps()：Verilator C++ sim 的依赖（2 层）

命令：
```bash
bazel query 'deps(//tests/verilator_sim:core_mini_axi_sim, 2)'
```
输出（完整见 `.tao/logs/T005-deps-core_mini_axi_sim-2.log`，已过滤 absl/bazel_tools 等样板）：
```
//hdl/chisel/src/coralnpu:VCoreMiniAxi_parameters.h
//hdl/chisel/src/coralnpu:core_mini_axi_cc_library
//hdl/verilog:sram_backdoor
//tests/systemc:Xbar
//tests/systemc:instruction_trace
//tests/verilator_sim:coralnpu/core_mini_axi_sim.cc
//tests/verilator_sim:coralnpu/core_mini_axi_tb.cc
//tests/verilator_sim:coralnpu/core_mini_axi_tb.h
//tests/verilator_sim:core_mini_axi_sim
//tests/verilator_sim:core_mini_axi_tb
//tests/verilator_sim:elf
//tests/verilator_sim:sim_libs
//tests/verilator_sim:util
@accellera_systemc//:systemc
@libsystemctlm_soc//:libsystemctlm_soc
@platforms//os:windows
```

### 5.4 query --output=build：cocotb meta target

命令：
```bash
bazel query --output=build '//tests/cocotb:core_mini_axi_sim_cocotb'
```
输出要点（完整见 `.tao/logs/T005-query-cocotb-meta-build.log`）：
```
# /home/gxt/fpga/coralnpu/tests/cocotb/BUILD:183:14
cocotb_test(
  name = "core_mini_axi_sim_cocotb",
  tags = ["cpu:2", "manual", "testcases_vname=CORE_MINI_AXI_SIM_TESTCASES", "verilator_cocotb_test_suite"],
  size = "enormous",
  hdl_toplevel = "CoreMiniAxi",
  hdl_toplevel_lang = "verilog",
  model = "//tests/cocotb:core_mini_axi_model",
  seed = "42",
  sim = ["@verilator//:verilator", "@verilator//:verilator_bin"],
  sim_name = "verilator",
  test_module = ["//tests/cocotb:core_mini_axi_sim.py"],
)
```

### 5.5 query --output=build：软件链入口

命令：
```bash
bazel query --output=build '//examples:coralnpu_v2_hello_world_add_floats'
```
输出要点（完整见 `.tao/logs/T005-query-hello_world-build.log`）：
```
# /home/gxt/fpga/coralnpu/examples/BUILD.bazel:19:19
_coralnpu_v2_binary(
  name = "coralnpu_v2_hello_world_add_floats",
  srcs = ["//examples:hello_world_add_floats.cc"],
  deps = ["//toolchain/crt:crt"],
  linker_script = "//examples:coralnpu_v2_hello_world_add_floats.ld",
  semihosting = False,
  word_size = 32,
  enable_vmem = True,
)
```

### 5.6 补充证据（rvv 变体 / cquery / build 可复现）

- `bazel query --output=build '//hdl/chisel/src/coralnpu:rvv_core_mini_axi_cc_library'` → `verilator_cc_library(..., module = "...:rvv_core_mini_axi_cc_library_verilog", module_top = "RvvCoreMiniAxi", systemc = True)`（`.tao/logs/T005-query-rvv_core_mini_axi_cc_library-build.log`）
- `bazel cquery '//tests/verilator_sim:core_mini_axi_sim'` → `//tests/verilator_sim:core_mini_axi_sim (4a7dfb7)`（配置哈希，`.tao/logs/T005-cquery-core_mini_axi_sim.log`）
- `bazel query 'kind(cc_binary, //tests/verilator_sim:*)'` → 全部 11 个 sim 可执行文件
- `bazel query 'deps(//hdl/chisel/src/coralnpu:core_mini_axi_cc_library, 1)'` → `core_mini_axi_cc_library`、`core_mini_axi_cc_library_verilog`、`@rules_hdl//verilator/private:verilator_copy_tree` 等（`.tao/logs/T005-deps-core_mini_axi_cc_library-1.log`）

### 5.7 build 可复现验证（2026-08-17，缓存命中）

| 命令 | 结果 | 日志 |
|------|------|------|
| `bazel build //hdl/chisel/src/coralnpu:core_mini_axi_cc_library_emit_verilog` | 成功（1151 action cache hit），产出 CoreMiniAxi.sv / VCoreMiniAxi_parameters.h / CoreMiniAxi.zip | `T005-build-emit_verilog.log` |
| `bazel build //examples:coralnpu_v2_hello_world_add_floats` | 成功（14 action cache hit），产出 .elf / .bin / .vmem | `T005-build-hello_world.log` |
| `bazel build //tests/verilator_sim:core_mini_axi_sim --linkopt=-latomic` | 成功（2688 action cache hit） | `T005-build-core_mini_axi_sim.log` |

> 复现注意：上述 build 缓存命中基于 T002/T003 已构建的 action cache；reviewer 若冷跑，`emit_verilog` 需首次编译 Chisel（scala_binary + firtool），耗时以分钟计，属正常。

---

## 6. 常用命令速查

```bash
# RTL 生成链
bazel build //hdl/chisel/src/coralnpu:core_mini_axi_cc_library_emit_verilog          # 纯 SV 导出（.sv/.h/.zip）
bazel build //hdl/chisel/src/coralnpu:core_mini_axi_cc_library                        # SystemC 模型
bazel build //hdl/chisel/src/coralnpu:core_mini_axi_cc_library_cc                     # 纯 C++ 模型
bazel build //hdl/chisel/src/coralnpu:core_mini_axi_bundle                            # SV 打包 zip

# 软件链
bazel build //examples:coralnpu_v2_hello_world_add_floats                             # ELF/BIN/VMEM

# 三套验证
bazel test  //tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_csr_test           # Cocotb 单测
bazel build //tests/verilator_sim:core_mini_axi_sim --linkopt=-latomic                # C++ sim 构建
./bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim --binary <elf>     # C++ sim 运行
(cd tests/uvm && make compile && make run)                                            # UVM（需 VCS，本机未执行）

# 依赖查询
bazel query --output=build '//hdl/chisel/src/coralnpu:core_mini_axi_cc_library'
bazel query 'deps(//tests/verilator_sim:core_mini_axi_sim, 2)'
bazel cquery '//tests/verilator_sim:core_mini_axi_sim'
```

---

## 7. 坑 / 经验（T005）

- **`core_mini_axi_cc_library` 名字带 `cc_library` 但实际是 SystemC verilator 模型**，不是 C++ 库；纯 SV 要看 `_emit_verilog`。命名容易误导，query `--output=build` 可一眼看出真实规则种类（`verilator_cc_library(... systemc=True)`）。
- **bazel query 与 cquery 用途不同**：query 静态、不限配置；cquery 展开配置。查 target 定义用 query，查"某个配置下会构建什么"用 cquery。
- **`deps(x, 2)` 输出含大量样板依赖**（absl、bazel_tools、remotejdk 等），笔记留存时按需过滤，但**原始完整日志保留在 `.tao/logs/`**。
- **bazel-bin 符号链接随最近构建目标切换**（T003 已记录）：`emit_verilog` 产物在 `bazel-out/k8-fastbuild/bin/...`，而 ELF 在 `bazel-out/k8-fastbuild-ST-<hash>/bin/...`（ST = transition），混用路径会踩坑。
- **UVM 目标 `//tests/uvm:uvm_sim_verilator` 只是 bazel 侧模型 target**，README 声明运行依赖 VCS + UVM 1.2 + MPACT cosim，本机无 VCS 环境仅记录不执行。
- 本任务全部命令为查询/构建（缓存命中），无代码改动，无 build 失败。
