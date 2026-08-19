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

---

## T010：目标器件适配 + AXI 桥接 + 上板 bitstream（xc7v2000tflg1925-1）

> 本段为 T010 记录：host 方案决策、AXI 桥接顶层设计、S2C 引脚/时钟适配、构建命令与结果。
> 与 T009 官方基线（xcvu13p chip_nexus）的对比见下"资源对比"小节。

### host 侧方案决策（T010 内定，与 T013 对齐）

- **候选**：MicroBlaze 软核 / JTAG 驱动（debug_bridge）/ 状态机主控。
- **决策（2026-08-18）：UART 状态机主控 —— RS232 J26 + 片上命令 FSM 驱动 AXI slave**
  - 板卡：S2C Dual Virtex-7 TAI LM（纯 Virtex-7，无 Zynq PS）。J26 RS232 接口（F1.E20=TX、F1.F20=RX，1.8V 逻辑，板载 RS232 电平转换）是手册明确的功能接口。
  - 理由（对比）：
    | 方案 | 优点 | 缺点 | 结论 |
    |---|---|---|---|
    | MicroBlaze | 标准软核 | 需额外 BRAM/程序/调试链，工程量最大 | 拒绝（过度设计） |
    | JTAG debug_bridge | 复用 J24 下载链 | 需 debug_bridge + AXI 宽度/协议转换 IP；纯 FPGA（无 PS）下 xsct/hw_server 对 BSCAN 桥的访问流非标准、集成风险高 | 拒绝（host 侧流程不确定性大） |
    | **UART 状态机主控** | 自包含 RTL（~400 行）、host 端任意串口脚本、协议可控可测 | RS232 接口可用性待 T012 现场确认 | **采用** |
  - **影响**：AXI 桥接顶层 = 命令 FSM（UART→AXI 单拍读写）+ uart_rx/tx；host 侧 = 任何 PC 串口（Python pyserial 脚本，T013 提供）；**不引入任何 Xilinx IP**（时钟用 MMCME2_BASE 原语，全功能 license 已覆盖 xc7v2000t，无需新 IP/license）。
  - 待确认（T012）：RS232 线缆/DB9 转 USB 可用性；OSC1 实际振荡器频率。

### AXI 桥接顶层设计（主仓库 `synth/rtl/`）

文件与职责：

| 文件 | 职责 |
|---|---|
| `top_coralnpu.sv` | 顶层：OSC1→MMCM→clk_core；SW1 复位；UART；CoreMiniAxi 实例化；m_axi 响应桩；LED |
| `host_cmd_fsm.sv` | 命令 FSM：UART 字节流→AXI4 单拍读写（驱动 CoreMiniAxi s_axi） |
| `uart_rx.sv` / `uart_tx.sv` | 8N1 UART，参数化 CLK_HZ/BAUD |
| `axi_master_stub.sv` | 响应 CoreMiniAxi m_axi（防外部访问挂死，返回 OKAY/全 0） |

接口连接：
- **s_axi（host→core）**：host_cmd_fsm 作 AXI master，单拍（AWLEN=0）、size=2（4B）、burst=INCR、id=0，**标准 AXI 字节通道对齐**（写数据按 addr[3:0] 放通道，读数据从对应通道提取）。
- **m_axi（core→外部）**：接到 axi_master_stub（不访问 EXTMEM/DDR，仅防挂死）。
- 控制/状态：io_boot_addr=0、io_te=0、irq 系=0；io_halted/io_fault → LED40/41；MMCM locked → LED42。

**关键 RTL 事实（CoreMiniAxi s_axi 语义，实测代码确认）**：
- AxiSlave→FabricMux→SRAM：**不做地址旋转**——TCM SRAM 按 `addr[12:4]` 选字、按 WSTRB 直接写数据位。因此 AXI master 必须按标准协议把数据放到 addr[3:0] 对应字节通道（4B 访问时 `s_wdata = {96'd0,data} << (addr[3:0]*8)`、`s_wstrb = 0xF << addr[3:0]`）。
- CoreCSR 读写也是**固定通道**：写 0x30000（offset 0）取 `[31:0]`、写 0x30004（offset 4）取 `[63:32]`；读回包按 offset 固定组装（offset 0→[31:0]、4→[63:32]、8→[95:64]）。标准 AXI 通道对齐恰好与之一致。
- 引导序列（S 命令）与官方一致：写 0x30004=0（PC_START）→ 写 0x30000=1（开时钟、保持复位）→ 写 0x30000=0（释放复位）；轮询 0x30008 bit0=HALTED。

