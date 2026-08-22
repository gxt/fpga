# T002: 跑通官方 Cocotb 快速开始（core_mini_axi_sim_cocotb）

## 执行环境
**执行环境**：机器201

## 接口规范
- 输入：coralnpu 源码（HEAD d93b5550）；bazel 8.6.0（T001 完成）
- 输出：官方 Cocotb 快速开始 target 构建并运行通过；首次构建拉取的依赖缓存于 bazel 外部仓库缓存；关键依赖下载清单记录到 `.tao/knowledge/toolchain-notes.md`
- meta target 语义：`bazel run //tests/cocotb:core_mini_axi_sim_cocotb` 是 cocotb_test_suite 生成的 **meta target**，实际运行 `tests/cocotb/BUILD` 中 `CORE_MINI_AXI_SIM_TESTCASES` 声明的全部 **20 个 case**（其中 `core_mini_axi_basic_write_read_memory`、`core_mini_axi_write_read_memory_stress_test`、`core_mini_axi_rand_instr_test`、`core_mini_axi_burst_types_test` 标记为 `large`，suite 整体 `size=enormous`）。全量冒烟属长耗时项，本任务做法二选一并记录选择：
  - 方案 A（全量冒烟）：timeout ≥ 6h，分段执行（首次 bazel 构建含 RISC-V 工具链，4 核 11G 内存环境预计数小时）；
  - 方案 B（固定单个快速用例）：选 1 个默认 `medium` size 的快速 case（如 `core_mini_axi_riscv_tests` 或 `core_mini_axi_csr_test`）作为冒烟，剩余 case 由 T006 子集选择覆盖。
- 约束：不改 coralnpu/ 内文件（如需修复按 ADR-003 流程）；执行前检查磁盘空间（bazel 外部仓库缓存 + 工具链构建，预留 ≥ 30G 可用），不足则先清理再执行

## 验收标准
1. 按所选方案执行：方案 A 跑完整 meta target（20 case），方案 B 跑单个快速 case——退出码 0，运行日志出现 Cocotb 通过标志（如 `Passed` / 0 failures / `All tests passed`）
2. 记录执行方案选择（A/B）与对应运行日志片段；若选方案 B，明确说明剩余 case 的覆盖计划（由 T006 子集执行）
3. 记录关键依赖下载清单（chisel、opentitan、riscv 工具链、hermetic verilator 版本等）与磁盘占用到 `.tao/knowledge/toolchain-notes.md`
4. 无对 coralnpu/ 的机器201修改（`git -C coralnpu status` 干净）

## 完成区

**状态**：已验证（reviewer 第 2 轮 Accepted + Mimo 交叉复核确认）
**Commit**：无（零代码改动，仅补写 .tao 下任务文件与知识库文档）
**测试结果**：通过 1/1；`//tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_csr_test` PASSED in 45.8s（强制真实重跑），cocotb 汇总 `TESTS=1 PASS=1 FAIL=0 SKIP=0`；另缓存命中重跑 `(cached) PASSED in 33.5s`
**修改文件**：
- `.tao/tasks/Phase0/T002-跑通官方-Cocotb-快速开始.md`（补写完成区 + 审阅记录 + 状态）
- `.tao/knowledge/toolchain-notes.md`（新增「Cocotb 快速开始」节：依赖清单、磁盘占用、坑/经验）
- `.tao/logs/T002-test-csr-full.log`（新增，真实 cocotb 全量输出日志）
- coralnpu/ 零改动
**验收结果**：
1. 方案 B（固定单个 medium case `core_mini_axi_csr_test` 冒烟）：退出码 0，日志含 Cocotb 通过标志
   - `T002-test-csr-full.log:16` `Running on Verilator version 5.050`
   - `:18` `Initialized cocotb v2.0.0`
   - `:347` `core_mini_axi_sim.core_mini_axi_csr_test passed`
   - `:353` `** TESTS=1 PASS=1 FAIL=0 SKIP=0`
   - `:363` `PASSED in 45.8s`；`:365` `Executed 1 out of 1 test: 1 test passes.`；bash 捕获 EXIT_CODE=0
