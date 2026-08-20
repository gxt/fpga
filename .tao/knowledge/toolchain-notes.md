# 工具链笔记

## Bazel / Bazelisk

### 安装方式（2026-08-16，机器201）

- **bazelisk**：`v1.29.0`（官方 release 预编译二进制）
  - 下载：`https://github.com/bazelbuild/bazelisk/releases/download/v1.29.0/bazelisk-linux-amd64`
  - 安装路径：`~/.local/bin/bazelisk`（任务原定 `~/bin`，经用户指示改为 `~/.local/bin`，已在 PATH 中）
  - `~/.local/bin/bazel` 为指向 bazelisk 的符号链接，全局 `bazel` 命令即 bazelisk
- **bazel**：`8.6.0`（由 bazelisk 按 `.bazelversion` 自动下载，缓存于 `~/.cache/bazelisk/`）
  - coralnpu `.bazelversion` 声明 `8.6.0`
- **前置检查**：python3 = `3.10.12`；系统 `srec_cat` **不存在**（coralnpu 通过 bazel 拉取 `@srecord` 源码自行构建，非硬依赖，缺失不阻塞）；系统无 `/usr/bin/bazel`（环境说明中所述 bazel 3.5.1 已不存在，机器201现无系统 bazel）

### 使用方式

- 在任意含 `.bazelversion` 的目录下直接 `bazel <cmd>`，bazelisk 自动切换对应版本
- 首次运行自动下载对应 bazel，下载输出含 "Signed by Bazel Developer"（签名校验通过）

### 坑 / 经验

- `bazelisk version` 与 `bazel help` 并发执行会争用同一 output base lock，后者会等待前者，属正常现象

## Cocotb 快速开始（coralnpu，2026-08-17，T002）

### 实测命令与结果

- 冒烟 target：`//tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_csr_test`（方案 B，见任务 T002）
- 首次构建（含全部依赖拉取 + RISC-V 工具链 + hermetic verilator 源码编译）：`Build completed successfully, 2709 total actions`，Elapsed 1307.9s（约 21.8 min）
- 测试：`PASSED in 45.8s`（cocotb 汇总 `TESTS=1 PASS=1 FAIL=0 SKIP=0`，`core_mini_axi_sim.core_mini_axi_csr_test passed`）
- 二次执行缓存命中：`(cached) PASSED in 33.5s`
- **核心依赖版本（均从外部仓库实测）**：

| 依赖 | 版本/来源 | 说明 |
| --- | --- | --- |
| bazel | 8.6.0 | bazelisk 按 `.bazelversion` 下载，缓存 `~/.cache/bazelisk/`（107M） |
| verilator | cocotb 报告 5.050；源码 configure.ac `5.051 devel` | **hermetic 源码构建**（rules_hdl 依赖 commit `b97df914`），非系统安装；V3*.cpp 全量编译是首次构建耗时大头 |
| cocotb | 2.0.0 | 外部仓库 `coralnpu_pip_deps_cocotb`（python 3.11.9 hermetic），非系统 pip |
| chisel | `org.chipsalliance:chisel_2.13:7.0.0-RC1`（+chisel-plugin 同版本，Maven） | CoreMiniAxi.sv 由 chisel 生成 |
| llvm-firtool | 1.114.0（Maven jar） | chisel → FIRRTL → Verilog 工具链 |
| RISC-V 工具链 | `toolchain_coralnpu_v2-2026-06-29.tar.xz`（GCS `shodan-public-artifacts`） | `riscv64-unknown-elf-gcc 16.1.0`（g6afcc4f6d-dirty），bazel toolchain 方式注册 |
| riscv-tests | `fd4e6cdd03...`（GitHub zip + 0001 patch） | 指令测试集 |
| opentitan | `lowRISC/opentitan` commit `0e3cf6221100...`（zip） | lowrisc 子模块（`lowrisc_opentitan_gh`） |
| RVVI | `5786f0d39b84...`（zip） | RISC-V 验证接口 |
| mpact-riscv | `cb68bd4a2cb8...`（含 `mpact-riscv-openat.patch`） | Google 模拟器，外部仓库 `com_google_mpact-riscv` |
| riscv-isa-sim | `fd72ee2d3e0d...` | spike |
| uvm-verilator | `5a37baacfed0...` | 子模块（`//rules/repos.bzl`） |
| srecord | bazel 拉取自建（替代系统 `srec_cat`） | 系统无 `srec_cat` 不阻塞 |
| rules_hdl | `7a1ba0e8d229...`（bazel_rules_hdl） | 挂 19 个 coralnpu 机器201 patch（cocotb/verilator 相关，`rules/repos.bzl` 引用 0001-0019） |