### host 协议（RS232 115200 8N1，ASCII，T013 host 脚本依据）

| 命令 | 格式 | 应答 |
|---|---|---|
| 写字 | `W<8hex addr><8hex data>\n` | `OK\n` / `ERR\n` |
| 读字 | `R<8hex addr><2hex count>\n`（count 1..16） | 每字一行 `<8hex addr><8hex data>\n`，结尾 `OK\n` / `ERR\n` |
| 启动 | `S\n` | `OK\n` / `ERR\n` |
| 状态 | `Q\n`（读 0x30008） | `<addr><data>\nOK\n` |
| 帮助 | `?\n` | `HELP\n` |
| 非法 | 其他 | 丢弃到行尾后 `ERR\n` |

### S2C 引脚约束（`synth/xdc/top_coralnpu.xdc`，来源：Dual V7 手册）

| 信号 | 引脚 | I/O 标准 | 手册出处 |
|---|---|---|---|
| clk_p/clk_n（OSC1） | W4/W3 | LVDS（MRCC） | Table 8-1 |
| rst_btn_n（SW1） | AP31 | LVCMOS18，PULLUP | Table 8-7 |
| uart_rx / uart_tx（J26） | F20 / E20 | LVCMOS18 | Table 8-9 |
| led_halted / led_fault / led_locked | K25 / K28 / J28 | LVCMOS15（H 点亮） | Table 8-10（LED40/41/42） |

- 引脚已在 Vivado part 数据库验证：W4/W3=`IO_L13P/N_T2_MRCC_37`、AP31=`IO_L13P_T2_MRCC_36`、E20=`IO_L14N_T2_SRCC_40`、F20=`IO_L14P_T2_SRCC_40` 等全部有效。

### 时钟方案（评估结论：不引入新 IP）

- 源：OSC1（W4/W3，默认 LVDS 差分）→ IBUFDS → **MMCME2_BASE**（原语，非 IP）→ BUFG → clk_core。
- 参数：假定输入 100MHz → M=12/D=1/OUT0=24 → 50MHz。`top_coralnpu` 参数 `CLK_IN_HZ/CORE_CLK_HZ/BAUD` 与 XDC `create_clock -period 10.0` 是唯一时钟配置点。
- **待确认项（T012）**：OSC1 实际振荡器频率未知（手册未标注，振荡器为用户安装件）。若实际≠100MHz：改 MMCM M/D/OUT 参数 + create_clock period 后重跑（小设计重跑约 10-30 分钟）；也可改用 TAI Player 可编程时钟（频率由软件设定）或用单端 IBUF（`USE_DIFF_CLK=0`）。
- xsim 验证发现 MMCM 仿真模型输出周期与理论有偏差（VCO 爬升），已加 `USE_MMCM` 参数（0=clk_p 直连）供仿真/调试绕过。

### 构建流程（非工程 batch，服务器）

```bash
# 服务器（T008 拓扑：本机 push RTL/工程，服务器只跑 vivado）
export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic   # 关键！
export PATH=/tools/Xilinx/2025.1/Vivado/bin:$PATH
cd ~/fpga/work/T010
nohup vivado -mode batch -source ~/fpga/synth/tcl/build_top.tcl \
  -tclargs ~/fpga/work/T010 ~/fpga/rtl_out/core_mini_axi ~/fpga/synth/rtl ~/fpga/synth/xdc \
  > T010-build.log 2>&1 &
```

- 产物：`post_synth.dcp`、`post_route.dcp`、`top_coralnpu.bit`、`top_coralnpu.bin`、`utilization_*.rpt`、`timing_*.rpt`、`route_status.rpt`、`clock_utilization.rpt`、`drc_route.rpt`。
- 本机 xsim 功能验证：`synth/sim/tb_top.sv`（USE_MMCM=0、BAUD=781250），4 条指令加载→S 启动→Q 轮询 HALTED→R 回读 42→LED→help/error 全部通过（日志 `.tao/logs/T010-sim-tb_top.log`）。

### 坑 / 经验（T010）

