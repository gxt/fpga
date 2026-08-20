# ADR-001: 仿真路径选择

- 状态：已接受
- 日期：2026-08-16
- 相关任务：T001、T002、T003、T006、T007

## 背景

coralnpu 官方提供三套验证体系：

1. **Cocotb**（`tests/cocotb/`）：Python/Cocotb 驱动 RTL 模型，bazel target `//tests/cocotb:core_mini_axi_sim_cocotb`，无 license 依赖。
2. **Verilator C++ sim**（`tests/verilator_sim/`）：bazel 将 Chisel 生成的 SystemVerilog 编译为 Verilator 模型并配 C++ 仿真器（`core_mini_axi_sim`），无 license 依赖。
3. **UVM**（`tests/uvm/`）：SystemVerilog UVM 测试台，依赖 VCS + license。

环境事实：

- 机器201无 VCS、无 license，UVM 无法运行。
- 系统 verilator 为 4.038（2020-07，过旧），但 bazel 通过 `@rules_hdl//verilator` 使用 **hermetic verilator**（固定版本随依赖拉取），不依赖系统 verilator。
- 已确认：iverilog 未安装；yosys/nextpnr 未安装（Xilinx 器件综合不需要开源链）。

## 决策

1. **采用官方 bazel 流程作为唯一仿真路径**：Cocotb + Verilator C++ sim 两条无 license 路径。
2. **排除 UVM**（`tests/uvm/`）：无 VCS license，仅阅读理解，不执行不移植。
3. **不引入自建仿真流程**（不建 Makefile/xsim/iverilog 流程）：复用上游 bazel target，减少维护面。
4. **系统 verilator 不作为依赖**：仿真模型一律由 bazel 的 hermetic verilator 生成。

## 影响

- 与官方流程一致，测试可回归、可与上游对齐；"复现"证据强。
- 首次 bazel 构建需下载大量第三方依赖（Chisel、opentitan、libsystemctlm-soc、RISC-V 工具链等），耗时数小时，受网络影响。
- RISC-V 交叉工具链由 bazel 构建（`toolchain/build_scripts/`），4 核/11G 内存环境较紧张，构建任务需设置较长超时。
- 仿真范围限制在官方提供的测试集 + 自编 ELF 测试，不覆盖 UVM 场景（如时序收敛类）。

## 已拒绝方案

- **VCS + UVM**：无 license，不可行。
- **升级系统 verilator**：bazel 走 hermetic，系统版本无关，无收益。
- **自建 xsim/iverilog 仿真流程**：重复造轮子，与上游脱节，违背复用优先原则。
