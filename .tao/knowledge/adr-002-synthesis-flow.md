# ADR-002: 综合流程选择（fusesoc + Vivado，机器202执行）

- 状态：已接受
- 日期：2026-08-16（2026-08-16 修订：明确 T009 官方器件综合为资源基线用途；T010 目标器件路径改走 core_mini_axi，与 ADR-004 一致；2026-08-20 修订：Vivado 职责全迁 202，201 非特殊情况不调用 Vivado）
- 相关任务：T008、T009、T010、T011

## 背景

coralnpu `fpga/` 目录已提供完整的综合基础设施：

- **fusesoc core 文件**：`coralnpu_soc.core`、`chip_nexus.core`、`chip_verilator.core`、`coralnpu_soc_pkg.core` 等，声明 RTL fileset、IP 依赖、参数。
- **Vivado tcl hooks**：`vivado_setup_hooks.tcl`、`vivado_pre_opt_hooks.tcl`、`vivado_hook_write_bitstream_post.tcl`、`convert_stitched_to_bin_smap.tcl`、`create_final_mmi.tcl`、`extract_bram_details.tcl`。
- **官方目标器件**：`xcvu13p-fhga2104-2-e`（Google 内部 Nexus 板，机器201无此硬件）。
- 构建走 bazel `fusesoc_build`（`//fpga:build_chip_nexus_*`）。

环境事实：

- 201（机器201 fpga201）已装 Vivado 2025.1，但**用户指定所有 Vivado 任务在 202 执行**（2026-08-20 调整：201 受内存限制，除烧录 bit/板卡连接外**非特殊情况不调用 Vivado**，特殊情况需咨询用户确认）。
- 机器201上板器件与官方 xcvu13p 不同，需要 XDC/时钟/IP 适配。
- 202 已确认（`gxt@192.168.200.202`、Vivado v2025.1 与机器201一致，见 `.tao/knowledge/registry.md`），承担**仿真 + 综合 + 实现 + bitstream**；202 fpga 目录 git 化（局域网同步）。

## 决策

1. **综合流程采用官方 fusesoc 生成 Vivado 工程的方式**：优先复用上游 core 文件与 tcl hooks，不重写整套 tcl。
2. **Vivado 执行环境为 202**：201 负责 RTL 生成（bazel）、仓库维护、opencode、板卡烧录与连接；**仿真（xsim）与综合/实现/bitstream 全部在 202 执行**（2026-08-20 起）；201 非特殊情况不调用 Vivado（特殊情况咨询用户确认）。
3. **官方器件综合（T009，xcvu13p chip_nexus 路径）仅作资源基线**：验证 fusesoc+Vivado 链路可用性，其资源/时序报告作为对比基线，不用于上板。
4. **目标器件适配（T010）改走 `core_mini_axi` + AXI 桥接顶层**（与 ADR-004 一致，不做完整 SoC 移植）：core_mini_axi 由 bazel 生成 SystemVerilog（`//hdl/chisel/src/coralnpu:core_mini_axi_cc_library`），AXI 桥接顶层与 XDC/时钟/IP 适配放主仓库 `synth/` 下；官方 `fpga/` 中无 core_mini_axi 现成 fusesoc core，需自建轻量 core/顶层（放主仓库），或直接纯 Vivado 工程。
5. 板级任务（T012+）以上板验证为目标，综合验收以 bitstream + 资源/时序报告为准；202 上按任务建子目录并尽可能创建 `.xpr` 工程。

## 影响

- 复用官方流程，适配成本集中在器件相关文件（XDC/时钟树/IP）与自建 AXI 桥接顶层，可控。
- 机器202是综合阶段硬依赖，机器202信息未确认前 T008/T009 无法验收。
- 器件适配工作量与机器201板卡型号相关，可能引入新 IP（如时钟向导、PLL），需关注 IP license；全功能 license 已确认覆盖 xc7v2000t 与 xcvu13p，验证能识别目标器件即可。

## 已拒绝方案

- **自建完整 Vivado tcl 脚本**：重复造轮子，脱离上游维护。
- **机器201承担综合主责**：用户明确指定机器202。
- **开源链 yosys/nextpnr**：目标器件为 Xilinx，开源链覆盖不佳且偏离官方流程。