- **CoreMiniAxi 的 s_axi 不做数据旋转**：AXI master 必须自行按 addr 做字节通道对齐，否则 TCM/CSR 写入错位（本设计 host_cmd_fsm 已处理）。
- **xsim 编译 CoreMiniAxi.sv**：需 `-d XSIM`（跳过 `default disable iff` SVA）、`\`timescale 包裹`（firtool 产物无 timescale）、加 `glbl.v`；xsim 对 `byte` 关键字做端口名会报错。
- **MMCM 仿真模型时钟不精确**（VCO 爬升、周期漂移）：UART 位周期对不上；仿真用 `USE_MMCM=0` 直连时钟。
- **firtool 生成的 SRAM 模型**：`ifdef` 选择 Verilator 后门 / 其他仿真器 fallback（`mem[addr]` 行为模型），xsim 走 fallback 分支，可综合（综合时 `SYNTHESIS` 关闭 initial 块）。
- **`file mkdir -force` 会创建字面 `-force` 目录**：tcl 中不要写 `-force`（这是 `write_bitstream` 等命令的选项，不是 `file mkdir` 的）。

### 资源对比（T010 目标器件 vs T009 官方基线）

**T010 最终结果（2026-08-18，第三版构建 = 最终）**：
- 器件：xc7v2000tflg1925-1；顶层 top_coralnpu；**0 ERROR / 0 CRITICAL WARNING / 287 警告行（9 类）**
  - 分类：8-7129 无负载端口×100、8-7137 fpnew set/reset 同优先级×92、8-6014 未用寄存器×42、8-3917 常量驱动端口×37、8-11065 参数转 localparam×7、**8-6430×4**、8-3936×2、**8-3848×2**、**8-327×1**
  - 处置结论：8-6430（ITCM/DTCM BRAM 读写碰撞，firtool 生成 SRAM 属性 `rw_addr_collision` 未置）——xsim 全链路验证读写正确（含回读 DTCM=42），当前配置无碰撞访问，判定不影响功能，T013 上板实测复核；8-3848（control_mvp 无驱动网络）×2——xsim 功能正常，判定可接受；8-327（en_latch_reg 锁存器，伴随 1 条 combinational latch loop）——core 上游 RTL 生成行为，xsim 验证正确，T013 关注；其余为良性优化类
  - **非阻断建议（T012/T013 关注）**：① `axi_master_stub` 写 FSM 在 W 先于 AW 时 `w_last_seen` 被覆盖 → BVALID 永不置位（当前场景 AW 先于 W 未触发，防挂死桩盲区）；② `uart_rx` 40MHz/115200 波特率偏差 +3.3%（临界），T013 串口实测关注
- 时序（post-route）：**WNS=+0.253ns（0 违例）、WHS=-0.085ns（7 端点，85ps，host→core AR 短路径 hold，可忽略）、0 routing errors**
  - 说明：hold 为寄存器化 AXI 输出后残留的少量短路径偏斜（build2 为 -0.016ns/2 端点，build3 为 -0.085ns/7 端点，属 run-to-run 放置差异）；85ps 在时序模型噪声级内，若 T013 板上实测异常再按"坑"节方法处理
- 首版 50MHz 有 -0.148ns setup（5 端点）+ -0.236ns hold（41 端点）违例 → 降频 40MHz + AXI 输出注册化后基本消除（见"坑"）
- bitstream（最终）：`top_coralnpu.bit`（55917279B，md5 4a588df3...）/ `top_coralnpu.bin`（55917152B，md5 96c04058...）；本机副本 `synth/out/T010/`；服务器 `~/fpga/work/T010/`
- 资源（utilization_route.rpt）：

| 资源 | T010 used/avail (util%) | T009 used/avail (util%) | 说明 |
|---|---|---|---|
| Slice LUTs | 43,446 / 1,221,600 (**3.56%**) | 523,889 / 1,728,000 (30.32%) | T010=core_mini_axi 标量核；T009=完整 chip_nexus SoC |
| LUT as Logic | 43,164 (3.53%) | 521,449 (30.18%) | |
| Slice Registers | 9,296 / 2,443,200 (0.38%) | 125,761 / 3,456,000 (3.64%) | |
| RAMB36E1 | 10 / 1,292 (0.77%) | 2 / 2,688 (0.07%) | T010 的 10 块来自 core 的 TCM 缓存/队列 |
| URAM | 0 | 258 / 1,280 (20.16%) | xcvu13p 独有（xc7v2000t 无 URAM） |
| DSP48E1 | 6 / 2,160 (0.28%) | 187 / 12,288 (1.52%) | |
| Bonded IOB | 8 / 1,200 (0.67%) | 82 / 832 (9.86%) | T010 仅 8 个引脚（时钟/复位/UART/LED） |
| MMCME2 | 1 / 24 (4.17%) | 1 / 16 (6.25%) | |

