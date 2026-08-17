# T003: 跑通官方 Verilator C++ sim（hello world add floats）

## 执行环境
**执行环境**：本地

## 接口规范
- 输入：coralnpu 源码；bazel 8.6.0（T001 完成）
- 输出：hello_world 可执行 ELF + Verilator C++ 仿真器 `core_mini_axi_sim` 构建产物，并成功运行
- 约束：不改 coralnpu/ 内文件；RISC-V 工具链已在 T002 首次构建中完成（本任务可复用缓存，若先于 T002 执行则同样耗时）

## 验收标准
1. `bazel build //examples:coralnpu_v2_hello_world_add_floats` 成功，产物 ELF 存在于 `bazel-bin/examples/coralnpu_v2_hello_world_add_floats.elf`（bazel-bin 符号链接指向实际 `bazel-out/.../bin/`）
2. `bazel build //tests/verilator_sim:core_mini_axi_sim` 成功
3. 运行：
   ```
   bazel-bin/tests/verilator_sim/core_mini_axi_sim \
     --binary bazel-bin/examples/coralnpu_v2_hello_world_add_floats.elf
   ```
   退出码 0，日志/回读输出包含预期数值（如加法结果），且记录中附输出样例
4. 记录运行方式、命令与输出样例到 `.tao/knowledge/toolchain-notes.md`

## 完成区
**状态**：已验证（reviewer 第 1 轮 Accepted + Mimo 交叉复核确认）
**Commit**：无（零代码改动，仅新增/更新 `.tao/knowledge/toolchain-notes.md` 与任务文件）
**测试结果**：验收 4/4 通过。日志留存 `.tao/logs/T003-*.log`
**修改文件**：
- `.tao/knowledge/toolchain-notes.md`（追加"Verilator C++ sim"章节，验收标准 4 要求）
- `.tao/tasks/Phase0/T003-跑通官方-Verilator-C++-sim-hello-world.md`（完成区）
- 未改 coralnpu/ 内任何文件（约束满足）
**验收结果**：
1. `bazel build //examples:coralnpu_v2_hello_world_add_floats` → exit 0，ELF 生成于 `bazel-out/k8-fastbuild-ST-dd8dc713f32d/bin/examples/coralnpu_v2_hello_world_add_floats.elf`（RISC-V 32-bit）；紧跟构建后 `bazel-bin/examples/...` 存在
2. `bazel build //tests/verilator_sim:core_mini_axi_sim` 需加 `--linkopt=-latomic`（缺 `-latomic` 致 `__atomic_is_lock_free` undefined reference，见坑）→ exit 0，产物 `bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim`
3. 运行（exit 0）：
   ```
   ./bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim --binary ./bazel-out/k8-fastbuild-ST-dd8dc713f32d/bin/examples/coralnpu_v2_hello_world_add_floats.elf
   ```
   默认输出样例：
   ```
   SystemC 2.3.4-Accellera --- redacted redacted
   Copyright (c) 1996-2022 by all Contributors,
   ALL RIGHTS RESERVED

   Info: /OSCI/SystemC: Simulation stopped by user.
   ```
   数值证据：ELF `.data` 段全零（input1/input2/output @0x10000/0x10020/0x10040 初值 0.0f），`--instr_trace` 显示 main（0x144）循环 8 轮 flw/fadd.s/fsw（PC 0x158–0x174）全部 `trap=no`，`--debug_axi` 显示 ELF 加载回读（ITCM 720B、DTCM 112B）与 CSR 回读一致、状态寄存器 0x30008 回读 = 1（CheckStatusSync 期望 `DATA(1,0,0,0)`）→ 预期 0.0f+0.0f=0.0f，程序正常完成无 fault
4. 运行方式/命令/输出样例已记录到 `.tao/knowledge/toolchain-notes.md`（新增"Verilator C++ sim（core_mini_axi_sim，2026-08-17，T003）"章节）
**新发现/坑**：
- `//tests/verilator_sim:core_mini_axi_sim` 链接需 `-latomic`（verilated.cpp/verilated_threads.cpp 的 `std::atomic::is_lock_free()` → `__atomic_is_lock_free` undefined reference）；用 `--linkopt=-latomic` 修复（不改源码）
- `bazel-bin` 符号链接随最近 build 目标配置切换（transition 目标 → `k8-fastbuild-ST-<hash>/bin`，host 目标 → `k8-fastbuild/bin`），混合用 `bazel-bin` 路径会因产物不在当前链接目录而失败（`open() fd>0` CHECK abort）；两个产物都用 `bazel-out/<配置>/bin/...` 完整路径最稳，ELF 在 ST 配置目录
- hello_world_add_floats 无打印/无 tohost（非 semihosting），"数值"只能通过 .data 段（全零输入）+ instr_trace（fadd.s 执行）+ status 回读（=1）间接证明；本 sim 无输出数值的通道
**遗留问题**：
- 无（验收 4/4 通过）