2. 方案选择记录（B）+ 日志片段：见「方案选择」节与上；剩余 19 case（含 4 个 large）由 T006 子集执行覆盖
3. 关键依赖下载清单与磁盘占用已写入 `.tao/knowledge/toolchain-notes.md`：verilator hermetic 5.050/5.051-devel（commit b97df914）、cocotb 2.0.0、chisel 7.0.0-RC1、llvm-firtool 1.114.0、RISC-V 工具链 toolchain_coralnpu_v2-2026-06-29（riscv64-unknown-elf-gcc 16.1.0）、riscv-tests/opentitan/RVVI/mpact-riscv/riscv-isa-sim/uvm-verilator/srecord/rules_hdl；bazel 缓存 8.9G + bazelisk 107M
4. `git -C /home/gxt/fpga/coralnpu status`：干净，无机器201修改（HEAD d93b5550 与接口规范一致）
**新发现/坑**：
- `bazel test` 默认命中 action cache，只显示 `(cached) PASSED`，看不到 cocotb 详细输出；留证需 `--nocache_test_results --test_output=all`（真实重跑约 46s）
- cocotb 输出含 `Cannot read termcap database`、`COCOTB_TESTCASE is deprecated` 等噪音，不影响通过
- 首次构建 2709 actions 中约 1/3 为 hermetic verilator V3*.cpp 源码编译，是耗时大头；二次构建秒级
- verilator 运行版本（cocotb 报告 5.050）与源码 configure.ac（5.051 devel）不一致，同一次构建产物，属源码版本号与发布号差异，非错误
**遗留问题**：
- 剩余 19 个 case（含 `core_mini_axi_basic_write_read_memory`、`core_mini_axi_write_read_memory_stress_test`、`core_mini_axi_rand_instr_test`、`core_mini_axi_burst_types_test` 4 个 large）未在本任务执行，覆盖计划交由 T006 子集选择执行

## 方案选择

- 选择 **方案 B（固定单个快速 case）**：选 `core_mini_axi_csr_test`（medium size）作为冒烟
- 理由：全量 meta target 20 case（size=enormous）为长耗时项；4 核 11G 环境首次构建约 22 min 已含依赖与工具链全量下载，全量跑 20 case 时长不可控，方案 B 已满足"跑通官方 Cocotb 快速开始"验收目的；剩余 case 由 T006 子集选择覆盖
- 昨日已执行（会话中断未写回，本任务补核验写回）：`.tao/logs/T002-build-csr.log`（2709 actions，Build completed successfully，Elapsed 1307.924s）+ `.tao/logs/T002-test-csr.log`（PASSED in 33.5s）
- 今日独立重跑核验（防伪造）：
  - 缓存命中重跑：退出码 0，`(cached) PASSED in 33.5s`，`Executed 0 out of 1 test: 1 test passes.`
  - 强制真实重跑（`--nocache_test_results --test_output=all`）：退出码 0，`PASSED in 45.8s`，完整 cocotb 输出 `TESTS=1 PASS=1 FAIL=0 SKIP=0`

## 审阅记录

#### 第 1 轮 engineer 自审
**审阅方式**：尝试开启 general subagent 代码级 review，返回 "Subagent depth limit reached (1)"（嵌套深度受限），按规则降级为**自主自审（嵌套受限）**。

逐项核验（防伪造 + 事实准确性）：

| # | 核验项 | 证据 | 判决 |
| --- | --- | --- | --- |
| 1 | T002-build-csr.log 真实成功 | 行1037 `INFO: Build completed successfully, 2709 total actions`；行1035 `Elapsed time: 1307.924s`；日志主体为 verilator V3*.cpp 编译，无 ERROR/FAILED | ✅ 真实 |
| 2 | T002-test-csr.log 真实 PASSED | 行17 `PASSED in 33.5s`；行19 `Executed 1 out of 1 test: 1 test passes.` | ✅ 真实 |
| 3 | 强制重跑（本会话新产出） | `T002-test-csr-full.log` 行347 `passed`、行353 `TESTS=1 PASS=1 FAIL=0 SKIP=0`、行363 `PASSED in 45.8s`、行365 `Executed 1 out of 1 test: 1 test passes.`；bash EXIT_CODE=0 | ✅ 真实 |
| 4 | coralnpu/ 零改动 | `git -C /home/gxt/fpga/coralnpu status`：`无文件要提交，干净的工作区`；HEAD d93b5550 与接口规范一致 | ✅ 真实 |
| 5 | toolchain-notes.md 依赖版本准确性 | verilator commit `b97df914`（rules_hdl `dependency_support/verilator/verilator.bzl` urls）、cocotb 2.0.0（外部仓库 `cocotb-2.0.0.dist-info`）、chisel 7.0.0-RC1（WORKSPACE:147）、llvm-firtool 1.114.0（repos.bzl:183）、toolchain_coralnpu_v2-2026-06-29 + gcc 16.1.0（WORKSPACE:273 + 实测 --version）、riscv-tests/opentitan/RVVI/mpact-riscv/riscv-isa-sim/uvm-verilator/rules_hdl 均与 repos.bzl 声明一致 | ✅ 全部核实一致 |
| 6 | 磁盘占用 | `du -sh ~/.cache/bazel` = 8.9G（external 6.1G + execroot 1.2G）；`~/.cache/bazelisk` = 107M | ✅ 实测 |

