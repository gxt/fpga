# synth/ —— 综合工程（201 维护）+ 机器202 综合工作流

本目录承载综合工程的 RTL/约束/仿真 tb/流程脚本，以及机器202（192.168.200.202）的文件交换工作流。
机器202信息（地址、Vivado 版本）登记在 `.tao/knowledge/registry.md`，执行拓扑见 `.tao/knowledge/synth-server.md`。

## 目录结构

```
synth/
├── rtl/      # 综合 RTL（201 维护）：top_coralnpu.sv 顶层 + uart_rx/tx + host_cmd_fsm + axi_master_stub + wrapper
├── xdc/      # 引脚约束（top_coralnpu.xdc，S2C F1）
├── tb/       # 综合后仿真 tb（T010-*/T016-* 任务前缀）
├── tcl/      # 综合流程脚本：build_top.tcl / program_top.tcl / resume_top.tcl
├── out/      # sync.sh pull 拉回的综合结果（.gitignore 忽略，不进 git）
└── README.md
```

通用同步工具 `scripts/sync.sh`（push/pull/exec，从 registry.md 解析 202 地址）。

## 快速上手

```bash
scripts/sync.sh info                    # 确认机器202连通与 Vivado 版本
scripts/sync.sh push all                # 推送 coralnpu 源码 + core_mini_axi RTL 产物
scripts/sync.sh push rtl rvv_core_mini_axi   # 追加推送 RVV 变体 SV
scripts/sync.sh exec "mkdir -p ~/fpga/workspace"   # 准备机器202工作目录
scripts/sync.sh pull                    # 拉回 workspace/ 结果到 out/（只拉保留项）
```

RTL 产物源路径：`coralnpu/bazel-out/k8-fastbuild/bin/hdl/chisel/src/coralnpu/`
（`bazel build //hdl/chisel/src/coralnpu:<key>_emit_verilog` 产物，见 `.tao/knowledge/coralnpu-build-map.md`）。

## 机器202目录布局（`~/fpga/`）

```
coralnpu/          # 推送的源码（sync.sh push src）
workspace/rtl_out/<key>/   # 推送的 RTL 产物（sync.sh push rtl <key>）
synth/             # 本目录镜像（sync.sh push synth）
workspace/         # 综合工作目录：workspace/<task>-<subtask>/（首次 subtask=first）
```

**Vivado 必须在 `workspace/<task>-<subtask>/` 内运行**（先 cd 进去，杜绝根目录杂散文件）。

## 综合流程（T010 上板工程 core_mini_axi + AXI 桥接）

- 设计：`rtl/`（top_coralnpu.sv + uart_rx/tx + host_cmd_fsm + axi_master_stub）、`xdc/top_coralnpu.xdc`
- 脚本：`tcl/build_top.tcl`（proj 模式 batch 构建）
- 构建（机器202，`export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic`）：
  ```bash
  cd ~/fpga/workspace/<task>-<subtask>
  vivado -mode batch -source ~/fpga/synth/tcl/build_top.tcl \
    -tclargs <work_dir> <rtl_dir> <top_rtl_dir> <xdc_dir>
  ```
  - `<rtl_dir>` = `~/fpga/workspace/rtl_out/core_mini_axi`（CoreMiniAxi.sv）
  - `<top_rtl_dir>` = `~/fpga/synth/rtl`；`<xdc_dir>` = `~/fpga/synth/xdc`
- 产物：`top_coralnpu.bit` / `.bin` + 各阶段 rpt/dcp（保留）；vivado.log/.jou/.cache/.Xil 等可清理
- 仿真验证：`tb/T010-tb_top.sv`（xsim，USE_MMCM=0 直连时钟）—— 用法见文件头注释
- host 协议（RS232 115200 8N1）：W/R/S/Q/? 命令，详见 `.tao/knowledge/synth-notes.md` T010 节
