# synth/ —— 远程综合工作流

本目录承载远程综合服务器（zzx-NF5280 · 192.168.200.202）的文件交换工作流。
服务器信息（地址、Vivado 版本、文件交换方式）登记在 `.tao/knowledge/registry.md`，
执行拓扑三要素见 `.tao/knowledge/synth-server.md`，本目录不重复登记主机地址。

## 文件

- `sync.sh` —— 同步工作流脚本（push/pull/exec），从 registry.md 自动解析服务器地址
- `out/` —— `sync.sh pull` 拉回的综合结果（.gitignore 忽略，不进 git）

## 快速上手

```bash
cd synth
./sync.sh info                  # 确认服务器连通与 Vivado 版本
./sync.sh push all              # 推送 coralnpu 源码 + core_mini_axi RTL 产物
./sync.sh push rtl rvv_core_mini_axi   # 追加推送 RVV 变体 SV
./sync.sh exec "mkdir -p ~/fpga/work"  # 准备远端工作目录
./sync.sh pull                  # 拉回远端 work/ 全部结果到 out/
./sync.sh pull runs             # 只拉回 work/runs/
```

RTL 产物源路径：`coralnpu/bazel-out/k8-fastbuild/bin/hdl/chisel/src/coralnpu/`
（对应 `bazel build //hdl/chisel/src/coralnpu:<key>_emit_verilog` 产物，见
`.tao/knowledge/coralnpu-build-map.md` §1）。

## 远端目录布局（`~/fpga/`）

```
coralnpu/          # 推送的源码（sync.sh push src）
rtl_out/<key>/     # 推送的 RTL 产物（sync.sh push rtl <key>）
synth/             # 本目录镜像（sync.sh push synth）
work/              # 远程综合工作目录：工程、报告、bitstream（sync.sh pull）
```

## T010 上板工程（core_mini_axi + AXI 桥接）

- 设计文件：`rtl/`（top_coralnpu.sv 顶层 + uart_rx/tx + host_cmd_fsm + axi_master_stub）、
  `xdc/top_coralnpu.xdc`（S2C F1 引脚）、`tcl/build_top.tcl`（非工程 batch 构建）
- 构建（服务器，`export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic`）：
  ```bash
  cd ~/fpga/work/T010
  vivado -mode batch -source ~/fpga/synth/tcl/build_top.tcl \
    -tclargs <work_dir> <rtl_dir> <top_rtl_dir> <xdc_dir>
  ```
  - `<rtl_dir>` = `~/fpga/rtl_out/core_mini_axi`（CoreMiniAxi.sv）
  - `<top_rtl_dir>` = `~/fpga/synth/rtl`；`<xdc_dir>` = `~/fpga/synth/xdc`
- 产物：`top_coralnpu.bit` / `.bin` + 各阶段 rpt/dcp
- 仿真验证：`sim/tb_top.sv`（xsim，USE_MMCM=0 直连时钟）—— 用法见文件头注释
- host 协议（RS232 115200 8N1）：W/R/S/Q/? 命令，详见 `.tao/knowledge/synth-notes.md` T010 节
