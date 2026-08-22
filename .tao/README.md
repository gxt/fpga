# fpga 工作仓库

本仓库用于 FPGA 相关的开发，覆盖从模拟（simulation）到综合（synthesis）的完整流程。

## 机器分工（2026-08-20 调整）

- **201**（机器201 fpga201，192.168.200.201）：fpga 仓库维护、opencode 运行、**板卡烧录与连接**（Vivado Hardware Manager）。**非特殊情况不调用 Vivado**（内存受限 11G），特殊情况需咨询用户确认。
- **202**（zzx-NF5280，192.168.200.202）：**所有 Vivado 任务**——仿真（xsim）、综合、实现、bitstream。fpga 主仓库 git 经 201 局域网同步（**主仓库仅限 201 push/pull**；202 外网已通，coralnpu submodule 及软件走外网）；按任务建子目录并尽可能创建 `.xpr` 工程；**sudo 命令必须经用户允许**。
- 详见 `.tao/knowledge/registry.md`（路由）与 `synth-server.md`（拓扑）。

## 仓库结构（2026-08-21 现状）

```
.
├── .tao/             工作仓库交互目录
│   ├── README.md     本文件：项目结构与角色流程
│   ├── tasks/        任务文件（M1/Phase0-4 已完成归档、M2/ 第二阶段）
│   ├── knowledge/    知识沉淀（registry/synth-server/board-notes/synth-notes/board-debug-log/flow-guide/soc-analysis/adr-*）
│   └── logs/         会话/验收日志
├── coralnpu/         Google Coral NPU（git submodule fork，见下节）
├── scripts/          机器202 交互（run202*.sh）+ 综合/烧录流程（build_top/program_top/resume/wrapper.tcl）+ 仿真脚本（t016_xsim*.sh）
├── sim/              上板调试/测试脚本（T007-* 程序、T015-* 上板脚本、T016-debug_write_tcm.py）
├── synth/            综合工程
│   ├── rtl/          上板顶层 RTL（top_coralnpu/host_cmd_fsm/uart_rx·tx/axi_master_stub）
│   ├── sim/          仿真 tb（T010-tb_top/T016-tb_debug_test/T016-tb_uart_cont）
│   ├── xdc/          引脚/时钟约束（top_coralnpu.xdc）
│   └── out/          任务产物（<任务>-<描述>/；中间版本归档 _archive/）
├── docs/             文档
└── .gitignore
```

## 工具链现状（2026-08-21）

| 工具 | 版本/说明 | 执行地 |
| --- | --- | --- |
| bazel/bazelisk | 8.6.0（构建 coralnpu SV，需 `CC=clang-14`） | 201/202 |
| Vivado | 2025.1（xsim 仿真/综合/实现/bitstream/烧录） | 202（仿真/综合）、201（烧录） |
| Verilator/Cocotb | coralnpu 官方 sim（Phase0-2 已验证） | 202 |
| riscv64 gcc | T007 程序交叉编译（rv32imf_zve32f） | 201 |
| 目标器件 | xc7v2000tflg1925-1（S2C Dual Virtex-7 TAI LM） | 202 |
| 上板 UART | 子板 AV42/AU42 → CH341 /dev/ttyUSB0 115200（`sg dialout`） | 201 |

详见 `.tao/knowledge/synth-server.md`（综合拓扑）、`flow-guide.md`（全流程/目录约定/时间表）。

## coralnpu 子模块管理

coralnpu 以 git submodule 引入，作为首要复现对象。

- **机器202**：`origin` 指向**自己的 fork**（`https://github.com/gxt/coralnpu.git`），官方仓库为 `upstream`（`https://github.com/google-coral/coralnpu.git`），仅用于拉取上游更新。
- **为什么**：官方仓库无写权限；子模块修改必须推送到自己的 fork，否则 `git submodule update` 会覆盖丢失机器201改动。
- **修改流程**：
  1. 在 `coralnpu/` 内修改并 `git commit`
  2. `git push origin <branch>`（推送到自己的 fork）
  3. 在主仓库 `git add coralnpu`（更新 gitlink 指向新 commit）并提交
  4. 记录实质改动到 `.tao/knowledge/changelog.md`
- **同步上游**：`git -C coralnpu fetch upstream && git -C coralnpu merge upstream/main`，处理冲突后走上述推送流程。
- **约定**：不改动官方代码时，子模块保持指向官方最新 commit；改动一律落回 fork。

## 角色流程

- **architect**：澄清需求、拆分任务、创建任务文件，写入 `.tao/tasks/`。
- **engineer**：按任务文件实现，Spec-first，完成后自审。
- **reviewer**：独立验证产出，重跑验收命令，判定 Accepted / Needs Revision。

任务流转遵循"任务文件 → 实现 → 验收"的顺序，任务文件即契约。

## 工具链现状（2026-08-21）

- **模拟**：Verilator/Cocotb（coralnpu 官方 sim，T001-T007 已验证）+ Vivado xsim（上板 RTL 功能验证）。
- **综合/实现/bitstream**：Vivado 2025.1，目标器件 `xc7v2000tflg1925-1`（S2C Dual Virtex-7），机器202 执行（`scripts/build_top.tcl`，batch/proj 双模式）。
- 详细使用记录见 `.tao/knowledge/synth-notes.md`（T009/T010 决策/结果/坑）与 `flow-guide.md`（全流程/时间表/目录约定）。

## 机器201环境约定

机器201/账号级环境约定（可执行文件路径、临时目录、用户名动态化）已移至全局 opencode 配置 `~/.config/opencode/instructions/env.md`，跨项目生效；本文件仅保留 bazelisk 版本选择说明。

- **bazelisk 版本选择**：优先级（高→低）`USE_BAZEL_VERSION` 环境变量 > `~/.bazeliskrc` > workspace 根 `.bazelversion` > latest。已建 `~/.bazeliskrc`（`USE_BAZEL_VERSION=8.6.0`）全局兜底：任意目录 `bazel` 默认 8.6.0（已缓存，不触发下载），**不再自动下载最新版**。注意：bazeliskrc 优先于 workspace 内 `.bazelversion`，未来某 workspace 需其它版本时用环境变量临时覆盖；主仓库根不再维护 `.bazelversion`/`MODULE.bazel`（coralnpu/ 的 `.bazelversion` 声明 8.6.0）。

## 约定

- 工作先读本文件，遵循全局 `~/.config/opencode/AGENTS.md` 规则。
- 最小修改、一次一件事；复用优先，不过度设计。
- 阶段交付时主动验证（跑模拟或综合命令）。

## 上板操作纪律（2026-08-20 起）

1. **复位确认**：凡涉及板卡 SW1 复位，必须先提醒用户、**等用户确认复位完成后再继续**；复位后等待（≥2s）+ `?` 重试确认 UART 稳定，禁止盲跑。
2. **脚本工作流**：上板/仿真脚本在**机器201 编写**（git 提交推送）→ **机器202 `git pull` 执行**（Vivado/xsim）；上板脚本机器201 本地执行（`sg dialout` 访问串口）。
3. **串口**：子板 UART = `/dev/ttyUSB0`（CH341，115200）；SRAM 复位不清（读回旧值属正常）。
4. 板级调试过程与坑见 `.tao/knowledge/board-debug-log.md`。
- **命令执行与失败处理纪律**已移至全局配置 `~/.config/opencode/instructions/discipline.md`（所有会话与子代理强制遵循）。

## 查看进展与下一步

使用 `/status` 命令查看全部任务状态、当前阶段与下一步（等价功能，见 `~/.config/opencode/command/status.md`）。
