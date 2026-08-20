# 板级调试日志（T015/T016，2026-08-20）

> 本文件记录 T015（UART host 通路）与 T016（Debug 抽象命令读写 TCM）的测试、调试过程与发现，
> 供后续重新上板尝试时参考。环境：S2C Dual Virtex-7 TAI LM（F1），bit = `T010-fix-clk`（时钟 L4/L3 + UART AV42/AU42 修正版）。

## 环境与工具

- **板卡**：S2C Dual Virtex-7 TAI LM（F1），JTAG J24（Digilent cable `SULEE2211346A`），子板 UART（AV42/AU42 → CH341）
- **串口**：`/dev/ttyUSB0`（CH341，VID 1a86:5523），115200 8N1；需 `dialout` 组（已加入）或 `sg dialout`
- **烧录**：`synth/tcl/program_top.tcl`（probe/program 两模式，机器201 执行）
- **复位**：SW1（AP31，低有效）——**每次测试前需人工复位；复位不清 SRAM**（ITCM/DTCM 内容保留）
- **命令协议**（T010 host_cmd_fsm）：`W<8hex addr><8hex data>` 写 / `R<8hex addr><2hex count>` 读 / `S` 引导 / `Q` 状态(CSR_STATUS 0x30008) / `?` 帮助，LF 结尾
- **脚本**：`sim/load_elf_uart.py`（ELF 加载，可用）、`sim/debug_write_tcm.py`（Debug 写 ITCM 上板，阶段 B 用）、`sim/diag_itcm_write.py`（ITCM 写诊断，排查用）、`synth/sim/tb_debug_test.sv`（T016 阶段 A 仿真 tb，ALL PASS）

### 调试脚本状态（2026-08-20）
| 脚本 | 状态 | 说明 |
|---|---|---|
| `sim/load_elf_uart.py` | 待修复 | 依赖 host W 写 ITCM（上板连续命令卡，需先修 host_cmd_fsm） |
| `sim/debug_write_tcm.py` | 待验证 | 上板 Debug 写未生效（阶段 B 阻塞） |
| `sim/diag_itcm_write.py` | 诊断用 | 上板 host 连续命令卡根因排查 |
| `synth/sim/tb_debug_test.sv` | ✅ 阶段 A 通过 | Debug 写 TCM 仿真验证 |

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
- **测试脚本**：`sim/uart_slow_test.py`（100ms 间隔 DTCM/ITCM 连续写）、`sim/diag_itcm_write.py`
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
