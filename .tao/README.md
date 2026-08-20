# fpga 工作仓库

本仓库用于 FPGA 相关的开发，覆盖从模拟（simulation）到综合（synthesis）的完整流程。

## 机器分工（2026-08-20 调整）

- **201**（本机 fpga201，192.168.200.201）：fpga 仓库维护、opencode 运行、**板卡烧录与连接**（Vivado Hardware Manager）。**非特殊情况不调用 Vivado**（内存受限 11G），特殊情况需咨询用户确认。
- **202**（zzx-NF5280，192.168.200.202）：**所有 Vivado 任务**——仿真（xsim）、综合、实现、bitstream。fpga 主仓库 git 经 201 局域网同步（**主仓库仅限 201 push/pull**；202 外网已通，coralnpu submodule 及软件走外网）；按任务建子目录并尽可能创建 `.xpr` 工程；**sudo 命令必须经用户允许**。
- 详见 `.tao/knowledge/registry.md`（路由）与 `synth-server.md`（拓扑）。

## 仓库结构

```
.
├── .tao/            工作仓库交互目录（本文件所在处）
│   ├── README.md    本文件：项目结构与角色流程
│   ├── tasks/       任务文件（架构师拆分的任务）
│   ├── knowledge/   知识沉淀（工具链、器件、时序等经验）
│   └── logs/        会话日志
├── coralnpu/        Google Coral NPU（git submodule，见下节）
├── rtl/             源码（计划）
├── sim/             模拟环境（计划）
├── synth/           综合/实现工程（计划）
├── docs/            文档（计划）
└── .gitignore
```

当前仅完成仓库初始化，`rtl/`、`sim/`、`synth/` 目录随任务推进建立。

## coralnpu 子模块管理

coralnpu 以 git submodule 引入，作为首要复现对象。

- **远端**：`origin` 指向**自己的 fork**（`https://github.com/gxt/coralnpu.git`），官方仓库为 `upstream`（`https://github.com/google-coral/coralnpu.git`），仅用于拉取上游更新。
- **为什么**：官方仓库无写权限；子模块修改必须推送到自己的 fork，否则 `git submodule update` 会覆盖丢失本地改动。
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

## 工具链现状

- **模拟**：待定（开源 iverilog/verilator，或 Vivado xsim）。
- **综合**：待定（优先兼容 Vivado，目标器件 Xilinx/AMD）。
- 决定后更新本文件，并在 `.tao/knowledge/` 沉淀使用记录。

## 本机环境约定

本机/账号级环境约定（可执行文件路径、临时目录、用户名动态化）已移至全局 opencode 配置 `~/.config/opencode/instructions/env.md`，跨项目生效；本文件仅保留 bazelisk 版本选择说明。

- **bazelisk 版本选择**：优先级（高→低）`USE_BAZEL_VERSION` 环境变量 > `~/.bazeliskrc` > workspace 根 `.bazelversion` > latest。已建 `~/.bazeliskrc`（`USE_BAZEL_VERSION=8.6.0`）全局兜底：任意目录 `bazel` 默认 8.6.0（已缓存，不触发下载），**不再自动下载最新版**。注意：bazeliskrc 优先于 workspace 内 `.bazelversion`，未来某 workspace 需其它版本时用环境变量临时覆盖；主仓库根不再维护 `.bazelversion`/`MODULE.bazel`（coralnpu/ 的 `.bazelversion` 声明 8.6.0）。

## 约定

- 工作先读本文件，遵循全局 `~/.config/opencode/AGENTS.md` 规则。
- 最小修改、一次一件事；复用优先，不过度设计。
- 阶段交付时主动验证（跑模拟或综合命令）。
- **命令执行与失败处理纪律**已移至全局配置 `~/.config/opencode/instructions/discipline.md`（所有会话与子代理强制遵循）。

## 查看进展与下一步

使用 `/status` 命令查看全部任务状态、当前阶段与下一步（等价功能，见 `~/.config/opencode/command/status.md`）。
