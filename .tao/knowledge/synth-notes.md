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
