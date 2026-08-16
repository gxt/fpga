# ADR-002: 综合流程选择（fusesoc + Vivado，远程服务器执行）

- 状态：已接受（服务器细节待补充）
- 日期：2026-08-16
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
- 远程服务器地址、Vivado 版本、文件交换方式为待确认项。

## 决策

1. **综合流程采用官方 fusesoc 生成 Vivado 工程的方式**：优先复用上游 core 文件与 tcl hooks，不重写整套 tcl。
2. **综合执行环境为远程服务器**：本机负责 RTL 生成（bazel）、文件同步、结果拉取与报告分析；本机 Vivado 仅做辅助（工程查看、报告查看、IP 预生成）。
3. **器件适配通过主仓库 `synth/` 下的脚本完成**（XDC、时钟、IP 配置覆盖层），不改上游 core 文件；确需修改上游时按 ADR-003 流程走 fork。
4. 板级任务（T012+）以上板验证为目标，综合验收以 bitstream + 资源/时序报告为准。

## 影响

- 复用官方流程，适配成本集中在器件相关文件（XDC/时钟树/IP），可控。
- 远程服务器是综合阶段硬依赖，服务器信息未确认前 T008/T009 无法验收。
- 器件适配工作量与本地板卡型号相关（待确认），可能引入新 IP（如时钟向导、PLL），需关注 IP license。

## 已拒绝方案

- **自建完整 Vivado tcl 脚本**：重复造轮子，脱离上游维护。
- **本机承担综合主责**：用户明确指定远程服务器。
- **开源链 yosys/nextpnr**：目标器件为 Xilinx，开源链覆盖不佳且偏离官方流程。
