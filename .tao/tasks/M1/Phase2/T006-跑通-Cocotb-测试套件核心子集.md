# T006: 跑通 Cocotb 测试套件核心子集

## 执行环境
**执行环境**：机器201

## 接口规范
- 输入：T002 已验证的 bazel/cocotb 环境；coralnpu `tests/cocotb/BUILD` 中定义的测试 target 清单
- 输出：核心子集测试的运行记录与结果矩阵（`.tao/knowledge/cocotb-test-matrix.md`），子集全绿
- 约束：不新增测试代码（新增属 T007）；子集选择须有理由（不依赖 VCS、实测耗时可控）；**执行时长以实测为准记录，不预设"2 分钟级"**；内存 11G，避免并行跑 large/enormous 测试导致 OOM，建议串行或按 size 分档执行

## 验收标准
1. 从 `bazel query //tests/cocotb:all` 列出全部可运行测试，依据执行时长（实测）与依赖筛选出核心子集（建议覆盖：nop/align 等基础、scalar 算术、至少一个 rvv 相关、一个中断/异常相关）
2. 子集内每个测试 `bazel test //tests/cocotb:<target>` 退出码 0
3. 结果矩阵记录：target、测试内容、实测运行时长、结果（通过/跳过及原因）、对应 RTL 配置
4. 说明哪些 target 被排除及其原因（如依赖 VCS、实测耗时过长、已知失败并附上游 issue 证据）

## 完成区
**状态**：已验证（reviewer 第 3 轮 Accepted + Mimo 交叉复核确认）
**Commit**：无（本任务不涉及代码改动，产出为知识库矩阵文档 `.tao/knowledge/cocotb-test-matrix.md` 与日志 `.tao/logs/T006-*.log`）
**测试结果**：37/37 通过（全部退出码 0）+ 1 个排除（`core_mini_axi_debug_gdbserver`，确定性环境失败，详见矩阵"排除清单"）。覆盖：`core_mini_axi_sim_cocotb` 全量 20 case（CoreMiniAxi scalar）全部通过；RVV 相关 5 个（rvv_add/rvv_arithmetic vanilla/rvv_exceptions/rvv_csr/rvv_basic_write_read_memory）全部通过；nop_stress 1 个通过；`core_mini_axi_debug_cocotb` 11/12 通过（gdbserver 除外）。
**修改文件**：
- 新增：`.tao/knowledge/cocotb-test-matrix.md`（结果矩阵，验收标准第 3 条产出）
- 新增：`.tao/logs/T006-*.log` × 38（每个 case 独立日志，已被 .tao/.gitignore 忽略）
- 未改动任何 coralnpu/ 内文件；未新增测试代码（新增属 T007）
**验收结果**：
- 环境实测：`nproc`=4；`free -h` 显示 total 11Gi / available ~6.5Gi / swap 2Gi（已用 1.1Gi）——证实任务文件"内存 11G"仅为总容量，**全程单 target 串行执行**，无 OOM
- `bazel query 'tests(//tests/cocotb:all)'`：494 个 test targets（已存 /tmp/gxt/T006-query-tests.txt）
- 37 个 target 逐个 `bazel test //tests/cocotb:<target>` 退出码 0；唯一失败 gdbserver 超时（300s）已诊断根因：工具链 `riscv64-unknown-elf-gdb` 硬依赖 `libmpfr.so.4`（机器201仅 libmpfr.so.6），`toolchain/wrappers/gdb` 兼容逻辑在机器201失效（`ldd` 实测 `libmpfr.so.4 => not found`），gdb 无法启动 → pyocd gdbserver 常驻 → 超时。确定性环境问题，**未盲目重试**（无重试依据）
- 完整 PASSED 时长与明细见矩阵文档；真实输出留存于 38 个日志文件
**新发现/坑**：
1. BUILD 中 4 个 `large` case 与 RVV `enormous` case **实测远低于超时档**（basic 85.6s、burst 68.2s、stress 23.3s、rand_instr 5.8s、rvv basic 97.2s）——"large/enormous" 只是分类标签，不是不可跑的判据
2. `riscv_tests` 一个 case 覆盖 158 个 ELF（rv32ui/um/uzbb/uf 含浮点）仅 5.1s，是最经济的 scalar ISA 回归
3. RVV verilator 模型首次构建 ~383s（63 actions），之后全缓存；RVV 测试先构建再跑即可
4. **gdbserver 环境坑**：coralnpu 工具链 gdb 依赖 `libmpfr.so.4`，wrapper 的兼容方案（`ldconfig -p | grep 'mpfr.so$'`）只对装了未版本化 `libmpfr.so`（libmpfr-dev）的系统有效；机器201仅有 libmpfr.so.6。修复需系统级安装 libmpfr4/libmpfr-dev（需 root），建议 T007 跟进
5. 所有单测输出 "specified size is too big" 警告（声明 size>实际耗时），无碍
**遗留问题**：
- `core_mini_axi_debug_gdbserver`（含 RVV 版）未跑通：根因 libmpfr.so.4 缺失，需系统级安装后复验（已附证据，矩阵"排除清单"记录）
- 未跑（超出核心子集，矩阵"排除清单"记录原因）：`rvv_load_store_test_*`（55 单测）、`rvv_ml_ops_cocotb_test_*`（6 单测）、`rvv_highmem_tests_*`（7 单测+1 meta）、`rvv_itcm512kb_dtcm512kb_tests_*`（3 单测+1 meta）、`rvv_bf16_ops`/`zvfbf`/`zfbfmin`（各 2 单测）、`rvv_core_mini_axi_sim_cocotb` 未跑 40 个（43 单测已跑 3）、`rvv_core_mini_axi_debug_cocotb_*`（12）、meta target、`vcs_*`（227）、`verilator_uvm_regression_*`（26）

