# 板级调试日志（T015/T016，2026-08-20）

> 本文件记录 T015（UART host 通路）与 T016（Debug 抽象命令读写 TCM）的测试、调试过程与发现，
> 供后续重新上板尝试时参考。环境：S2C Dual Virtex-7 TAI LM（F1），bit = `T010-fix-clk`（时钟 L4/L3 + UART AV42/AU42 修正版）。

## 环境与工具

- **板卡**：S2C Dual Virtex-7 TAI LM（F1），JTAG J24（Digilent cable `SULEE2211346A`），子板 UART（AV42/AU42 → CH341）
- **串口**：`/dev/ttyUSB0`（CH341，VID 1a86:5523），115200 8N1；需 `dialout` 组（已加入）或 `sg dialout`
- **烧录**：`scripts/program_top.tcl`（probe/program 两模式，机器201 执行）
- **复位**：SW1（AP31，低有效）——**每次测试前需人工复位；复位不清 SRAM**（ITCM/DTCM 内容保留）
- **命令协议**（T010 host_cmd_fsm）：`W<8hex addr><8hex data>` 写 / `R<8hex addr><2hex count>` 读 / `S` 引导 / `Q` 状态(CSR_STATUS 0x30008) / `?` 帮助，LF 结尾
- **脚本**：`sim/T015-load_elf_uart.py`（ELF 加载，可用）、`sim/T016-debug_write_tcm.py`（Debug 写 ITCM 上板，阶段 B 用）、`sim/T015-diag_itcm_write.py`（ITCM 写诊断，排查用）、`synth/sim/T016-tb_debug_test.sv`（T016 阶段 A 仿真 tb，ALL PASS）

### 调试脚本状态（2026-08-20）
| 脚本 | 状态 | 说明 |
|---|---|---|
| `sim/T015-load_elf_uart.py` | 待修复 | 依赖 host W 写 ITCM（上板连续命令卡，需先修 host_cmd_fsm） |
| `sim/T016-debug_write_tcm.py` | 待验证 | 上板 Debug 写未生效（阶段 B 阻塞） |
| `sim/T015-diag_itcm_write.py` | 诊断用 | 上板 host 连续命令卡根因排查 |
| `synth/sim/T016-tb_debug_test.sv` | ✅ 阶段 A 通过 | Debug 写 TCM 仿真验证 |

## T015：UART host 通路验证

### 已验证通过
- UART 通路：`?`→`HELP`，Q 读 CSR_STATUS，W/R 写读 **DTCM(0x10000)** 一致（A5A5A5A5 写后读回一致）
- W/R/S/Q 命令协议工作（单命令稳定）

### 关键问题与发现
1. **ITCM 写上板 SLVERR**：host 经 `s_axi` 写 ITCM(0x0) 返回 `ERR`（SLVERR），写 DTCM 正常；**与 T010 仿真矛盾**（仿真 tb 写 ITCM 返回 OK）
2. **连续命令卡住**：单命令稳定，**连续 W 命令后 host 无响应/ERR**（需 SW1 复位恢复）；复位后能写 3-4 字 ITCM 的窗口不稳定
3. **复位状态**：复位后 `CSR_CTRL(0x30000)=3`（`resetReg=RegInit(3)`：bit0=Reset active high、bit1=clock gate）——**核复位+时钟门控，不取指**，排除"核运行冲突"假设
4. **SRAM 不清**：SW1 复位不清 ITCM/DTCM（读回旧值）

### 尝试过的加载流程（均未稳定）
- 复位后直接 W 写 ITCM：窗口内 3-14 字后卡
- 写 `CSR_CTRL=0` 后写 ITCM：仍卡（且 CTRL=0 会释放核运行）
- 写 `CSR_CTRL=1`（时钟开、核复位保持）后写：仍卡（host 已不稳定）

### 结论
- UART/DTCM 通路正常；**ITCM 加载是 T015/T013 阻塞点**
- **根因方向**：`host_cmd_fsm` 连续 AXI 写事务上板时序（`XW_AW→XW_W→XW_B`，疑 B 响应握手）——需 RTL 分析 + 仿真重现，避免上板盲试

## T016：Debug 抽象命令读写 TCM

### 阶段 A（机器202 xsim 仿真）—— ALL CHECKS PASSED