**finding 处置**：

| finding | 处置 | 改了什么 | 复验证据 |
| --- | --- | --- | --- |
| 无阻塞性 finding | — | — | 全部核验项 PASS |

**判决**：✅ Accepted（证据充分、无伪造、无事实错误；零代码改动符合约束；剩余 case 覆盖已明确移交 T006）

#### 第 1 轮 reviewer 验收

**重跑记录**（审查者独立执行，日志留存 `.tao/logs/T002-review-*.log`）：

| # | 命令 | 真实输出（关键行） | 退出码 |
| --- | --- | --- | --- |
| 1 | `cd /home/gxt/fpga/coralnpu && bazel test //tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_csr_test`（缓存命中） | `(cached) PASSED in 45.8s`；`Executed 0 out of 1 test: 1 test passes.`；`INFO: Build completed successfully, 1 total action` | 0 ✅ |
| 2 | 同上 + `--nocache_test_results --test_output=all`（强制真实重跑，约 36s） | `Running on Verilator version 5.050`；`Initialized cocotb v2.0.0`；`core_mini_axi_sim.core_mini_axi_csr_test passed`；`** TESTS=1 PASS=1 FAIL=0 SKIP=0 **`；`PASSED in 36.1s`；`Executed 1 out of 1 test: 1 test passes.` | 0 ✅ |
| 3 | `git -C /home/gxt/fpga/coralnpu status` | `无文件要提交，干净的工作区`；HEAD `d93b5550` 与接口规范一致 | 0 ✅ |
| 4 | 磁盘占用实测 | `du -sh ~/.cache/bazel` = 8.9G；`~/.cache/bazelisk` = 107M（与 toolchain-notes 一致） | — ✅ |

**约束核验**（对照任务验收标准逐条）：

1. ✅ 方案 B 冒烟通过：exit 0、日志含 Cocotb 通过标志（我独立重跑确认，非采信完成区）
2. ✅ 方案选择（B）+ 日志片段已记录；剩余 19 case 覆盖计划明确指向 T006（`Phase2/T006-跑通-Cocotb-测试套件核心子集.md` 文件存在）；BUILD 确认 `core_mini_axi_csr_test` 为 default medium（无 size 标注，`default_testcase_size="medium"`），4 个 large case（basic_write_read_memory / write_read_memory_stress_test / rand_instr_test / burst_types_test）与描述一致
3. ⚠️ toolchain-notes.md「Cocotb 快速开始」节存在；抽查关键项**全部与源码一致**：chisel 7.0.0-RC1（WORKSPACE:147 ✅）、llvm-firtool 1.114.0（rules/repos.bzl:183 ✅）、toolchain_coralnpu_v2-2026-06-29（WORKSPACE:273 ✅）、riscv64-unknown-elf-gcc 16.1.0（实测 binary `gcc-16.1.0` ✅）、riscv-isa-sim fd72ee2d3e0d（rules/extensions.bzl:126 + rules/deps.bzl:49 ✅）、verilator commit b97df914（外部仓库 rules_hdl `dependency_support/verilator/verilator.bzl:25` ✅）且 configure.ac 声明 `5.051 devel`（与文档"源码 configure.ac 5.051 devel"一致 ✅）、cocotb 2.0.0（外部仓库 `cocotb-2.0.0.dist-info` ✅）、rules_hdl 7a1ba0e8d229（repos.bzl:135 ✅）、磁盘 8.9G/107M（实测 ✅）
4. ✅ coralnpu/ 零改动（git status 干净）；`.tao/` 下改动为任务自身产出（任务文件、toolchain-notes.md、T002-test-csr-full.log），`.tao/README.md` 亦有改动（环境约定迁移，非本任务声明产物，已核验与 T002 无冲突）

**发现的问题**：

- **事实错误（需修正）**：toolchain-notes.md 第 49 行 rules_hdl 行写"挂 **17** 个 coralnpu 机器201 patch"，但 `rules/repos.bzl` 第 139-163 行实际引用 **0001-0019 共 19 个 patch**（`grep -c "third_party/rules_hdl:00"` = 19，磁盘 `third_party/rules_hdl/*.patch` 亦 19 个）。"17"与源码声明不符。
- 备注（非阻塞）：完成区"缓存命中重跑 33.5s"为 8/16 旧缓存记录；今日 reviewer 重跑缓存命中显示 45.8s，因工程师 8/17 强制真实重跑（45.8s）已更新 action cache，属正常现象，不构成伪造。

