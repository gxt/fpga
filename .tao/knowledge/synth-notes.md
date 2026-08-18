# 综合笔记（synth-notes.md）

本文件记录 fpga 仓库综合相关的实测结果、命令与经验。由各综合任务（T009+）增量补充。

---

## T009：官方器件综合基线（chip_nexus · xcvu13p-fhga2104-2-e）

> **标注：本结果 = 官方器件（xcvu13p）综合基线，供 T010/T011 对比使用，不上板。**

### 结论摘要

- **综合成功**：`synth_design completed successfully`，**0 errors / 1397 warnings**（官方统计行写 0 critical warnings；但日志实际存在 **8 条 `CRITICAL WARNING:`**：3× Synth 8-9873 模块重复定义覆盖 + 5× Common 17-55 XDC `set_property` 无对象；`runme.log` 显示结果未入 cache due to CRITICAL_WARNING——作为基线如实披露）
- 产物路径（远端 `gxt@192.168.200.202`）：
  - 工程根：`~/fpga/work/T009/synth_only/`
  - 综合网表：`.../synth-vivado/com.google.coralnpu_fpga_chip_nexus_0.1.edn`（808MB）、`..._0.1.v`（329MB，329065099 字节）
  - 综合 checkpoint：`.../com.google.coralnpu_fpga_chip_nexus_0.1.runs/synth_1/chip_nexus.dcp`
  - 资源报告：`.../com.google.coralnpu_fpga_chip_nexus_0.1.runs/synth_1/chip_nexus_utilization_synth.rpt`
  - 综合日志：`.../synth-vivado/T009-synth2.log`（本地副本 `.tao/logs/T009-server-synth.log`）
- 本地拉回副本：`synth/out/T009_chip_nexus_synth_only/`（网表太大未拉回，留服务器）

### 执行路径（决策记录）

任务文件提供了 A（服务器 fusesoc）/ B（bazel）/ C（手工 tcl）三路径，最终**采用"本机官方 fusesoc 生成工程 → 服务器 Vivado 综合"的混合路径**，理由：

1. **路径 A 不可行**：服务器无外网（pypi/github 均不通）、无 pip/ensurepip，无法安装 fusesoc
2. **路径 B 不可行**：`fusesoc_build` 规则把 `--setup --build` 绑定，在本地 bazel 跑会直接调本机 Vivado 综合；本机仅 4 核/11G（可用 5G），xcvu13p 综合需 ~23G 内存（实测 PSS 峰值），本机必然 OOM
3. **混合路径**（采用）：本机 pip `fusesoc==2.4.3 + edalize==0.6.1`（与 coralnpu 官方 pin 一致，见 `coralnpu/third_party/python/requirements.bzl`），用官方 core 文件与参数跑 `fusesoc run --target=synth --setup` 生成自包含 Vivado 工程（19MB），rsync 推送服务器，服务器 `make synth` 完成综合
   - 仍是官方 fusesoc 流程（非手工组工程），仅 setup/build 分机器执行；符合 T008 拓扑"服务器不跑 fusesoc/bazel，只跑 vivado"
   - 综合实测内存 22.8G PSS 峰值 → 服务器（62G）是正确执行机

### 实际命令

本机（RTL/工程生成）：
```bash
# 1. bazel 生成 Chisel 子系统产物（core 依赖）
bazel build //fpga/ip/coralnpu_chisel_subsystem_default:rtl_files
# 产出 CoralNPUChiselSubsystem.sv（315627 行/16MB）+ coralnpu_chisel_subsystem_default.core

# 2. fusesoc 环境
pip install fusesoc==2.4.3 edalize==0.6.1 --user
# 坑：ispyocto.core 引用 ../../../external/ispyocto/... 相对路径（bazel 布局），
#     需 ln -s <bazel outputbase>/external/ispyocto coralnpu/external/ispyocto（用后即删）

# 3. fusesoc 生成 Vivado 工程（官方 target synth，参数取自 fpga/BUILD _NEXUS_NAME_MAP）
fusesoc --config=<cfg: [main] cache_root=/tmp/fusesoc-cache> \
  --cores-root=<coralnpu>/fpga \
  --cores-root=<opentitan>/hw \
  --cores-root=<bazel-out>/fpga/ip/coralnpu_chisel_subsystem_default \
  run --target=synth --setup \
  --build-root=<out>/build.chip_nexus_synth_only \
  com.google.coralnpu:fpga:chip_nexus:0.1 \
  --ClockFrequencyMhz=50 --IspClockFrequencyMhz=10 --SpimClockFrequencyMhz=100 \
  --ItcmSizeKBytes=8 --DtcmSizeKBytes=32 --pnr=none
```
服务器（综合）：
```bash
export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic   # 关键！
export PATH=/tools/Xilinx/2025.1/Vivado/bin:$PATH
cd ~/fpga/work/T009/synth_only/synth-vivado
nohup make synth > T009-synth2.log 2>&1 &
```