## 审阅记录

#### 第 1 轮 engineer 自审
**方式**：自主自审（嵌套受限，主会话指示不嵌套子代理，按 engineer 规则降级为自主逐项核对）

**审查意见与核对结果**：

1. **验收标准 1（query + 子集筛选）**：✅ 已执行 `bazel query 'tests(//tests/cocotb:all)'` 得 494 个 test targets；子集覆盖建议全部满足——nop（nop_stress_test）、align（master_write_alignment）、scalar 算术（coralnpu_isa_test + riscv_tests 158 ELF + riscv_dv）、rvv（rvv_add/rvv_arithmetic/rvv_exceptions/rvv_csr/rvv_basic 共 5 个）、中断/异常（exceptions_test、run_wfi_in_all_slots、rvv_exceptions_test）。
2. **验收标准 2（子集退出码 0）**：✅ 37 个 target 全部退出码 0；唯一非绿 gdbserver 已按规则 5 诊断（根因 libmpfr.so.4 缺失，`ldd` 实测 + wrapper 直接复现），非 flaky、无重试依据，故不计入子集并如实记录失败。
3. **验收标准 3（矩阵）**：✅ `.tao/knowledge/cocotb-test-matrix.md` 含 target/测试内容/实测时长/结果/RTL 配置四要素；RTL 配置取自知识库 coralnpu-build-map.md（CoreMiniAxi 与 RvvCoreMiniAxi 的 chisel 参数），非杜撰。
4. **验收标准 4（排除说明）**：✅ 排除 5 类并给原因：vcs 依赖（227）、meta 聚合、UVM 非 cocotb（26）、附加 RVV 套件、gdbserver 环境失败（附 `ldd`/wrapper 复现证据）。
5. **验收标准 5（失败先诊断）**：✅ 仅 1 例失败，诊断链完整（日志超时 → pyocd 常驻 → gdb 启动失败 → libmpfr.so.4 not found → wrapper 兼容逻辑对机器201 ldconfig 失效），未盲目重试。
6. **约束核验**：未新增测试代码 ✅；未改 coralnpu/ 内文件 ✅（仅新增 .tao/ 下矩阵与日志）；日志留存 38 个 ✅；内存实测（nproc/free）记录进矩阵 ✅；全程串行无 OOM ✅。
7. **防造假核验**：所有 PASSED 时长逐条 grep 自真实日志 ✅；gdbserver 失败如实记录（未伪造通过）✅；"37/37 + 1 排除"的计数与日志清单一致（`grep -H "PASSED in"` 输出 37 条 + gdbserver 1 条 FAILED）✅。
8. **数据准确性复核**：vcs 目标数与 uvm 目标数已按 query 输出精确统计（227/26）修正，未用估算值 ✅。