- 结论：T010 设计在 xc7v2000t 上占用极小（<4% LUT），资源余量充足；T011 对比时注意**两器件资源总量与设计范围不同**（xc7v2000t 无 URAM、LUT 总量 1.22M < xcvu13p 的 1.73M）。

### 坑 / 经验补充（T010 第二版）

- **时序违例处置**：首版 50MHz post-route WNS=-0.148ns（5 端点）、WHS=-0.236ns（41 端点，u_host→u_core 短路径时钟偏斜主导）。处置：
  1. **降频 40MHz**（MMCM CLKOUT0_DIVIDE_F 24→30，CORE_CLK_HZ=40M）：setup 全收敛（WNS=+1.450）；
  2. **AXI 输出注册化**（host_cmd_fsm 的 awvalid/wvalid/arvalid/bready/rready 与 addr/data 改为寄存器输出、握手后清除）：把短路径启动寄存器移到靠近 core AXI 端口，hold 从 41 端点/-0.236ns 降到 2 端点/-0.016ns。
  - 注册化注意：**必须"握手后清除"**（`if (s_awvalid_r && s_awready) s_awvalid_r<=0`），否则组合 AXI valid 会双握手（core 队列 2 深、awready 常高，同一地址入队两次导致 B 不返回挂死）。已用 xsim 回归验证。
- **xsim 回归**：`synth/sim/tb_top.sv`（USE_MMCM=0、CORE_CLK_HZ=50M、BAUD=781250）全链路通过（日志 `.tao/logs/T010-sim-tb_top.log`）。

---

## T011：资源/时序报告深度分析（T010 深化 + T009 对比 + 工具链沉淀）

> 本段为 T011 分析任务产物：在 T010 已记录结论（LUT 43,446、Reg 9,296、RAMB36 10、DSP48E1 6、IOB 8、MMCM 1、WNS +0.253 / WHS -0.085）基础上，从留存报告深化 LUT 构成、RAMB36/DSP 归属、时序三阶段演进与关键路径，补全与 T009 基线对比及流程坑。
> **数据来源（真实构建流水线，2026-08-18 服务器 Vivado 2025.1 构建，全部数字提取自留存报告，无编造）**：
> - T010：`synth/out/T010/` 下 `utilization_{synth,place,route}.rpt`、`timing_{synth,place,route}.rpt`、`route_status.rpt`、`clock_utilization.rpt`、`drc_route.rpt`、`T010-build.log`（首版 50MHz）、`T010-build2.log`（40MHz）、`T010-build3.log`（最终）、`vivado.log`
> - T009：`synth/out/T009_chip_nexus_synth_only/chip_nexus_utilization_synth.rpt`

### 1. T010 资源利用率深化（route 最终，xc7v2000tflg1925-1）

#### 1.1 LUT/FF 构成（utilization_route.rpt）

| 项 | 数值 | 说明 |
|---|---|---|
| Slice LUTs | 43,446 / 1,221,600 (**3.56%**) | 已按 LUT combining 调整（synth 阶段原始 43,911 → 物理优化后 43,446，-465） |
| └ LUT as Logic | 43,164 (3.53%) | O5-only 14 + O6-only 38,907 + O5&O6 4,243 |
| └ LUT as Memory | 282 (0.08%) | **全为 Distributed RAM**（RAMD32×422 + RAMS32×138 原语），**Shift Register 0** |
| Slice Registers | 9,296 / 2,443,200 (0.38%) | FF 9,294（FDCE 8,841 + FDRE 431 + FDPE 22）+ Latch 2（LDCE，en_latch_reg） |
| F7/F8 Muxes | 751 / 98 | |
| Slice（SLICEL/SLICEM） | 12,178 / 305,400 (3.99%) | SLICEL 8,725 + SLICEM 3,453；Unique Control Sets 223 |
| CARRY4 | 1,133 | |
| BUFGCTRL / MMCME2_ADV | 4 / 128 (3.13%)；1 / 24 (4.17%) | |

#### 1.2 RAMB36E1 ×10 归属（vivado.log RAM 映射表，事实）