### 磁盘占用（bazel 缓存）

- `/home/gxt/.cache/bazel`：**8.9G**（output base `.../09e84813.../` 内 external 6.1G + execroot 1.2G）
- `/home/gxt/.cache/bazelisk`：107M（bazel 8.6.0 本体）
- 当前磁盘 `/` 491G 空闲，后续全量 20 case 构建无需清理

### 坑 / 经验（T002）

- 验证类命令重跑（`bazel test`）默认命中 action cache，只显示 `(cached) PASSED`，**看不到 cocotb 详细输出**；要留证需加 `--nocache_test_results --test_output=all`（实测约 46s 真实重跑）
- cocotb 测试输出含 `Cannot read termcap database` / `DeprecationWarning: COCOTB_TESTCASE is deprecated` 等噪音，不影响通过
- 首次构建大部分时间耗在 hermetic verilator 源码编译（约 1/3 actions 为 V3*.cpp），二次构建秒级

## Verilator C++ sim（core_mini_axi_sim，2026-08-17，T003）

### 实测命令与结果

- ELF 构建：`bazel build //examples:coralnpu_v2_hello_world_add_floats` → 成功，产物 `coralnpu_v2_hello_world_add_floats.elf`（RISC-V 32-bit ELF）
- sim 构建：`bazel build //tests/verilator_sim:core_mini_axi_sim` → **首次直接失败**，需加 `--linkopt=-latomic`（见坑）
- 运行（exit 0）：
  ```
  ./bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim \
    --binary ./bazel-out/k8-fastbuild-ST-dd8dc713f32d/bin/examples/coralnpu_v2_hello_world_add_floats.elf
  ```
- 运行输出样例（默认，仅 SystemC 信息）：
  ```
  SystemC 2.3.4-Accellera --- redacted redacted
  Copyright (c) 1996-2022 by all Contributors,
  ALL RIGHTS RESERVED

  Info: /OSCI/SystemC: Simulation stopped by user.
  ```
- `--instr_trace` 追加指令 trace（`PC,INST,REG,DATA` 行），可见 main（0x144）循环 8 轮执行 flw/fadd.s/fsw（PC 0x158–0x174），全部 `trap=no`；`--debug_axi` 追加 TLM 事务日志（ELF 加载回读 Write+Read+Expect 一致、CSR 回读一致、状态 0x30008 回读 = 1）
- **数值预期**：hello_world_add_floats 的 input1/input2 是未初始化 `.data`（链接后 ELF 段全零 = 0.0f），output[i] = 0.0f + 0.0f = 0.0f；程序无打印，验证靠 exit 0 + status 回读 1 + instr_trace trap=no

### 坑 / 经验（T003）

- **`//tests/verilator_sim:core_mini_axi_sim` 链接需 `-latomic`**：链接 `libverilator_lib.a` 时 `verilated.cpp/verilated_threads.cpp` 的 `std::atomic::is_lock_free()` 生成对 `__atomic_is_lock_free` 的外部引用，链接命令默认无 `-latomic` 报 undefined reference。解决：`bazel build //tests/verilator_sim:core_mini_axi_sim --linkopt=-latomic`（不改源码；系统有 `/usr/lib/gcc/x86_64-linux-gnu/11/libatomic.a`）
- **`bazel-bin` 符号链接随最近一次 build 的目标配置切换**：构建 transition 目标（如 `//examples:...`）后 bazel-bin 指向 `bazel-out/k8-fastbuild-ST-<hash>/bin`，构建普通 host 目标（如 `//tests/verilator_sim:core_mini_axi_sim`）后指向 `bazel-out/k8-fastbuild/bin`。因此官方 README 中 `bazel-bin/... --binary bazel-bin/...elf` 混合写法不可靠——直接运行可能因 bazel-bin 指向的配置不含另一产物而报 `open() fd>0` 失败（absl CHECK abort）。**稳妥做法：两个二进制都用 `bazel-out/<配置>/bin/...` 完整路径**（ELF 在 ST 配置目录）
- 运行可执行文件建议显式加 `./` 前缀
- RISC-V 工具链 objdump/readelf/nm 位于 `~/.cache/bazel/_bazel_<user>/<outputbase>/external/toolchain_coralnpu_v2/bin/`（用于检查 ELF 段/符号/反汇编）