| finding | 处置 | 改了什么 | 复验证据 |
|---------|------|---------|---------|
| 矩阵中 vcs/uvm 排除数量为估算值 | ✅已修 | 按 query 输出精确计数修正为 227/26 | `grep -c "vcs_"`=227、`grep -c "verilator_uvm_regression_"`=26 |
| （无其它 finding） | — | — | — |

**判决**：实现完成，37/37 子集测试通过，1 项排除附完整证据链。可提交验收。

#### 第 1 轮 reviewer 验收
**重跑记录（独立执行，非采信工程师叙述）**：

| 验收命令 | 我的真实输出/退出码 | 结论 |
| --- | --- | --- |
| `bazel query 'tests(//tests/cocotb:all)'` | **494 个 test targets**（重跑存 `/tmp/gxt/review-T006-query.txt`；工程师保存的 `/tmp/gxt/T006-query-tests.txt` 是 503 行但含 9 行 bazel 启动/警告消息，非 target 行） | ✅ 列出成功；⚠️ 完成区"503 个 test targets"**计数有误，应为 494** |
| `bazel test //tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_master_write_alignment` | `(cached) PASSED in 3.9s`，exit=0（日志 `.tao/logs/T006-review-master_write_alignment.log`） | ✅ 通过（与矩阵 3.9s 一致） |
| `bazel test //tests/cocotb:rvv_core_mini_axi_sim_cocotb_rvv_exceptions_test --nocache_test_results` | **真实重跑** `PASSED in 2.6s`，exit=0（日志 `.tao/logs/T006-review-rvv_exceptions_nocache.log`） | ✅ 通过（与矩阵 2.7s 近似一致） |
| `bazel test //tests/cocotb:core_mini_axi_debug_cocotb_core_mini_axi_debug_halt_resume` | `(cached) PASSED in 5.1s`，exit=0（日志 `.tao/logs/T006-review-debug_halt_resume.log`） | ✅ 通过（与矩阵 5.1s 一致） |
| 日志真实性抽查 | `.tao/logs/T006-*.log` 共 **38 个**；`grep -H "PASSED in"` = **37 条**、FAILED = 1 条（gdbserver 300s TIMEOUT，`exit status 3`）；每条 PASSED 时长与矩阵逐条一致；抽查 master_write_alignment / rvv_exceptions 日志为真实 bazel 输出（非伪造） | ✅ 37/37 + 1 FAIL 属实 |
| gdbserver 排除证据复现 | `ldd` 工具链 gdb → `libmpfr.so.4 => not found`；直接运行 gdb → `error while loading shared libraries: libmpfr.so.4` exit=127；runfiles 树内运行 wrapper → 同报错 exit=127；`ldconfig -p | grep 'mpfr.so$'` 无匹配（机器201仅 libmpfr.so.6） | ✅ "确定性环境失败"**属实**，证据链完整 |
| vcs/uvm 排除计数 | `grep -c "vcs_"`（query 结果）= **227**、`verilator_uvm_regression_` = **26**（我的独立 query 输出统计） | ✅ 与矩阵/完成区一致 |
| meta target 存在性 | `core_mini_axi_sim_cocotb`、`rvv_core_mini_axi_sim_cocotb`、`rvv_load_store_test`、`rvv_arithmetic_cocotb_test`、`rvv_ml_ops_cocotb_test` 均在 query 输出中；`nop_stress_test` BUILD 确证 `hdl_toplevel="RvvCoreMiniAxi"` | ✅ |
| RTL 配置引用 | 矩阵 CoreMiniAxi / RvvCoreMiniAxi 参数与 `coralnpu-build-map.md` §3 逐条一致 | ✅ |