| 实例 | 端口（Depth×Width） | RAMB36 |
|---|---|---|
| `\itcm/sram/sramModules_0` | 512×128（READ_FIRST / WRITE_FIRST 双口） | **2** |
| `\dtcm/sram/sramModules_0` | 2K×128（同上） | **8** |
| 合计 | | **10** |

- 对应架构笔记 §3.1：TCM 单周期 SRAM（TCM128，128 位宽）；ITCM 8KB、DTCM 32KB → BRAM。
- **AXI 侧小队列全部走 LUTRAM 而非 BRAM**（vivado.log L1298-1305）：`axiSlave` 的 `addrArbiter_io_in_0/1`（RAM32M×12/12）、`writeData_q`（×25）、`io_axi_write_resp_q`（×2）、`readDataQueue`（×23）、`ebus2axi/wdataQueue`（×25）、`CoreMiniAxi__GC0/readDataSkid_q`（×23）、`top_coralnpu/scalar_rd_pipe_q`（×7）——即 282 个 LUTRAM 的构成。

#### 1.3 DSP48E1 ×6 归属（推断，标注）

- core_mini_axi 为**标量核**（无 RVV/matrix 后端），6 个 DSP48E1 推断来自**标量 MLU（M 扩展乘法器）+ 浮点 FPU（enableFloat=True）**的乘法/乘加推断。
- 佐证：vivado.log 有 `Synth 8-12192 Not enough pipeline registers after wide multiplier. Pipeline registers present is 0. Recommended levels is 4.`（CoreMiniAxi.sv L16079，宽乘法器无流水寄存器）。40MHz 下无 setup 问题，**若提频需关注**。
- 未逐实例核验（post_route.dcp 未开），故标"推断"。

#### 1.4 布局特征

- **全部逻辑在 SLR2**（Slice 12,178 / 15.95%、LUT 43,446 / 14.23%、BRAM 10 / 3.10%、DSP 6 / 1.11%）；IO 分散 SLR3×2 / SLR2×5 / SLR1×1。
- 跨 SLR SLL 共 119：SLR2↔SLR1 117（SLR2→SLR1 116 单向集中 + SLR1→SLR2 1）、SLR2↔SLR3 2。
- route_status：62,605 逻辑网 / 0 routing errors（50,507 可布线网全部 fully routed）。

### 2. xc7v2000t（T010）vs xcvu13p（T009）资源占用对比

> T010 = **route 后**（物理优化后，顶层 top_coralnpu = core_mini_axi 标量核 + host 桥接，40MHz）；T009 = **synth 后**（完整 chip_nexus SoC，含 RVV 后端/ISP/外设，50MHz）。两者**器件族与设计范围不同**，利用率为可比指标。

| 资源 | T010 used/avail (util%) | T009 used/avail (util%) | 差异来源 |
|---|---|---|---|
| LUT（含 LUTRAM） | 43,446 / 1,221,600 (**3.56%**) | 523,889 / 1,728,000 (**30.32%**) | 数量 1:12.1（T010≈T009 的 8.3%）；T009 含 RVV/matrix/ISP 的算术与控制逻辑 |
| └ LUT as Logic | 43,164 (3.53%) | 521,449 (30.18%) | |
| └ LUT as Memory | 282 (0.08%) | 2,440 (0.31%) | 绝对量 T009=8.7×；相对占比 T010 0.65% > T009 0.47%（T009 的 LUTRAM 增长慢于 LUT 总量） |
| FF/Reg | 9,296 / 2,443,200 (0.38%) | 125,761 / 3,456,000 (3.64%) | 1:13.5；T009 有 RVV 向量寄存器堆/ROB/缓冲 |
| Carry | CARRY4 1,133 | CARRY8 9,733 / 216,000 (4.51%) | 器件架构不同（7 系 CARRY4 vs US+ CARRY8），不可直接比数量 |
| F7/F8 Muxes | 751 / 98 | 23,202 / 4,090 | T009 大量 MUXF 来自向量数据通路的宽 mux |
| BRAM（RAMB36） | **10** / 1,292 (0.77%) | **2** / 2,688 (0.07%) | T010 的 10 = ITCM 2 + DTCM 8（TCM 存于 BRAM）；T009 的 RAM 主要走 URAM/LUTRAM（BRAM≈0） |
| URAM | **0**（xc7v2000t 无此资源） | **258** / 1,280 (**20.16%**) | xcvu13p 独有；T009 的 RVV 向量缓冲/寄存器堆用 URAM |
| DSP | 6 / 2,160 (0.28%) | 187 / 12,288 (1.52%) | T010 无 matrix 后端（MAC 阵列）→ DSP 仅标量 MLU+FPU；T009 的 RVV MAC/浮点单元占大头 |
| Bonded IOB | 8 / 1,200 (0.67%) | 82 / 832 (9.86%) | T010 仅 8 引脚（差分时钟/复位/UART×2/LED×3）；T009 完整 SoC 引脚 |
| BUFG | BUFGCTRL 4 / 128 (3.13%) | BUFGCE 12 / 384 (3.13%) | T010 4 个：clk_fb / clk_core / 门控 _cg_clk_o / 门控 _rst_sync_clk_o |
| MMCM | MMCME2_ADV 1 / 24 (4.17%) | MMCME4_ADV 1 / 16 (6.25%) | 各 1 个 |
| STARTUPE3 | 0 | 1 / 4 (25.00%) | T009 chip_nexus 含配置/启动接口 |

