# fpga 工作仓库

本仓库用于 FPGA 相关的开发，覆盖从模拟（simulation）到综合（synthesis）的完整流程。

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

## 约定

- 工作先读本文件，遵循全局 `~/.config/opencode/AGENTS.md` 规则。
- 最小修改、一次一件事；复用优先，不过度设计。
- 阶段交付时主动验证（跑模拟或综合命令）。

## 命令执行与失败处理纪律

适用于所有会话与子代理，尤其针对复杂/长耗时命令（bazel 构建、Vivado 综合等）。

1. **执行前声明预期**：说明命令目的 + 期望的 exit code / 输出标志。
2. **失败先诊断**：先读全量错误输出/日志，定位首个根因；禁止无依据重试或换参数乱试。
3. **有依据重试，最多 2 次**：每次重试必须说明「改了什么、为何这次会成功」。
4. **停止升级**：2 次无效立即停止，向用户汇报根因分析 + 候选方案，由用户决策。
5. **长命令超时保护**：为 bazel/Vivado 类长命令设充足 timeout，避免中途被杀掩盖真实问题。
6. **记录沉淀**：失败根因与坑写入任务文件「新发现/坑」及 `.tao/knowledge/`。