**约束核验**：
- `git status`：仅 `M .tao/tasks/Phase2/T006-*.md` + `?? .tao/knowledge/cocotb-test-matrix.md`；**coralnpu/ 内零改动** ✅
- 未新增测试代码（无 coralnpu/ 内文件变更）✅
- 环境实测：`nproc`=4、`free -h` total 11Gi / available 6.0Gi / swap 2Gi 已用 1.3Gi —— 与完成区记录一致；38 个日志时间戳 07:13→07:46 单调递增、无重叠，**串行执行证据充分**，无 OOM ✅

**发现的问题（数据准确性，不涉核心结论）**：
1. **完成区 "503 个 test targets" 计数错误**：我重跑 `bazel query` 得 **494** 个 target。工程师保存的 `/tmp/gxt/T006-query-tests.txt` 为 503 行，但含 9 行 bazel 启动/警告输出（`Starting local Bazel server`、`WARNING: WORKSPACE support...` 等），非 target 行。真实 target 数为 **494**。
2. **矩阵排除清单数量不精确**：
   - `rvv_highmem_tests_*`/`rvv_itcm512kb_dtcm512kb_tests_*` 写"各 3 个"：实测（非 vcs）`rvv_highmem_tests` 前缀共 **8 个** target（含 meta、slow 变体），`rvv_itcm512kb_dtcm512kb_tests` 前缀共 **4 个**（1 meta + 3 testcase）。若口径为"非 slow 非 meta testcase 3 个"可解释，但矩阵未说明口径。
   - `rvv_core_mini_axi_sim_cocotb_*` 未跑的"20 个"：实测非 vcs 前缀共 **43 个** target（含 meta、21 个 slow 变体），已跑 3 个，未跑 **40 个**（或非 slow testcase 未跑 18 个）。"20 个"与两种口径都不符。
   - `rvv_core_mini_axi_debug_cocotb_*`（12 个）✅ 与实测一致。
   - `rvv_load_store_test_*` 非 vcs 55 个 testcase + meta 1 = 56，✅ 基本一致（若含 meta）。
   - `rvv_ml_ops_cocotb_test_*`（6 个）✅ 与实测一致（非 vcs 6 testcase + 1 meta）。

**判决**：**Needs Revision**（核心验收全部实质通过，但完成区与矩阵存在可核实的数字错误，须修正后复验）
- **整改项 1**：完成区 "503 个 test targets" → 修正为 **494**（注明原始文件 503 行含 9 行 bazel 启动/警告非 target 行）。
- **整改项 2**：矩阵排除清单数量按 query 精确修正：`rvv_highmem_tests_*` 8 个（含 meta/slow）、`rvv_itcm512kb_dtcm512kb_tests_*` 4 个（1 meta+3 testcase）、`rvv_core_mini_axi_sim_cocotb_*` 未跑 40 个（含 slow）或明确统计口径。
- **已验证**：query 子集覆盖（nop/align/scalar/rvv/中断异常）✅、3 个代表 case 重跑（1 个真实 nocache）✅、日志 37 PASSED + 1 FAIL 真实 ✅、gdbserver 环境根因（ldd/wrapper 复现）✅、vcs 227 / uvm 26 计数 ✅、RTL 配置引用 ✅、coralnpu 零改动 ✅、串行无 OOM ✅。
- **采信项**（无法独立复现历史行为）：37 个 case 中我仅重跑 3 个代表 case，其余 34 个 PASSED 以日志为准采信（日志内容真实性已验证为真实 bazel 输出）。