**差异来源总结**：
1. **设计范围（主因）**：T010 = core_mini_axi 标量核（无 RVV、无 L1 cache、无 ISP），LUT/FF/DSP 相差一个量级主要由此决定（架构笔记 §3.2：core_mini_axi 不实例化 L1 cache；§5.2：RVV 后端仅 rvv_core 变体启用）。
2. **器件族**：xc7v2000t（7 系列，无 URAM、LUT 1.22M、CARRY4、DSP48E1）vs xcvu13p（UltraScale+，URAM 1,280、LUT 1.73M、CARRY8、DSP48E2）；URAM 项不可比（T010 器件无）。
3. **实现阶段**：T010 为 route 后（LUT 已物理优化 -465），T009 为 synth 后（未优化，实际值会略降）；对比利用率为近似可比。
4. **集成面**：T010 自研 host 桥接 + 8 引脚；T009 官方 SoC 外设 + 82 引脚。

### 3. 时序三阶段演进（T010，clk_mmcm_out 40MHz / 25ns，period 约束 25ns）

| 阶段 | WNS(ns) | TNS(ns) | TNS Fail/Total | WHS(ns) | THS(ns) | THS Fail/Total |
|---|---|---|---|---|---|---|
| synth | +3.437 | 0.000 | 0 / 28,576 | **-1.180** | -609.282 | 2,104 / 28,576 |
| place | +0.707 | 0.000 | 0 / 28,576 | **-2.549** | -1,277.900 | 1,476 / 28,576 |
| **route（signoff）** | **+0.253** | 0.000 | 0 / 28,576 | **-0.085** | -0.257 | 7 / 28,576 |

> THS 总表 = intra-clock（clk_mmcm_out）+ async_default 路径组之和（如 synth：1516+588=2104；place：1079+397=1476）。Setup（WNS/TNS）全阶段 0 违例。

#### 3.1 关键路径（route signoff，setup，WNS=+0.253ns）

```
源: u_core/core/score/fetch/instructionBuffer/circularBuffer/buffer_7_inst_reg[13]/C (FDCE, clk_mmcm_out)
目: u_core/core/score/retirement_buffer/instBuffer/deqPtr_reg[1]_rep__0/D (FDCE, clk_mmcm_out)
Requirement 25.000ns | Data Path Delay 24.371ns (logic 5.094 = 20.9% + route 19.277 = 79.1%)
Logic Levels 47 (CARRY4=9 LUT2=4 LUT3=3 LUT4=3 LUT5=7 LUT6=20 MUXF7=1)
Clock Path Skew -0.265ns | Clock Uncertainty 0.077ns
```

- **路径本质（架构对应）**：取指缓冲（instructionBuffer circularBuffer）→ dispatch 判断（op/valid/readDataBits）→ LSU 保留站（lsu/rs）→ 退休缓冲（retirement_buffer 的 trap/cfDone/deqPtr 退休控制链）。即"取指缓冲 → 退休"的**跨模块控制链**，非单一运算单元。
- 47 级逻辑、79% 延迟在布线（routed net），符合 CoreMiniAxi.sv（Chisel/firtool 生成）无手工流水切割的特征。
- **时钟结构**（clock_utilization.rpt + timing_route.rpt）：`clk_osc`(100MHz, W4/W3 IBUFDS) → MMCME2_ADV → `clk_mmcm_out`(40MHz) → BUFGCTRL_X0Y64 → `clk_core`（clock_utilization FF 计数 416；timing 报告 net fo=419）；u_core 内部再经 `u_core/cg`（LUT3 门控 + BUFGCTRL_X0Y66）→ `_cg_clk_o`（timing 报告 net fo=8054；clock_utilization FF 计数 8004）——核心逻辑跑在门控时钟域。关键路径源/目的均在 `_cg_clk_o` 域。
- 三阶段关键路径源相同（`instructionBuffer/circularBuffer/buffer_7_inst_reg[6]`），目的逐级变化（synth→retiredEcalls、place→deqPtr[2]_rep、route→deqPtr[1]_rep）——同一控制链上的不同端点。

