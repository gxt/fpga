# Changelog

任务对仓库代码的实质改动记录（由 `/complete` 追加）。

| 日期 | 描述 | 执行方 |
| --- | --- | --- |
| 2026-08-18 | T007：主仓库 `sim/` 新增自定义测试程序（t007_scalar_fp_test.c、t007_rvv_add_test.c、t007_tcm.ld、build/run 脚本、README、.gitignore），coralnpu/ 零改动 | engineer |
| 2026-08-18 | T008：主仓库 `synth/` 新增机器202综合工作流（sync.sh push/pull/exec、README、.gitignore），registry.md 传输命令与 synth-server.md 拓扑三要素更新，coralnpu/ 零改动 | engineer |
| 2026-08-18 | T010：主仓库 `synth/` 新增 AXI 桥接顶层（rtl/ 5 SV：top_coralnpu/uart_rx/uart_tx/host_cmd_fsm/axi_master_stub）+ xdc/tcl/sim（tb_top.sv），产出上板 bitstream，coralnpu/ 零改动 | engineer |
| 2026-08-20 | T012：主仓库 `synth/tcl/` 新增 program_top.tcl（Hardware Manager 烧录/识别脚本，probe/program 两模式），板卡烧录验证通过，coralnpu/ 零改动 | 主会话/engineer |

| 2026-08-21 | T015：主仓库 `synth/rtl/uart_rx.sv`（rx 2 级同步器 + DIV 四舍五入）、`uart_tx.sv`（DIV）、`host_cmd_fsm.sv`/`top_coralnpu.sv`（host_tcm 直写分支加/删，方案A清理后恢复纯 AXI）、`build_top.tcl`（phys_opt -hold_fix）；**coralnpu fork 实验性改动**：CoreAxi host_tcm 端口（d74e0ac8 加 → 8225240f 移除，净零）+ host_clang wrapper clang-14（保留，Ubuntu 24.04 构建必需）；T007 上板 ALL PASS | 主会话/engineer |
| 2026-08-21 | T016：无 RTL 改动（复用 T010-clean + T015 UART 修复），上板 Debug 写 TCM ALL PASS（阶段A xsim + 阶段B 上板），新增/复用 `sim/T016-debug_write_tcm.py` | 主会话/engineer |
| 2026-08-21 | T013：无代码改动（T015 覆盖 NPU 上板验证），补 ADR-004 差异说明（验收4） | 主会话/engineer |
| 2026-08-21 | 目录整理（023c6bf）：新增 `scripts/`（run202*.sh + 综合/烧录 tcl + t016_xsim*.sh 从家目录纳入），`sim/` 与 `synth/sim/` 加任务前缀，`build_top.tcl` 产物精简，`synth/out/` 中间版本归档 `_archive/` | 主会话 |