#### 第 2 轮 reviewer 验收
**复验范围**：主会话已按第 1 轮整改项修正 3 处数据计数。本轮独立复验这 3 处是否生效、是否引入新问题。

**重跑记录（独立执行，非采信叙述）**：

| 验收命令 | 我的真实输出/退出码 | 结论 |
| --- | --- | --- |
| `bazel query 'tests(//tests/cocotb:all)'`（我重跑，workdir=coralnpu） | target 行 **494 个**（总 504 行，含 bazel 启动/警告 10 行；`grep -cE "^//tests/cocotb:"`=494，exit=0） | ✅ 与修正后"494 个 test targets"一致 |
| 修正点 1：完成区/自审 494 | 任务文件第 27 行"bazel query ...：494 个 test targets"；第 1 轮 reviewer 记录原文未改动（git diff 确认该段完整保留，含"503→494"整改项原文） | ✅ 生效 |
| 修正点 2：矩阵排除清单数字 | 见下逐项 grep | ✅ 生效 |
| 修正点 3：矩阵 sim 未跑 20→40 | 矩阵第 84 行"未跑的其余 case（40 个，共 43 单测已跑 3）" | ✅ 生效 |
| `grep -cE "^//tests/cocotb:rvv_load_store_test_"`（review-T006-query.txt） | **55**；另有 meta `rvv_load_store_test` 1 个 | ✅ 与矩阵"55 个单测"一致 |
| `grep -cE "^//tests/cocotb:rvv_highmem_tests_"` | **7**（3 常规 testcase + slow meta 1 + 3 slow testcase）；另有 meta `rvv_highmem_tests` 1 个，合计 **8** | ✅ 与矩阵"7 个单测，另有 meta 1 个"一致 |
| `grep -cE "^//tests/cocotb:rvv_itcm512kb_dtcm512kb_tests_"` | **3**；另有 meta `rvv_itcm512kb_dtcm512kb_tests` 1 个，合计 **4** | ✅ 与矩阵"3 个单测，另有 meta 1 个"一致 |
| `grep -cE "^//tests/cocotb:(rvv_bf16_ops_cocotb_test|zvfbf_cocotb_test|zfbfmin_cocotb_test)"` | 各 **2**（1 单测 + 1 meta，如 `rvv_bf16_ops_cocotb_test` + `rvv_bf16_ops_cocotb_test_rvv_bf16_ops_test`） | ✅ 与矩阵"各 2 个"一致 |
| `grep -cE "^//tests/cocotb:rvv_core_mini_axi_sim_cocotb_"` | **43**（含 slow meta 1 与 21 个 slow 变体）；已跑 3（B 组 rvv_exceptions_test / csr_test / basic_write_read_memory）→ 未跑 **40** | ✅ 与矩阵"43 单测已跑 3、未跑 40"一致 |
| `bazel test //tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_master_write_alignment` | `(cached) PASSED in 3.9s`，exit=0（日志 `.tao/logs/T006-review-r2-cached.log`） | ✅ 缓存命中，与矩阵 3.9s 一致 |
| 日志抽查 | `.tao/logs/T006-*.log` 38 个；`grep -l "PASSED in"`=37、`grep -l "FAILED"`=1 | ✅ 与完成区"37/37 + 1 排除"一致 |
| `git status --short` | 仅 `M .tao/tasks/Phase2/T006-*.md` + `?? .tao/knowledge/cocotb-test-matrix.md`；coralnpu/ 内零改动 | ✅ 干净 |

**发现的问题（未闭环，第 1 轮同类残留）**：
- **任务文件完成区"遗留问题"行（第 38 行）仍保留第 1 轮旧数字，未随矩阵同步修正**：
  - `rvv_load_store_test_*`（**56**）→ 矩阵已改为 55 单测；
  - `rvv_highmem_tests_*`/`rvv_itcm512kb_dtcm512kb_tests_*`（**各 3**）→ 矩阵已改为 7 单测+1 meta / 3 单测+1 meta；
  - `rvv_core_mini_axi_sim_cocotb` 未跑 **20 个** → 矩阵已改为 40 个。
  - 该行自第 1 轮即含此错误（第 1 轮 reviewer 已指出"完成区与矩阵存在可核实的数字错误"），本轮返工只改了矩阵与"494"，**这一行未同步**，导致任务文件自身与矩阵口径矛盾。