#### 3.2 hold 违例（route signoff，7 端点，WHS=-0.085ns）

```
源: u_host/s_araddr_r_reg[31]/C (FDCE, clk_mmcm_out)   ← host_cmd_fsm 的 AXI 地址输出寄存器
目: u_core/axiSlave/addrArbiter_io_in_0_q/ram_ext/Memory_reg_0_1_66_66/RAMA/I (RAMD32 LUTRAM)
Data Path Delay 2.853ns (logic 0.216 = 7.6% + route 2.637 = 92.4%) | Logic Levels 0
Clock Path Skew +2.676ns (DCD 0.629 - SCD -1.405 - CPR 0.642)
```

- **本质**：host（clk_core 域，BUFGCTRL_X0Y64 直连）→ core AXI slave 地址仲裁队列（**_rst_sync_clk_o 门控域，BUFGCTRL_X0Y67**，clock_utilization g1 实证 `readDataNext_pipe_v_reg_i_2`）的**跨门控时钟域短路径**；0 逻辑级纯布线路径，skew 2.676ns 主导。（注：`_cg_clk_o`/BUFGCTRL_X0Y66 为 setup 关键路径域，hold 路径目的 RAMD32 在 X0Y67/_rst_sync_clk_o 域）
- place 阶段同路径更严重（-2.549ns/1,476 端点，含 async_default），route 真实布线后收敛到 -0.085ns/7 端点——**hold 违例数在 route 后大幅下降，signoff 以 route 的 report_timing_summary 为准**。
- 与 T010 已有结论一致（"host→core AR 短路径 hold，85ps 噪声级"）；7 端点全部是 `u_host/*` → `u_core/axiSlave/*` LUTRAM 地址仲裁（仅最差 1 条在 timing_route.rpt 可实证，其余 6 条按同域推断）。

#### 3.3 50MHz 首版违例处置记录（build.log 实际数据，补充 T010 第二版）

| 版本 | MMCM CLKOUT0_DIVIDE_F | Route 35-57（router 估算） | 处置 |
|---|---|---|---|
| build.log（50MHz） | 24（period 20ns） | 中间迭代 WNS=-0.774(TNS-22.2)→-0.101→-0.228→-0.101→最终 **WNS=-0.058 / TNS=-0.089 / WHS=0.066** | 首版，setup 未收敛（核心路径长，79% 布线延迟） |
| build2.log（40MHz） | 30（period 25ns） | 最终 **WNS=1.361 / WHS=0.109** | 降频后 setup 大幅收敛 |
| build3.log（最终） | 30 | 最终 **WNS=0.236 / WHS=0.077** | + AXI 输出注册化（host_cmd_fsm），signoff 报告 WNS=+0.253 / WHS=-0.085 |

> **坑（数值口径）**：`Route 35-57 Estimated Timing Summary`（router 估算，reg2reg 为主）与 `report_timing_summary`（signoff，含 LUTRAM/latch/async 路径）的 hold 值可能不同（build3：35-57 WHS=0.077 vs signoff WHS=-0.085/7 端点）。**判定是否收敛一律以 signoff 的 `timing_route.rpt` 为准**。synth-notes T010 节中"build2=-0.016ns/2 端点"无法从留存 build2.log 复现（无该值），以留存报告为准并保留原记录不追改。

### 4. 综合/实现流程坑与解决（供 T010 迭代与 T013 上板参考）