## 审阅记录

#### 第 1 轮 engineer 自审
**自主自审（嵌套受限）**：任务明确限制不嵌套调起子代理，按 engineer 规则降级为自主自审。

| finding | 处置 | 改了什么 | 复验证据 |
|---------|------|---------|---------|
| F1: sim 构建首次失败，需诊断而非盲目重试 | ✅已修 | 读全量错误定位到 `__atomic_is_lock_free` undefined reference，确认链接命令无 `-latomic`、系统存在 libatomic，用 `--linkopt=-latomic` 有依据重试 | T003-build-sim.log（失败）+ T003-build-sim-linkatomic.log（exit 0） |
| F2: 直接按验收标准 3 的命令形式运行失败（fd>0 CHECK abort） | ✅已修 | 诊断发现 `bazel-bin/examples/...elf` 不存在，根因是 bazel-bin 链接指向随配置切换；改用 `bazel-out/<配置>/bin/...` 完整路径（与官方 README 第 59 行一致） | T003-run-sim.log（失败）+ T003-run-sim2.log（exit 0） |
| F3: 输出缺"加法结果"数值，验收标准 3 要求"含预期数值" | ✅已修 | 分析 ELF `.data` 段（全零=0.0f 输入）、反汇编 main（flw/fadd.s/fsw 循环 8 次）、`--instr_trace`（8 轮 FADD，trap=no）、`--debug_axi`（ELF 加载回读 + 状态 0x30008=1），构成"预期数值 0.0f+0.0f=0.0f 且程序正常完成"证据链 | T003-run-sim-trace.log、T003-run-sim-debugaxi.log |
| F4: 复杂命令输出需留存 .tao/logs/ | ✅已修 | 全部 T003-*.log 复制到 `.tao/logs/` | ls .tao/logs/ |
| F5: 验收标准 4 要求记录运行方式到知识库 | ✅已修 | toolchain-notes.md 追加"Verilator C++ sim"章节（命令、输出样例、坑） | read toolchain-notes.md |

**判决**：Accepted（实现侧自审），无未修 finding。
- 遗留说明（供 reviewer/主会话参考）：`--linkopt=-latomic` 为构建命令行选项，未持久化到 coralnpu/ 内任何文件（遵守约束）；如需固化到 wrapper 脚本或 .bazelrc 由主会话决策。

#### 第 1 轮 reviewer 验收

**判决：Accepted**（4/4 验收标准独立重跑通过，约束无违反；含 1 个非阻断提示见末尾）

**重跑记录**（全部由 reviewer 独立执行，输出留存 `.tao/logs/T003-review-*.log`；不采信完成区转述）：