**约束核验**：
- 未新增测试代码、未改 coralnpu/ 内文件 ✅（git status 确认）
- 矩阵/日志/494 计数全部与 query 全表一致 ✅
- 第 1 轮 reviewer 记录保持原文未被改动 ✅

**判决**：**Needs Revision**（第 1 轮 3 处修正已生效，但整改不完整——任务文件完成区"遗留问题"行仍是旧数字 56/各 3/未跑 20，与矩阵及实测矛盾）
- **整改项**：同步修正任务文件完成区"遗留问题"行（第 38 行）数字为矩阵口径：`rvv_load_store_test_*`（55 单测）、`rvv_highmem_tests_*`（7 单测+1 meta）、`rvv_itcm512kb_dtcm512kb_tests_*`（3 单测+1 meta）、`rvv_core_mini_axi_sim_cocotb` 未跑 40 个、`rvv_bf16_ops`/`zvfbf`/`zfbfmin`（各 2）。
- **已验证**：494 计数 ✅、矩阵排除清单 5 项数字（55/7+1/3+1/各2/40）✅、43-3=40 口径 ✅、缓存命中 ✅、git 干净 ✅、日志 37+1 ✅。
- **采信项**：37 个 case 中本轮仅重跑 1 个缓存命中代表 case，其余以日志为准（第 1 轮已逐条核实日志真实性）。

#### 第 3 轮 reviewer 验收
**复验范围**：主会话已按第 2 轮整改项同步任务文件"遗留问题"行（第 38 行）数字。本轮独立复验该行与矩阵口径一致，并抽查整体验收仍成立。

**重跑记录（独立执行，非采信叙述）**：

| 验收命令 | 我的真实输出/退出码 | 结论 |
| --- | --- | --- |
| `bazel test //tests/cocotb:core_mini_axi_sim_cocotb_core_mini_axi_master_write_alignment`（workdir=coralnpu） | `(cached) PASSED in 3.9s`，exit=0（日志 `.tao/logs/T006-review-r3-cached.log`） | ✅ 缓存命中，与矩阵 3.9s、第 1/2 轮一致 |
| `grep -cE "^//tests/cocotb:rvv_load_store_test_"`（review-T006-query.txt，我第 1 轮保存的 query 输出） | **55**（另有 meta 1） | ✅ 与第 38 行"55 单测"及矩阵一致 |
| `grep -cE "^//tests/cocotb:rvv_ml_ops_cocotb_test_"` | **6**（另有 meta 1） | ✅ 与第 38 行"6 单测"及矩阵一致 |
| `grep -cE "^//tests/cocotb:rvv_highmem_tests_"` | **7**（另有 meta 1，合计 8） | ✅ 与第 38 行"7 单测+1 meta"及矩阵一致 |
| `grep -cE "^//tests/cocotb:rvv_itcm512kb_dtcm512kb_tests_"` | **3**（另有 meta 1，合计 4） | ✅ 与第 38 行"3 单测+1 meta"及矩阵一致 |
| `grep -cE "^//tests/cocotb:(rvv_bf16_ops_cocotb_test\|zvfbf_cocotb_test\|zfbfmin_cocotb_test)"` | 三前缀合计 **6**（各 2） | ✅ 与第 38 行"各 2 单测"及矩阵一致 |
| `grep -cE "^//tests/cocotb:rvv_core_mini_axi_sim_cocotb_"` | **43**（含 slow/meta）；已跑 3 → 未跑 40 | ✅ 与第 38 行"未跑 40（43 已跑 3）"及矩阵一致 |
| `rvv_core_mini_axi_debug_cocotb_*`/`vcs_*`/`verilator_uvm_regression_*` 计数 | 12 / 227 / 26（第 1/2 轮已实测） | ✅ 与第 38 行一致 |
| 日志目录 | `.tao/logs/T006-*.log` 44 个 = 38 核心 + 6 review（5 前轮 + 本轮 1）；`grep -l "PASSED in"`=42（37 核心 + 5 review）、`grep -l "FAILED"`=1（gdbserver） | ✅ 核心 37 PASS + 1 FAIL 结构未变 |
| `git status --short` | 仅 `M .tao/tasks/Phase2/T006-*.md` + `?? .tao/knowledge/cocotb-test-matrix.md`；coralnpu/ 内零改动 | ✅ 干净 |