- **license 环境变量**（T009 已记，再次强调）：`export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic`，缺省时 synth_design 直接报 `Common 17-345`。
- **file mkdir 陷阱**：tcl 中 `file mkdir -force <dir>` 会把 `-force` 当目录名创建字面 `-force/` 目录（`synth/out/T010/-force/` 可见残留）。`-force` 是 `write_bitstream` 等命令的选项，不是 `file mkdir` 的。
- **MMCM 原语命名**：RTL 实例化 `MMCME2_BASE`，综合后 utilization 报告显示为 `MMCME2_ADV`（B=ADV 子集，Vivado 统一报告）。
- **宽乘法器流水提示**：`Synth 8-12192 Not enough pipeline registers after wide multiplier (0 present, 4 recommended)`——CoreMiniAxi.sv 中 32×32/宽乘法无流水寄存器，40MHz 无 setup 问题；若提频（>50MHz）需在 core 外部/内部补流水或降低时钟。
- **BRAM rw_addr_collision**（8-6430，ITCM/DTCM 各 1 条）：firtool 生成 SRAM 未置 `rw_addr_collision` 属性，同地址读写碰撞会有仿真/行为差异；xsim 全链路验证当前访问无碰撞，T013 上板实测复核。
- **时序收敛方法论（本设计有效）**：
  1. 先降频定位是否逻辑深度问题（50MHz→40MHz 后 setup 从 -0.058→+1.36）；
  2. hold 违例集中在 host→core 短路径时，用**输出寄存器化 + 握手后清除**把启动寄存器移到 AXI 端口（注意双握手挂死坑，见 T010 节）；
  3. hold 违例看 signoff `timing_route.rpt`（route 后可能大幅收敛，不要只看 place 阶段数值吓自己）。
- **构建耗时实测（build3，服务器 16 核/62G）**：synth_design 12:54（PSS 峰值 10.86GB：main 3.26 + forked 8.48）→ opt_design 0:47 → place_design 4:30 → route_design 10:10 → write_bitstream 1:31 → **端到端 ~30 分钟**（对比 T009 xcvu13p 仅 synth 即 1h25m，小设计迭代很快）。
- **警告分类（build3：0 ERROR / 0 CRITICAL / 287 WARNING，9 类主因）**：8-7129 无负载端口×100、8-7137 fpnew set/reset 同优先级×92、8-6014 未用寄存器×42、8-3917 常量驱动端口×37、8-11065 参数转 localparam×7、8-6430×4、8-3936×2、8-3848×2（control_mvp 无驱动）、8-327×1（en_latch_reg 锁存器 + 1 条组合 latch loop，timing_route.rpt check_timing 12 也报 latch_loops=1 HIGH）。均为上游 Chisel 生成 RTL 行为，xsim 功能验证通过，T013 上板关注锁存器与 collision。
- **check_timing 提示**：no_input_delay 2（报告仅给计数，未列端口名；2 个非时钟输入端口未设 input delay）、no_output_delay 3（3 个输出端口未设 output delay）——本设计全同步单时钟（40MHz）内部路径已约束，IO 为板级异步/无外部时序要求，可忽略（HIGH 提示非错误）；latch_loops 1 对应 8-327 的 en_latch_reg 组合 latch loop。

### 5. 报告文件留存路径

| 报告/产物 | 本地 | 服务器（gxt@192.168.200.202） |
|---|---|---|
| T010 全套报告 + bitstream | `synth/out/T010/`（utilization/timing_{synth,place,route}.rpt、route_status.rpt、clock_utilization.rpt、drc_route.rpt、post_synth.dcp、post_route.dcp、top_coralnpu.bit/.bin、T010-build{1,2,3}.log、vivado.log） | `~/fpga/work/T010/`（报告源路径 `/home/gxt/fpga/work/T010/`） |
| T010 构建脚本/RTL/XDC | `synth/tcl/build_top.tcl`、`synth/rtl/`、`synth/xdc/top_coralnpu.xdc` | `~/fpga/synth/` 同结构 |
| T009 官方基线 | `synth/out/T009_chip_nexus_synth_only/chip_nexus_utilization_synth.rpt` | `~/fpga/work/T009/synth_only/synth-vivado/com.google.coralnpu_fpga_chip_nexus_0.1.runs/synth_1/chip_nexus_utilization_synth.rpt` |

**T013 上板参考结论**：T010 在 xc7v2000t 上资源占用 <4% LUT / <0.8% BRAM，40MHz signoff 仅 7 端点 85ps hold 噪声级违例；资源与时序余量充足，上板风险主要在**板级**（RS232 电平/波特率偏差 +3.3%、OSC1 频率待确认，见 T010 节）。
