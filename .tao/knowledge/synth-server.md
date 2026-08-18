# 综合服务器执行拓扑（synth-server.md）

本文件记录远程综合服务器（zzx-NF5280 · 192.168.200.202）的执行拓扑，由 T008 负责维护细化。服务器硬件/Vivado 信息见 `registry.md`。

## 决策记录

- **执行模式（2026-08-16，用户决策）：路径 A —— 本机 ssh 直连远程执行**
  - 本机会话作为控制端，通过 `ssh gxt@192.168.200.202` 在远程运行 Vivado batch 命令
  - 长任务（综合/实现）用 tmux/nohup 托管，日志拉回本机分析
  - **不在远程部署 opencode**，不启用「远端智能体」路由
  - 若后续长综合迭代拉日志往返频繁，再评估升级路径 B（远程 opencode，待用户再决策）

## 执行拓扑三要素（T008 确定，2026-08-18）

**结论：同步工程后纯 Vivado —— 本地生成/推送 RTL，服务器只跑 synth/impl/bitstream**

| 要素 | 决策 | 依据 |
| --- | --- | --- |
| ① 服务器跑什么 | **同步工程后纯 Vivado**：服务器不跑 bazel/fusesoc，只接受本地推送的 RTL（SystemVerilog）与工程，跑 `vivado -mode batch`（synth/impl/write_bitstream） | 实测服务器无 bazel/bazelisk/fusesoc、无 bazel 缓存（2026-08-18 `which bazel fusesoc` 为空）；装 bazel 全家桶 + 首次拉依赖成本高（本地 8.9G+，含 Chisel/verilator 等仿真依赖，综合并不需要）；T009 约束允许 fusesoc 不可用时走手工组工程偏离路径；ADR-002 决策 4 目标器件走 core_mini_axi 纯 SV |
| ② 依赖到位方式 | **本地 bazel 产物推送**：RTL 在本地 `bazel build //hdl/chisel/src/coralnpu:<key>_emit_verilog` 生成 `.sv/.h/.zip`，`synth/sync.sh push rtl <key>` scp/rsync 推送远端 `~/fpga/rtl_out/<key>/`；服务器不自拉 bazel 缓存。第三方依赖（RISC-V 工具链、IP）不需要到服务器——服务器只碰 SV 与 Vivado 自带 IP | RTL 生成是纯宿主侧流程（Chisel→firtool→SV，见 coralnpu-build-map.md §1）；综合/实现不需要工具链与仿真依赖 |
| ③ 每步执行机器 | RTL 生成（Chisel→SV）：**本地** bazel；综合（synthesis）、实现（place&route）、bitstream：**远端** Vivado batch（本机 ssh 直连 / `sync.sh exec` 托管）；结果（报告/bitstream/日志）**拉回本地**分析 | ADR-002 决策 2：本机不承担综合主责，本机 Vivado 仅辅助（工程查看/报告分析/IP 预生成） |

> 若后续 T009 官方器件（xcvu13p）走 fusesoc 完整流程需要服务器 bazel，可作为增强项评估（需在服务器装 bazelisk 并冷拉依赖，预计与本地同等量级耗时），当前不启用。

## 文件交换

- **标准入口：主仓库 `synth/sync.sh`**（从 registry.md 自动解析服务器地址，`info/push src/push rtl <key>/push synth/pull/exec`）
- 以 rsync 增量为主、scp 单文件为辅（传输命令与远端布局见 `registry.md` 与 `synth/README.md`）：本机推送 coralnpu 源码（`push src`）/ RTL 产物（`push rtl <key>`，远端 `~/fpga/rtl_out/<key>/`）/ 工程 → 远程；远程结果（`~/fpga/work/`）拉回本机 `synth/out/`
- 不把密码/密钥写入脚本或任务文件（ssh 依赖密钥免密，BatchMode）

## 关键命令记录（T008 实测）

- 远程 `vivado -version`（2026-08-18，验收 3）：
  ```
  vivado v2025.1 (64-bit)
  Tool Version Limit: 2025.05
  SW Build 6140274 on Wed May 21 22:58:25 MDT 2025
  IP Build 6138677 on Thu May 22 03:10:11 MDT 2025
  SharedData Build 6139179 on Tue May 20 17:58:58 MDT 2025
  ```
  与本地一致（≥ 项目要求，支持目标器件）
- license 识别目标器件检查（2026-08-18，验收 5，`vivado -mode batch` + `get_parts`）：
  ```
  xc7v2000tflg1925-1: RECOGNIZED -> xc7v2000tflg1925-1
  xcvu13p-fhga2104-2-e: RECOGNIZED -> xcvu13p-fhga2104-2-e
  virtex7 全族 part 数: 203
  ```
  检查 tcl 留存远端 `~/fpga/T008-get_parts.tcl`，完整日志 `.tao/logs/T008-license-get_parts.log`

## T009 实测补充（2026-08-18，官方器件基线综合）

- **license 配置（关键，T010/T011 必须）**：服务器需在综合命令前 `export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic`（Vivado_System_Edition）。T008 的 `get_parts` "RECOGNIZED" ≠ 可综合（不耗 license）；首次综合因无 license 环境变量报 `Common 17-345`。当前仅命令内 export，未持久化（如需可加入 `~/.bashrc` 或综合脚本）
- **官方器件综合流程（实测可行）**：本机 fusesoc 2.4.3 `run --target=synth --setup` 生成工程（官方流程，参数与 `_NEXUS_NAME_MAP` 一致）→ `sync.sh push` 到服务器 → 服务器 `make synth`。服务器无外网/pip 不可装 fusesoc；本地直接 fusesoc_build 会 OOM（内存峰值 22.8G > 本机 11G）
- **内存**：`synth_design` PSS 峰值 22811MB → **服务器（62GiB）为唯一可行综合机**
- **ispyocto**：`ispyocto.core` 的 `../../../external/` 相对路径在非 bazel 环境需 `coralnpu/external/ispyocto` 符号链接
- **综合结果**：xcvu13p-fhga2104-2-e，0 errors，耗时 1h25m39s，资源基线见 `synth-notes.md`