**第 38 行逐项核对结果**（第 2 轮整改项，与矩阵第 80/82/83/84 行口径逐一对照）：

- `rvv_load_store_test_*`（**55 单测**）✅ 与矩阵"55 个单测"一致
- `rvv_ml_ops_cocotb_test_*`（**6 单测**）✅ 与矩阵"6 个单测"一致
- `rvv_highmem_tests_*`（**7 单测+1 meta**）✅ 与矩阵"7 个单测，另有 meta 1 个"一致
- `rvv_itcm512kb_dtcm512kb_tests_*`（**3 单测+1 meta**）✅ 与矩阵"3 个单测，另有 meta 1 个"一致
- `rvv_bf16_ops`/`zvfbf`/`zfbfmin`（**各 2 单测**）✅ 与矩阵"各 2 个单测"一致
- `rvv_core_mini_axi_sim_cocotb` 未跑 **40 个（43 单测已跑 3）** ✅ 与矩阵"40 个，共 43 单测已跑 3"一致
- `rvv_core_mini_axi_debug_cocotb_*`（**12**）✅ 与矩阵一致
- `vcs_*`（**227**）✅ 与矩阵一致
- `verilator_uvm_regression_*`（**26**）✅ 与矩阵一致

第 2 轮整改项全部闭环，任务文件自身与矩阵口径不再矛盾。

**约束核验**：
- 未新增测试代码、未改 coralnpu/ 内文件 ✅（git status 确认）
- 第 1/2 轮 reviewer 记录原文保留 ✅（第 63-132 行完整）
- 本轮复验日志已存 `.tao/logs/T006-review-r3-cached.log` ✅

**判决**：**Accepted** —— 第 1/2 轮缺陷（503→494 计数、矩阵排除清单 5 处数字、遗留问题行数字）全部闭环，无新增问题。核心结论仍成立：query 494 个 target、37/37 子集通过、gdbserver 确定性环境失败（libmpfr.so.4 缺失）有完整证据链。
- **已验证**：第 38 行 9 项数字与矩阵全部一致 ✅、缓存命中 3.9s ✅、git 干净 + coralnpu 零改动 ✅、日志 37 PASS + 1 FAIL 结构 ✅。
- **采信项**：37 个 case 本轮仅重跑 1 个缓存命中代表 case（第 1 轮已真实 nocache 重跑 1 个、缓存重跑 2 个并逐条核实 38 个日志真实性）；gdbserver 根因以第 1 轮 ldd/wrapper 复现证据为准。

#### 第 1 轮 architect 交叉复核（Mimo）

**复核结论**：**确认 Accepted**，通过收尾。

- reviewer 三轮回合机制合理：第 1 轮（503→494 + 矩阵计数）、第 2 轮（遗留问题行未同步）定位准确，第 3 轮 Accepted 无过严/过松
- 数据一致性独立抽查通过（highmem 7+1 meta、sim 43-3=40、vcs 227 与 494 全表一致）
- 排除清单证据充分：gdbserver（libmpfr.so.4 缺失，ldd + wrapper 复现）、vcs（license）、uvm（非 cocotb）、附加 RVV（代表 case 已验证）
- 约束无违反：不新增测试代码、coralnpu 零改动
