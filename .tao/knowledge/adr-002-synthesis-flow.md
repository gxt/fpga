# ADR-002: 综合流程选择（fusesoc + Vivado，远程服务器执行）

- 状态：已接受
- 日期：2026-08-16（2026-08-16 修订：明确 T009 官方器件综合为资源基线用途；T010 目标器件路径改走 core_mini_axi，与 ADR-004 一致）
- 相关任务：T008、T009、T010、T011

## 背景

coralnpu `fpga/` 目录已提供完整的综合基础设施：

- **fusesoc core 文件**：`coralnpu_soc.core`、`chip_nexus.core`、`chip_verilator.core`、`coralnpu_soc_pkg.core` 等，声明 RTL fileset、IP 依赖、参数。
- **Vivado tcl hooks**：`vivado_setup_hooks.tcl`、`vivado_pre_opt_hooks.tcl`、`vivado_hook_write_bitstream_post.tcl`、`convert_stitched_to_bin_smap.tcl`、`create_final_mmi.tcl`、`extract_bram_details.tcl`。
- **官方目标器件**：`xcvu13p-fhga2104-2-e`（Google 内部 Nexus 板，本机无此硬件）。
- 构建走 bazel `fusesoc_build`（`//fpga:build_chip_nexus_*`）。

环境事实：

- 本机已装 Vivado 2025.1（`/tools/Xilinx/2025.1/Vivado/bin/vivado`），但**用户指定综合须在远程服务器执行**（本机不承担综合主责），本机 Vivado 仅辅助。
- 本地上板器件与官方 xcvu13p 不同，需要 XDC/时钟/IP 适配。
- 远程服务器已确认（`gxt@192.168.200.202`、Vivado v2025.1 与本地一致，见 `.tao/knowledge/registry.md`），文件交换方式由 T008 阶段确认。

## 决策

1. **综合流程采用官方 fusesoc 生成 Vivado 工程的方式**：优先复用上游 core 文件与 tcl hooks，不重写整套 tcl。
2. **综合执行环境为远程服务器**：本机负责 RTL 生成（bazel）、文件同步、结果拉取与报告分析；本机 Vivado 仅做辅助（工程查看、报告查看、IP 预生成）。
3. **官方器件综合（T009，xcvu13p chip_nexus 路径）仅作资源基线**：验证 fusesoc+Vivado 链路可用性，其资源/时序报告作为对比基线，不用于上板。
4. **目标器件适配（T010）改走 `core_mini_axi` + AXI 桥接顶层**（与 ADR-004 一致，不做完整 SoC 移植）：core_mini_axi 由 bazel 生成 SystemVerilog（`//hdl/chisel/src/coralnpu:core_mini_axi_cc_library`），AXI 桥接顶层与 XDC/时钟/IP 适配放主仓库 `synth/` 下；官方 `fpga/` 中无 core_mini_axi 现成 fusesoc core，需自建轻量 core/顶层（放主仓库），或直接纯 Vivado 工程，T008 执行拓扑阶段确定。
5. 板级任务（T012+）以上板验证为目标，综合验收以 bitstream + 资源/时序报告为准。

## 影响

- 复用官方流程，适配成本集中在器件相关文件（XDC/时钟树/IP）与自建 AXI 桥接顶层，可控。
- 远程服务器是综合阶段硬依赖，服务器信息未确认前 T008/T009 无法验收。
- 器件适配工作量与本地板卡型号相关，可能引入新 IP（如时钟向导、PLL），需关注 IP license；全功能 license 已确认覆盖 xc7v2000t 与 xcvu13p，验证能识别目标器件即可。

## 已拒绝方案

- **自建完整 Vivado tcl 脚本**：重复造轮子，脱离上游维护。
- **本机承担综合主责**：用户明确指定远程服务器。
- **开源链 yosys/nextpnr**：目标器件为 Xilinx，开源链覆盖不佳且偏离官方流程。