**判决**：**Needs Revision**

- 具体整改项：将 `.tao/knowledge/toolchain-notes.md` 第 49 行 "挂 17 个 coralnpu 机器201 patch" 修正为 "挂 **19** 个"（repos.bzl 实际引用 0001-0019）；或若坚持 17 需说明剔除依据（0007 skywater / 0013 VCS / 0019 注入修复等），但按 repos.bzl 声明数应为 19。
- 其余验收项（测试通过、方案记录、T006 指向、coralnpu 零改动、依赖清单抽查一致）均已独立重跑验证为真实，修正后即可 Accepted。

#### 第 2 轮 reviewer 验收

**复验背景**：第 1 轮唯一缺陷为 `.tao/knowledge/toolchain-notes.md` 第 49 行 rules_hdl patch 数"17"应为"19"（repos.bzl 实际引用 0001-0019 共 19 个）。主会话已返工修正，本轮复验该缺陷 + 抽查整体验收标准。

**重跑记录**（审查者独立执行，日志留存 `.tao/logs/T002-review-2-bazel-test.log`）：

| # | 命令 | 真实输出（关键行） | 退出码 |
| --- | --- | --- | --- |
| 1 | 缺陷复验：`grep -c "third_party/rules_hdl:00" /home/gxt/fpga/coralnpu/rules/repos.bzl` | `19`（引用 0001-0019，repos.bzl 行 140-157 + 162） | 0 ✅ |
| 2 | 缺陷复验：`ls /home/gxt/fpga/coralnpu/third_party/rules_hdl/*.patch \| wc -l` | `19` | 0 ✅ |
| 3 | 缺陷复验：`grep -n "rules_hdl" /home/gxt/fpga/.tao/knowledge/toolchain-notes.md` 第 49 行 | `挂 19 个 coralnpu 机器201 patch（cocotb/verilator 相关，rules/repos.bzl 引用 0001-0019）` | 0 ✅ |
| 4 | 抽查：`bazel test //tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_csr_test`（缓存命中） | `(cached) PASSED in 36.1s`；`Executed 0 out of 1 test: 1 test passes.`；`INFO: Build completed successfully, 1 total action` | 0 ✅ |
| 5 | 抽查：`git -C /home/gxt/fpga/coralnpu status` | `无文件要提交，干净的工作区`；HEAD `d93b5550` 与接口规范一致 | 0 ✅ |

**约束核验**（对照任务验收标准逐条）：

1. ✅ 方案 B 冒烟：bazel test 退出码 0（本轮独立重跑确认，缓存命中）。
2. ✅ 方案选择（B）与日志片段已记录；剩余 case 覆盖指向 T006，未变化。
3. ✅ **第 1 轮缺陷已闭环**：toolchain-notes.md 第 49 行现为"挂 **19** 个"，与 repos.bzl 引用数（19，0001-0019）及磁盘 patch 文件数（19）三方一致。文档-源码不再矛盾。
4. ✅ coralnpu/ 零改动（git status 干净）。
5. ✅ 依赖清单抽查结果沿用第 1 轮（本轮聚焦缺陷复验，不重复全量核验；第 1 轮已独立核实全部关键项）。

**发现的问题**：无新增问题。

**判决**：**Accepted**

- 第 1 轮缺陷（toolchain-notes.md 第 49 行 patch 数 17→19）已修复并经三方对照复验闭环，无新增问题。
- 整体验收标准（方案 B 冒烟 exit 0、coralnpu 零改动、依赖清单与源码一致）第 1 轮已全量独立验证，本轮抽查仍成立。

#### 第 2 轮 architect 交叉复核（Mimo）

**复核结论**：**确认 Accepted**，无补充发现需打回。

- 对照规划任务文件与实际产出：T002 验收标准 4 条全部被 reviewer 覆盖，无遗漏；我独立验证 `bazel test`（cached PASSED in 36.1s, exit 0）、`git -C coralnpu status`（干净）、T006 文件存在、repos.bzl patch 数 19 三方一致
- reviewer 判决合理性：第 1 轮 Needs Revision（patch 数 17→19）恰当——真实事实错误；第 2 轮 Accepted 成立，无过严/过松
- 约束遵守：coralnpu 零改动、方案 B 记录、T006 覆盖计划均守住
- 依赖清单抽查（rules_hdl patch 19、verilator 5.050/5.051-devel、cocotb 2.0.0）与源码一致
- 未发现 reviewer 遗漏或误判，可进入收尾
