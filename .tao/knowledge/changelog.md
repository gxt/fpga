# Changelog

任务对仓库代码的实质改动记录（由 `/complete` 追加）。

| 日期 | 描述 | 执行方 |
| --- | --- | --- |
| 2026-08-18 | T007：主仓库 `sim/` 新增自定义测试程序（t007_scalar_fp_test.c、t007_rvv_add_test.c、t007_tcm.ld、build/run 脚本、README、.gitignore），coralnpu/ 零改动 | engineer |
| 2026-08-18 | T008：主仓库 `synth/` 新增机器202综合工作流（sync.sh push/pull/exec、README、.gitignore），registry.md 传输命令与 synth-server.md 拓扑三要素更新，coralnpu/ 零改动 | engineer |
| 2026-08-18 | T010：主仓库 `synth/` 新增 AXI 桥接顶层（rtl/ 5 SV：top_coralnpu/uart_rx/uart_tx/host_cmd_fsm/axi_master_stub）+ xdc/tcl/sim（tb_top.sv），产出上板 bitstream，coralnpu/ 零改动 | engineer |