### 综合耗时（实测）

| 阶段 | 实测值 |
|---|---|
| 工程生成（fusesoc setup，本机） | ~4 分钟 |
| `synth_design`（服务器，elapsed） | **1 小时 25 分 39 秒**（cpu 1h59m42s） |
| 网表写出 write_edif + write_verilog | 27s + 47s |
| 端到端（make synth 启动→完成） | ~1 小时 34 分钟 |
| 综合内存 | PSS 峰值 22,811 MB（main 9,962 + forked 13,164） |

### 资源预估（xcvu13p-fhga2104-2-e，synth 后 report_utilization）

| 资源 | Used | Available | Util% |
|---|---|---|---|
| CLB LUTs（含 LUT as Memory） | 523,889 | 1,728,000 | **30.32%** |
| └ LUT as Logic | 521,449 | 1,728,000 | 30.18% |
| CLB Registers | 125,761 | 3,456,000 | 3.64% |
| CARRY8 | 9,733 | 216,000 | 4.51% |
| F7/F8 Muxes | 23,202 / 4,090 | 864,000 / 432,000 | 2.69% / 0.95% |
| Block RAM Tile（RAMB36） | 2 | 2,688 | 0.07% |
| URAM | 258 | 1,280 | **20.16%** |
| DSP48E2 | 187 | 12,288 | 1.52% |
| Bonded IOB | 82 | 832 | 9.86% |
| BUFGCE | 12 | 384 | 3.13% |
| MMCM | 1 | 16 | 6.25% |

要点：LUT 占用 30%（主要来自 Chisel 生成的 RVV 核 + ISP），URAM 20%（RVV 向量寄存器堆/缓冲），BRAM 几乎为 0（大量 RAM 被综合为 LUTRAM）。**xcvu13p 资源余量充足（>60%），T010 时序收敛空间大。**

### 坑 / 经验（T009）

- **License 是最大坑**：T008 用 `get_parts` 验证"xcvu13p RECOGNIZED"≠ 可综合（那只是 part 数据库识别，不耗 license）。**服务器 Vivado 实际无 license 环境变量**，首次综合报 `Common 17-345 license not found for feature 'Synthesis'`。修复：`export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic`（Vivado_System_Edition，2037 到期）。**此环境变量必须写入后续所有综合命令**。
- **本机不可跑 xcvu13p 综合**：综合需 22.8G 内存峰值，本机 11G 必然 OOM；服务器 16 核/62G 是唯一正确执行机。
- **fusesoc 2.4.3 + edalize 0.6.1 组合**与 Vivado 2025.1 兼容（生成的 tcl 能正常驱动 synth_design）。
- **ispyocto.core 的 `../../../external/` 相对路径**（bazel 布局遗留）在非 bazel 环境会解析失败；解法是建 `coralnpu/external/ispyocto` 符号链接指向 bazel output base 的 external/ispyocto，fusesoc setup 时它会把文件 copy 进工程（工程自包含）。
- **fusesoc setup 的 WARNING**（`... not within the directory containing the core file. deprecated`）与 `backend is deprecated` 可忽略，不影响生成。
- 工程生成使用 `--pnr=none`（synth_only），Makefile 的 `make synth` 目标只产出网表（.edn/.v/.dcp），不跑 impl。
- `get_licensed_features` 不是合法 Tcl 命令（Vivado 无此 API），验证 license 直接跑一次 synth_design 即可。

### 后续（T010/T011）

- T010 目标器件适配：本基线 target 即 xcvu13p（官方器件）；如需换器件/改参数重跑，复用上述 fusesoc 命令改 flags
- T011 资源时序对比：以本笔记资源表为基线
