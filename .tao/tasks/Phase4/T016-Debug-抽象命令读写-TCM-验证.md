# T016: Debug 抽象命令读写 TCM 验证

## 执行环境
**执行环境**：机器202（阶段 A xsim 仿真）＋ 机器201（阶段 B 上板 UART）

## 接口规范
- 输入：T010 bitstream（已含 Debug 模块，经 CSR 0x30800 区域访问）；T015 验证的 UART host 通路；coralnpu Debug 模块寄存器映射（`scalar/Debug.scala`，见 coralnpu-architecture.md §Debug）
- 输出：验证经 Debug 模块（AXI CSR 0x30800-0x30814）抽象命令读写 ITCM/DTCM；命令序列与结果记录（`.tao/knowledge/synth-notes.md` 或 `board-notes.md`）
- 约束：**分两阶段**——阶段 A（机器202 xsim 仿真，全自动）在阶段 B（机器201 上板 UART）之前；抽象命令需核 halted（cmderr=4 当未 halt）；Access Memory 仅支持 ITCM/DTCM（cmderr=5 其他地址）

## 验收标准
1. **阶段 A（机器202 xsim，自动）**：新建独立 tb（不改原 `tb_top.sv`）模拟 UART 发 Debug CSR 序列：写 Dmcontrol(0x30810)=0x80000001（haltreq+dmactive）→ 轮询 Dmstatus(0x30811) allhalted → 写 Data1(0x30805)=地址 → 写 Data0(0x30804)=数据 → 写 Command(0x30817)（cmdtype=2 + aamsize=2 + write/transfer）→ 轮询 Abstractcs(0x30816) busy=0 且 cmderr=0 → 读回 Data0 验证一致
2. **阶段 B（机器201 上板）**：UART 发同一序列，写 DTCM(0x10000)/ITCM(0x0) 后读回一致，cmderr=0
3. 记录：抽象命令编码、寄存器映射（相对基址 0x30800 的偏移）、halt 前提、与 T013 程序加载的关系（备选通道）
4. 若阶段 A 失败（busy 不释放/时钟门控影响），先排查仿真问题，不直接上板

## 完成区
**状态**：进行中（阶段 A 完成、阶段 B 阻塞——详见 board-debug-log.md；UART 已稳定，可重测阶段 B）
**当前进展**：
- ✅ **阶段 A（机器202 xsim）ALL CHECKS PASSED**：Debug 抽象命令写 ITCM[0x0]/ITCM[0x4]/DTCM[0x10000] 成功（R 命令读回一致）
- ✅ **Debug 访问协议发现**：CoreAxiCSR Dbg 寄存器（0x30800/04/08 触发、0x30814 清响应队列）+ Debug 内部偏移（Data0/Data1/Dmcontrol/Command）
- ❌ **阶段 B（上板）**：Debug 写 ITCM 未生效（Dmstatus/Abstractcs 读回失败/0），与仿真差异，需波形级排查
- **上下文（2026-08-21）**：T015 根因定案为 uart_rx 亚稳态（已修复，W 命令 20/20）；T015 的 host W 直连写 TCM（AXI）已全部正常——阶段 B 的"Debug 写未生效"很可能同为 UART 层偶发（Debug 命令为长命令序列），**建议用 T010-clean bit + UART 修复后重测阶段 B**
- 调试过程/脚本/工具见 `.tao/knowledge/board-debug-log.md`
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：
- 阶段 B 待重测（UART 修复后）；若仍失败需波形级排查 Debug 通路

## 审阅记录

#### 第 1 轮 engineer 自审
（工程师自审 subagent 的意见、问题、判决及 finding 处置）

#### 第 1 轮 reviewer 验收
（审查者独立验证的重跑记录、约束核验、判决；Needs Revision 返工后，下一轮标 `第 2 轮`）
