# 开发全流程指南（需求讨论 → 上板调试）

日期：2026-08-21
目的：固化"需求讨论 → EDA 仿真/综合/实现 → 上板调试"的完整流程，明确每步执行地、耗时、协作模式与规范。

## 1. 阶段划分

| # | 阶段 | 执行地 | 耗时 | 协作模式 |
| --- | --- | --- | --- | --- |
| 0 | 需求讨论/方案 | 201 | 分钟级 | 交互（反向追问澄清） |
| 1 | RTL 开发（bazel 生成 SV / 手写 RTL） | 201 | 1-10min | 交互/等待 |
| 2 | 仿真验证（xsim + tb） | 202 | 1-5min | **快速：opencode 等待完成** |
| 3 | 综合+实现+bit | 202 | **25-35min** | **慢速：nohup 安排，opencode 不等待** |
| 4 | 产物检查（rsync bit/报告、0 ERROR/时序） | 201 | 1-2min | 交互 |
| 5 | 上板烧录 | 201 | 2-3min | **进行前提醒用户** |
| 6 | 上板调试（复位确认、串口脚本、结果验证） | 201 | 每轮 1-5min | 交互（复位必先确认） |
| 7 | 收尾沉淀（日志/任务完成区/提交） | 201 | 分钟级 | 交互 |

## 2. 时间估计表（实测基准）

| 任务 | 估计耗时 | 模式 |
| --- | --- | --- |
| bazel 增量构建（CoreMiniAxi/SoC SV） | 1-3min | opencode 等待 |
| xsim 仿真（编译 + 运行） | 1-5min | opencode 等待 |
| **综合 + 实现 + bitstream**（xc7v2000t） | **25-35min**（synth ~13min + place ~5min + route 10-18min + bit ~2min） | **nohup 安排，不等待** |
| 完整 SoC 综合（T009 参考，xcvu13p synth_only） | ~1h25m | nohup 安排，不等待 |
| 上板烧录 | 2-3min | 提醒后执行 |
| 上板串口测试（单轮） | 1-5min | 交互 |

**协作约定**：
- 快速任务（≤5min）：opencode 直接阻塞等待 202 执行完成并取结果
- 慢速任务（>10min）：opencode 仅安排任务（nohup 启动），**告知用户预计时间**，不等待；用户按估计时间查询（`run202_wait.sh`）后继续下一步
- 查询方式（**非阻塞**）：`run202_check.sh <task>` —— 立即返回状态（进行中/已完成）+ 进度线索 + ERROR 数，不等待
- 如需阻塞（可选）：`run202_wait.sh <task>` —— 单条命令远端等待至完成

## 3. 远程任务规范

- **启动**：`scripts/run202.sh <task> <cmd...>` —— ssh 到 202 用 `nohup` 后台启动（防网络中断），任务日志落 `~/fpga/work/<task>/build.log`
- **等待**：`scripts/run202_wait.sh <task> [pid_pattern]` —— 单条 ssh 远端 `while pgrep ...; do sleep 15; done`，返回即完成
- **目录**：201 `synth/out/<日期>-<任务>-<描述>/`（bit/报告）；202 `~/fpga/work/<task>/`（工程/日志）
- **网络纪律**：所有远程启动必须 nohup + 日志重定向；禁止本地 sleep+多次查询循环

## 4. 目录命名规范（统一）

**每个任务独立子目录，命名统一 `<任务>-<描述>`**（连字符小写，201/202 同名）：

| 位置 | 规范 | 示例 |
| --- | --- | --- |
| 201 产物 | `synth/out/<任务>-<描述>/` | `synth/out/T010-sync/` |
| 202 工作 | `~/fpga/work/<任务>-<描述>/` | `~/fpga/work/T010-sync/` |

- 任务编号统一（`T###` 或简称），描述简短小写连字符（`fix-clk`/`hosttcm`/`baudfix`/`sync`）
- 禁止：下划线分隔描述、前缀游离（如 `synth_t008_check`）、无描述裸名（如 `T010`）

**历史重命名映射（2026-08-21 规范化）**：
- `synth_t008_check` → `T008-check`
- `T009_chip_nexus_synth_only` → `T009-chip-nexus-synth`
- `T010`（首版）→ `T010-first`
- 202 `run202-*` 测试残留已清理

## 5. bit 产物规范

- 每次生成 bit 用**专门子目录**：`synth/out/<日期>-<任务>-<描述>/`（如 `synth/out/20260821-T010-sync/`）
- **必须建 Vivado xpr 工程文件**：综合用 `build_top.tcl` 工程模式（`create_project`，参数 `proj`），产出 `.xpr`；非工程 batch 模式保留（参数 `batch`）用于快速迭代
- 产物：`top_coralnpu.bit`/`.bin`、`post_route.dcp`、各 `*.rpt`（utilization/timing/route_status/drc）
- 烧录用指定 bit 文件（先 `ls -la synth/out/*/top_coralnpu.bit` 确认最新版本再烧）

## 6. 提醒机制（强制约定）

以下操作**执行前必须提醒用户并等确认**：
1. **长时间任务启动**（综合/完整 SoC/长仿真）：提醒 + 告知预计耗时
2. **上板烧录**：提醒将烧录哪个 bit（含版本/时间戳确认）
3. **板卡 SW1 复位**：每次复位前提醒并等用户确认
4. 长时间串口测试/可能影响板卡的实验

## 7. 上板调试标准流程

1. 提醒 → 烧录 bit（确认版本）→ 提醒 → 用户复位
2. `sg dialout` 跑测试脚本（`sim/` 下按需选择）
3. 结果验证 + 记录到 `board-debug-log.md`
4. 问题沉淀：证据链（先确认环境/时序，再改 RTL）+ 每次改动记录

### 上板调试输出约定（强制）

- **运行测试脚本必须实时、完整显示输出**，能看到"运行到哪一步、正在做什么"
- **禁止用 `| tail`、`| head` 等截断管道**接调试脚本输出——截断后看不到中间进度，只能干等
- 调试脚本（`sim/*.py`）本身应打印每步进度（如 `T015-itcm_direct_test` 每字一行、`T015-load_elf` 加载计数、`T015-csr_probe` 每步读值），运行时不加任何输出过滤
- 例外：仅当输出**确实过大**且需要看尾部时，可先完整落盘再分块查看（如 `> log 2>&1` 后 `run202_check`/分段读文件），**不适用于交互式上板测试**

## 8. 工具清单

- `scripts/run202.sh`：201→202 远程 nohup 任务启动
- `scripts/run202_wait.sh`：阻塞等待任务完成
- `scripts/build_top.tcl`：综合+实现+bit（batch/proj 双模式）
- `scripts/program_top.tcl`：烧录
- `sim/*.py`：上板测试脚本（T015-itcm_direct_test/T015-uart_raw_probe/T015-load_elf/T015-t007_result_check 等）