**Debug 访问协议（关键发现）**：不是标准 Debug 直地址（0x30810/0x30817），而是 **CoreAxiCSR 的 Dbg 寄存器**：
| 地址 | 寄存器 | 用途 |
|---|---|---|
| 0x30800 | DbgReqAddr | 写 **Debug 内部寄存器偏移**（Data0=0x4 Data1=0x5 Dmcontrol=0x10 Abstractcs=0x16 Command=0x17） |
| 0x30804 | DbgReqData | 写数据 |
| 0x30808 | DbgReqOp | 写 op（**READ=1 / WRITE=2**）触发访问 |
| 0x30810 | DbgRspData | 读结果 |
| 0x30814 | DbgStatus | **写清响应队列（深度 1，必须消费）** |

**验证结果**：Debug 写 ITCM[0x0]/ITCM[0x4]/DTCM[0x10000] 全部成功（R 命令读回 deadbeef/CAFEBABE/12345678 一致）；抽象命令 cmderr=0（halt 生效）
**已知限制**：Debug Access Memory **读**返回 0（data0 依赖 `io.itcm.readData.valid` 时序）——**加载/验证用 R 命令读回代替**，不受影响

**xsim 编译/调试坑（机器202 流程）**：
- 设计文件无 `timescale`，需编译时加 `` `timescale 1ns/1ps `` 头（用 python 生成副本；注意 bash 反引号陷阱）
- xelab 需 `-L unisim -L unisims_ver`（BUFG 等 Xilinx 原语）；glbl.v 单独编译
- `buf` 是 SV 门原语关键字（不能用做变量名）
- `recv_hexline` 需消费 hex 行尾 `\n`，否则后续 `recv_expect_str("OK\n")` 错位
- 复位的 UART 初始发送残留会污染首命令响应（复位后清 `rx_byte_q`）
- 仿真脚本传输用 base64 规避 shell 引号陷阱

### 阶段 B（上板）—— Debug 写 ITCM 未生效

**结果**：UART 通路 OK；halt（Dmcontrol 写）后 Dmstatus/Abstractcs 读回失败/0；Debug 写 ITCM 后 R 读回仍 0（复位后 ITCM 清零）——**Debug 写未生效，与仿真差异**
**可能根因**：上板 Debug 请求 ready/时序（`req_valid_pulse` 需 `io.debug.req.ready`）；或 CoreAxiCSR Dbg 寄存器上板写路径未触发 Debug 模块；需波形级排查

## 后续重试指南

1. **上板前**：先 `?` 确认 UART 稳定（复位后等待 2s + 重试）；每次测试前 **SW1 复位**并等确认
2. **修 host_cmd_fsm 前**：先在**机器202 xsim 重现连续 W 命令卡住**（本地可控），定位 B 响应/状态机问题后再上板
3. **若修 host FSM 连续命令**：修后机器202 重综合（build_top.tcl）+ 重新烧录（program_top.tcl）
4. **Debug 通道**：阶段 A 协议已验证（Dbg 寄存器 + 清队列），上板不工作待波形级排查
5. **工具提醒**：串口用 `sg dialout`（当前 opencode 会话）；SRAM 复位不清，读回旧值属正常

### 调试现场：方案 A（host_tcm 直写 ITCM）已烧录待测（2026-08-20 现场快照）

- **当前状态**：新 bit `T010-hosttcm/top_coralnpu.bit`（含 **host_tcm 直写端口**，绕过 AXI）已烧录上板，DONE HIGH
- **待办**：**SW1 复位后**测试 W 写 ITCM 连续多字（直写应不再卡 AXI）+ R 读回验证
- **改动**：coralnpu fork `d74e0ac8`（CoreAxi 加 host_tcm 端口，ITCM arbiter 4 端口）；主仓库 `72a4fae`（host_cmd_fsm W 写 ITCM 走直写）+ `b4e6dcd`（信号声明顺序）
- **测试脚本**：`sim/T015-uart_slow_test.py`（100ms 间隔 DTCM/ITCM 连续写）、`sim/T015-diag_itcm_write.py`
- **相关环境**：bazel 需 `CC=clang-14`（Ubuntu 24.04 clang-18 modules 不兼容）
- **恢复步骤**：复位 → `sg dialout` 跑 uart_slow_test.py → 验证 ITCM 直写全过 → 记录结果

### 分析：ITCM vs DTCM 结构对比（2026-08-20，T015 根因分析）

**背景**：上板 host AXI 写 DTCM 正常、写 ITCM 3-4 字后卡；仿真不复现。排查存储层是否差异。

**RTL 查证结论**：
| 维度 | ITCM | DTCM |
| --- | --- | --- |
| 地址/大小 | 0x0000-0x1FFF（8KB） | 0x10000-0x17FFF（32KB） |
| 接口位宽 | 128b + 16b strb | 相同（TCM128） |
| 存储组成 | SramBlock(512)=2×RAMB36（无级联） | SramBlock(2048)=8×RAMB36（4×深度级联） |
| 存储黑盒 | Sram.v Generic 行为 SRAM，同步1拍读 | 完全同构 |
| 仲裁端口 | 4：core取指/AXI/Debug/host_tcm(新) | 3：core读写/AXI/Debug |
| core 访问 | 只读（取指，write 置 invalid） | 读+写 |
| 优先级 | source(0)=core取指（最高） | source(0)=core数据总线（最高） |

- **存储层完全同构**（同 Sram.v 黑盒，仅 NUM_ENTRIES 不同），BRAM 无本质区别，可排除存储差异
- **关键差异**：FabricArbiter（Fabric.scala:24）为**固定优先级**，fabricBusy(i)=高优先源有效即背压

**根因假设**：ITCM 的 source(0)=core 取指端口——core 一旦运行（PC 在 ITCM 内）持续占用 ITCM，AXI 写（source(1)）被永久背压饿死；DTCM 的 source(0) 仅 load/store 时占用，程序不访问数据时 AXI 写畅通。**与"DTCM 正常、ITCM 卡"吻合**。
**待实证**：上板 core 在 resetReg=3（复位+门控）下 ibus.valid 是否残留为高（组合逻辑可能拉高）。

**下一步验证（新 bit T010-hosttcm 已烧录待测）**：
1. 复位后测 host_tcm 直写（source(3) 最低优先）：**直写也卡**→证明仲裁器饿死假设；**直写通**→AXI slave→FabricMux 路径问题
2. 若饿死假设成立：修复方向 = host 写 ITCM 前暂停 core（halt/保持复位）或调整仲裁优先级

### 根因定案：T015 "host 写 ITCM 卡" = uart_rx 亚稳态（2026-08-21）

**结论**：此前所有"host 连续写卡/无响应/SLVERR"现象（AXI 写 ITCM、方案 A 直写 ITCM、DTCM ERR、CSR 读失败）**均为同一个根因：uart_rx 直接异步采样 rx_in（无同步器）导致的亚稳态**，与 TCM/AXI/仲裁/直写路径无关。仿真理想时序不复现。

**证据链**：
1. W 长命令（18 字节）失败率 30-45%，? 短命令（2 字节）100% → **错误率与命令长度相关**（亚稳态每字节 ~3.3%，命令越长越易中）
2. DIV 四舍五入（21→22，波特率偏差 3.34%→1.36%）**无改善**（W 仍 11/20）→ 排除波特率
3. 波特率探测（uart_baud_probe）：FPGA TX 115200 时 ? 6/6 → **clk_core=40MHz 精确**（排除时钟频率）
4. uart_rx 加 2 级同步器后：? 20/20、W 20/20、DTCM 16/16、ITCM 直写 16/16 + 读回一致 → **根治**

**修复**（T010-sync bit，10:59）：
- `uart_rx.sv`：rx_in 加 2 级同步器（rx_q1/rx_q2，空闲=1 防误触发起始位）
- `uart_rx.sv`/`uart_tx.sv`：DIV 四舍五入（RX 22，辅助改善）
- `build_top.tcl`：phys_opt_design -hold_fix（顺带修 u_host→u_core 写路径 35 端点 hold 违例，WHS -0.113→+0.019）

**方案 A 结论**：host_tcm 直写 ITCM（CoreAxi source(3)）已实现且工作正常（16/16），保留作为 ITCM 加载通路；原"AXI 写 ITCM 卡"实为 UART 亚稳态误判，非 AXI/仲裁问题。

### T007 上板运行成功（2026-08-21，T015 目标达成）

- bit：T010-sync（10:59，最新，md5 514c5a56...）
- 加载：load_elf_uart.py 232 字（ITCM 0x0 204 字 + DTCM 0x10000 28 字）全成功
- S 启动 OK → 核 HALTED（STATUS=1，CTRL=0）
- **回读验证 ALL PASS**：out_mul={700,1600,2700,4000}、fout={2.0,3.0,5.0,7.0}
- 注意：load_elf 的 Q 轮询判定有误报（Q 响应格式正确 `0003000800000001`，但轮询时机在核跑完前；可用 t007_result_check.py 直接回读确认）

### 目录规范化（2026-08-21）
统一 `synth/out/<任务>-<描述>/`（201）与 `~/fpga/work/<任务>-<描述>/`（202）命名。重命名映射：`synth_t008_check`→`T008-check`、`T009_chip_nexus_synth_only`→`T009-chip-nexus-synth`、`T010`(首版)→`T010-first`；清理 202 run202-* 测试目录与 201 顶层 vivado.* 残留。当前 bit 目录：`T010-sync`（最新，md5 514c5a56...）。

### AXI 写 ITCM 验证（2026-08-21，T010-axiitcm bit）
- 改动：host_cmd_fsm W 命令关闭直写分支（ITCM 也走 XW_AW/AXI），其余不变
- bit：T010-axiitcm（14:55，md5 96c8425a...，proj 工程模式首次成功，WNS+0.333/WHS+0.086/hold 0）
- 结果：**AXI 写 ITCM 8/8 + 读回一致；load_elf 232 字全成功；T007 运行 ALL PASS**
- **结论：host_tcm 直写端口非必需**（UART 同步器修复后 AXI 写 ITCM 正常）；方案 A 可移除回到上游干净状态
- 注意：load_elf 需 `python3 -u`（管道下 stdout 块缓冲导致"看不到进度"）

### 方案 A 清理完成（2026-08-21，T010-clean bit）
- 移除 host_tcm 直写端口：CoreAxi.scala（coralnpu fork 8225240f，ITCM/DTCM arbiter 3 端口）+ host_cmd_fsm（删 XW_HOST/直写信号）+ top（删 io_host_tcm）
- CoreMiniAxi.sv 重建（无 io_host_tcm），回到上游干净状态
- bit：T010-clean（md5 9b2d8d0e...，WNS+0.950/WHS+0.016/hold 0/0 ERROR，proj 工程模式）
- 验证：load_elf 232 字（纯 AXI 写 ITCM）全成功 + T007 运行 **ALL PASS**
- 结论：host_tcm 直写端口已彻底移除，仅用 AXI 写 ITCM，设计回到上游干净

### T016 阶段 B 重测通过（2026-08-21）
- bit：T010-clean（UART 同步器修复后）
- 结果：Debug 写 ITCM[0x0]=DEADBEEF、ITCM[0x4]=CAFEBABE → R 读回一致 → **ALL PASS**
- **假设确认**：阶段 B"Debug 写未生效" = uart_rx 亚稳态（Debug 命令为长命令序列，当时与 host 写 ITCM 卡同因）；UART 修复后 Debug 通路（CoreAxiCSR Dbg 寄存器 0x30800/04/08/14）完全正常
- Dmstatus/Abstractcs 读回 0 为已知限制（Debug Access Memory 读返回 0），加载/验证用 R 命令读回代替，不受影响

## T018 上板验证（2026-08-26，50MHz 新核 2290a286c）

### 结果
- bit：`synth/out/T018-e3-synth/top_coralnpu.bit`（50MHz，md5 9814dbad）
- t007_scalar_fp_test.elf 上板 **ALL PASS**（HALTED + out_mul/fout 结果 bit-exact）

### 坑与发现
1. **Q 命令上板不可靠**：核已 HALTED（R 命令读 STATUS=1），但 `load_elf_uart.py` 用 Q 轮询报"未进入 HALTED"（E2 仿真 Q 正常、上板异常——UART 帧拆分致响应解析失败）。**修复**：load_elf 轮询改用 R 命令读 0x30008。Q 命令根因未深挖。
2. **0x30004 是 pcStartReg（启动地址寄存器）非运行 PC**；STATUS=1 无法区分"初始 halted"vs"跑完 halted"——判定核执行需回读结果数组（DTCM 内容）。
3. 50MHz signoff WNS=-0.175ns（核内 dm→retirement_buffer，布线 81%），**上板实测稳定 → 接受**（决策 A）。
4. 早期"核未启动"误判：csr_rw_diag 证实 CSR 写读全部正常（PC_START/CTRL），最终 dtcm_diag（回读 DTCM=42）确认核执行正常——**诊断应优先回读数据而非只看 STATUS/PC**。