| # | 命令 | 我的退出码 | 结果 |
|---|------|-----------|------|
| 1 | `bazel build //examples:coralnpu_v2_hello_world_add_floats` | 0 | 缓存命中，产物 up-to-date；`file` 确认 `bazel-bin/examples/...elf` = **ELF 32-bit LSB, UCB RISC-V, statically linked**；readelf 确认 RISC-V EXEC |
| 2a | `bazel build //tests/verilator_sim:core_mini_axi_sim`（**不加** linkopt） | 1 | 复现失败：`libverilator_lib.a(verilated.pic.o): undefined reference to '__atomic_is_lock_free'`（verilated.cpp / verilated_threads.cpp）——**工程师"需 -latomic"说法独立验证成立** |
| 2b | `bazel build //tests/verilator_sim:core_mini_axi_sim --linkopt=-latomic` | 0 | 成功，产物 `bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim`（11MB） |
| 3a | `./bazel-out/k8-fastbuild/bin/tests/verilator_sim/core_mini_axi_sim --binary ./bazel-out/k8-fastbuild-ST-dd8dc713f32d/bin/examples/coralnpu_v2_hello_world_add_floats.elf` | 0 | 输出仅 SystemC 2.3.4 信息 + `Simulation stopped by user.`，与完成区样例一致 |
| 3b | 同上 + `--instr_trace` | 0 | main(0x144) 循环 8 轮，PC 0x158–0x174 全 trap=no；**与工程师留存 T003-run-sim-trace.log 关键行 diff 为空**（防造假核验通过） |
| 3c | 同上 + `--debug_axi` | 0 | ITCM Write/Read/Expected @0x0 len=720 一致；DTCM @0x10000 len=112 一致；0x30008 Read=Expected=`{0x1,0,0,0}` |
| 4 | 反汇编（riscv64-unknown-elf-objdump） | 0 | main：`0x158 flw fa5,0(a5)` / `0x15c flw fa4,0(a3)` / `0x160 fadd.s` / `0x164 fsw` / `0x174 bne` 回 0x158——与工程师描述逐字节一致 |
| 5 | objdump `.data` 段 + nm | 0 | `.data` @0x10000 共 0x70B **全零**；`input1`@0x10000、`input2`@0x10020、`output`@0x10040 → 初值 0.0f |
| 6 | 源码核验 `core_mini_axi_tb.{h,cc}` / `core_mini_axi_sim.cc` | — | `csr_addr_=0x30000`；`CheckStatusAsync()` 期望 `Read(csr_addr_+0x8=0x30008)` = `DATA(1,0,0,0)`，与 debug_axi 输出吻合；sim 返回非零条件 `io_fault || (tohost_halt && tohost_val!=1)`，exit=0 证明未触发 |

**证据链核验结论**：默认模式无数值打印属实（本 sim 无打印/tohost 通道）。0.0f+0.0f=0.0f 的推断证据链**完整独立复现**：ELF `.data` 全零（输入=0.0f）→ 反汇编确认 fadd.s 执行 → instr_trace 8 轮 FADD 全 trap=no → 状态寄存器 0x30008 回读=1 且与源码 CheckStatusSync 期望一致 → exit 0。该证据链成立。

**约束核验**：
1. coralnpu/ 零改动：**通过**。`git status --porcelain` 干净；submodule HEAD d93b5550 未漂移；README.md 未改；任务期间曾出现 `.README.md.swp`（vim 交换残留，14:12）但现已不存在，不影响结论
2. 日志留存 `.tao/logs/T003-*.log`：**通过**（含本次重跑 T003-review-*.log）
3. 未改契约/spec/测试：**通过**（本次改动仅 toolchain-notes.md 追加章节 + 任务文件完成区，`git diff --stat` 2 文件 67+/4-）
4. 无 commit（零代码改动承诺）：**通过**

**非阻断提示**（供主会话/架构师参考）：
- `--linkopt=-latomic` 仅为命令行选项，未固化到任何文件（符合约束）；后续若常跑 `//tests/verilator_sim` 建议由主会话决策持久化方式（.bazelrc 或 wrapper 脚本）
- 官方 README 的 `bazel-bin/...` 混合路径写法因 bazel-bin 链接随最近 build 配置切换而不可靠，工程师用 `bazel-out/<配置>/bin/` 完整路径规避——已在我的重跑中复现该现象（build sim 后 `bazel-bin/examples/...elf` 不存在），属环境特性而非实现缺陷

#### 第 1 轮 architect 交叉复核（Mimo）

**复核结论**：**确认 Accepted**，无阻断性发现。

- 验收标准 4 条全覆盖无遗漏（第 4 条文档类读文件确认即可，reviewer 隐含覆盖）
- 证据链可信度（核心）：独立读 `hello_world_add_floats.cc`（26 行）确认**无 printf/tohost/semihosting，纯 8 次浮点加法**；`.data` 无初始化器→ELF 全零→0.0f；`core_mini_axi_tb.cc:437-442` CheckStatusAsync 期望 0x30008=DATA(1,0,0,0) 与 debug_axi 回读一致；engineer/reviewer 两份 trace/debugaxi 日志 diff 一致（仅时间戳差异），防伪造性强
- reviewer 判决合理性：Accepted 成立，无过严/过松（reviewer 主动复现无 -latomic 失败对照实验，验证充分）
- 约束遵守：coralnpu 零改动、HEAD d93b5550 未漂移、-latomic 未持久化记录准确
- 建议：通过收尾，T003 标记已验证
