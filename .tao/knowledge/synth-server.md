# 机器202执行拓扑（synth-server.md）

本文件记录机器202（zzx-NF5280 · 192.168.200.202）的执行拓扑，由 T008 负责维护细化。机器202硬件/Vivado 信息见 `registry.md`。

## 决策记录

- **执行模式（2026-08-16，用户决策）：路径 A —— 机器201 ssh 直连机器202执行**
  - 机器201会话作为控制端，通过 `ssh gxt@192.168.200.202` 在机器202运行 Vivado batch 命令
  - 长任务（综合/实现）用 tmux/nohup 托管，日志拉回机器201分析
  - **不在机器202部署 opencode**，不启用「机器202智能体」路由
  - 若后续长综合迭代拉日志往返频繁，再评估升级路径 B（机器202 opencode，待用户再决策）

## 执行拓扑三要素（2026-08-20 调整：xsim 仿真迁入 202）

**结论：202 = Vivado 专属执行机（仿真 + 综合 + 实现 + bitstream）；201 = 仓库维护 + opencode + 板卡烧录（非特殊情况不调用 Vivado）**

| 要素 | 决策 | 依据 |
| --- | --- | --- |
| ① 202 跑什么 | **所有 Vivado 任务**：仿真（xsim）、综合（synth）、实现（place&route）、write_bitstream。不跑 bazel/fusesoc | 202 无 bazel/fusesoc（实测）；**2026-08-20 起 xsim 仿真从 201 迁入 202**（201 内存受限 11G，202 62GiB 充裕；用户决策） |
| ② 依赖到位方式 | **git 同步**：fpga 主仓库 202 从 201 `git pull`（局域网，主仓库仅限 201 push/pull）；coralnpu submodule 及其他软件/依赖走**外网**（2026-08-20 起外网已通）；`synth/sync.sh`（rsync）辅助推送大产物（RTL 生成物/网表/报告） | 主仓库 git 同步仅允许经 201（用户约定）；202 外网已通（2026-08-20 实测 github/pypi 可达）；RTL 生成（bazel）在 201 完成 |
| ③ 每步执行机器 | RTL 生成（Chisel→SV）：**201** bazel；仿真/综合/实现/bitstream：**202** Vivado batch（201 ssh 直连托管）；结果（报告/bitstream/日志）**拉回 201** 分析 | 用户决策（2026-08-20）：201 除烧录/板卡连接外非特殊情况不调用 Vivado，特殊情况需咨询确认 |

## 202 工作规范（2026-08-20，用户要求）

1. **fpga 目录 git 化**：202 `~/fpga/` 为 git 仓库，与 201 保持一致并同步（局域网 `git pull`；coralnpu submodule 内容由 201 侧提供）
2. **任务子目录 + Vivado 工程**：针对具体任务创建子目录（如 `~/fpga/work/<T0xx>/`），**尽可能创建 Vivado 工程文件（.xpr）**（非仅 batch tcl），便于工程化管理与复用
3. **sudo 约束**：202 上所有 `sudo` 命令必须经过用户允许（不得擅自执行）
4. 长任务（仿真/综合）用 tmux/nohup 托管，日志拉回 201 分析

> 若后续 T009 官方器件（xcvu13p）走 fusesoc 完整流程需要机器202 bazel，可作为增强项评估（需在机器202装 bazelisk 并冷拉依赖，预计与机器201同等量级耗时），当前不启用。

## 202 任务 git 同步流程（2026-08-20 用户确认）

**原则**：git 只能同步 commit（不能同步未提交改动）；主仓库只从 201 push/pull（202 不 push）；Vivado 产物与 git 并行不冲突。

### 任务启动前
1. **201 git 仓库干净**：`git status` 无未提交改动；有则先提交并 `git push origin master`
2. **同步给 202**：202 `cd ~/fpga && git pull origin master`（origin = 201 局域网）；submodule 如有更新 `git submodule update`

### 任务执行中（202）
- 可修改 git 受管文件（`.tao/`、`synth/`、`sim/` 等）
- Vivado 产物（`work/`、`rtl_out/`、`synth/out/`）在 .gitignore，**不走 git**，经 `synth/sync.sh` rsync 回传

### 任务完成后
1. **202 提醒用户**（经 201 会话汇报）：变更清单 = git 受管改动（文件 + 类型）+ Vivado 产物（work/ 路径/大小）+ 待清理临时文件
2. **用户决定是否提交**：确认哪些改动该提交；临时文件先清理
3. **202 本地 commit**（用户确认后，提交信息按 git-commit 规范，可标注「（机器202）」区分执行机）
4. **201 拉取**：**先 `git fetch fpga202` 更新 remote-tracking 快照，再 `git pull fpga202 master`**（`fpga202` remote 已配置 = `gxt@192.168.200.202:/home/gxt/fpga`；**201 发起拉取，202 不 push**）——注意：`fpga202/master` 是本地快照，只在 fetch 时更新，202 有本地 commit 后必须 fetch 再 pull，避免快照过期
5. **201 审查并推送**：确认提交内容后 `git push origin master`；202 后续 pull 保持同步

### 约束
- 双向"干净"前置：启动 202 任务前 201 干净；201 拉取 202 前 201 也须干净（避免未提交改动干扰 pull）
- 202 不直接 push 到 201 仓库（主仓库操作从 201 发起）
- 202 commit 署名建议与 201 一致（`gxt@gxt@pku.edu.cn`），历史可读

## 文件交换（2026-08-20 更新：git 同步为主）

- **主路径（git）**：202 fpga 目录为 git 仓库，与 201 同步（局域网 `git pull`；coralnpu submodule 内容由 201 侧同步提供）——小文件/源码/文档走 git
- **辅助（sync.sh）**：大产物（RTL 生成物 `.sv/.h/.zip`、网表、报告、bitstream）用 `synth/sync.sh push/pull`（rsync 增量）推 202 `~/fpga/rtl_out/<key>/`、`~/fpga/work/` 拉回 201 `synth/out/`
- 不把密码/密钥写入脚本或任务文件（ssh 依赖密钥免密，BatchMode）

## 关键命令记录（T008 实测）

- 机器202 `vivado -version`（2026-08-18，验收 3）：
  ```
  vivado v2025.1 (64-bit)
  Tool Version Limit: 2025.05
  SW Build 6140274 on Wed May 21 22:58:25 MDT 2025
  IP Build 6138677 on Thu May 22 03:10:11 MDT 2025
  SharedData Build 6139179 on Tue May 20 17:58:58 MDT 2025
  ```
  与机器201一致（≥ 项目要求，支持目标器件）
- license 识别目标器件检查（2026-08-18，验收 5，`vivado -mode batch` + `get_parts`）：
  ```
  xc7v2000tflg1925-1: RECOGNIZED -> xc7v2000tflg1925-1
  xcvu13p-fhga2104-2-e: RECOGNIZED -> xcvu13p-fhga2104-2-e
  virtex7 全族 part 数: 203
  ```
  检查 tcl 留存机器202 `~/fpga/T008-get_parts.tcl`，完整日志 `.tao/logs/T008-license-get_parts.log`

## T009 实测补充（2026-08-18，官方器件基线综合）

- **license 配置（关键，T010/T011 必须）**：机器202需在综合命令前 `export XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic`（Vivado_System_Edition）。T008 的 `get_parts` "RECOGNIZED" ≠ 可综合（不耗 license）；首次综合因无 license 环境变量报 `Common 17-345`。当前仅命令内 export，未持久化（如需可加入 `~/.bashrc` 或综合脚本）
- **官方器件综合流程（实测可行）**：机器201 fusesoc 2.4.3 `run --target=synth --setup` 生成工程（官方流程，参数与 `_NEXUS_NAME_MAP` 一致）→ `sync.sh push` 到机器202 → 机器202 `make synth`。机器202当时无外网/pip 不可装 fusesoc（**2026-08-18 历史实测；2026-08-20 起外网已通，可 pip 安装**）；机器201直接 fusesoc_build 会 OOM（内存峰值 22.8G > 机器201 11G）
- **内存**：`synth_design` PSS 峰值 22811MB → **机器202（62GiB）为唯一可行综合机**
- **ispyocto**：`ispyocto.core` 的 `../../../external/` 相对路径在非 bazel 环境需 `coralnpu/external/ispyocto` 符号链接
- **综合结果**：xcvu13p-fhga2104-2-e，0 errors，耗时 1h25m39s，资源基线见 `synth-notes.md`

## T010 实测补充（2026-08-18，目标器件 bitstream 生成）

### 任务分解（机器201 vs 机器202）

| 环节 | 执行机 | 内容 |
| --- | --- | --- |
| RTL 生成 | 机器201 | bazel 生成 `CoreMiniAxi.sv`（缓存热，秒级） |
| 适配设计 | 机器201 | AXI 桥接顶层 5 个 SV（top_coralnpu/uart_rx/uart_tx/host_cmd_fsm/m_axi_stub）+ XDC + tcl + `tb_top.sv`（主仓库 `synth/`） |
| RTL 功能验证 | 机器201 | **xsim**（xelab 编译 + xsim 仿真，多轮迭代，最后一轮 17:42 `ALL CHECKS PASSED`） |
| 工程生成/推送 | 机器201 | Vivado 工程（tcl）+ `sync.sh push` 机器202 |
| 综合/实现/bitstream | 机器202 | `vivado -mode batch`：synth → place → route → write_bitstream |

### 各部分时间统计（2026-08-18，实测）

> 说明：流程为「设计→xsim 验证→修改→推送→机器202 build→发现问题→回改」迭代循环，**纯环节耗时无法精确分离**；以下为时间跨度（文件 mtime 界定）与可精确确认点。

| 环节 | 耗时 | 依据 |
| --- | --- | --- |
| RTL 生成（bazel 产 CoreMiniAxi.sv） | **≈0 新增** | 复用 T008 已推送产物（`rtl_out/core_mini_axi`），T010 内无独立 bazel 时间块 |
| 适配设计（5 SV + XDC） | 跨度 **14:19→17:41 ≈ 3h22m**（含迭代与穿插验证） | uart_tx 14:19 → uart_rx 15:10 → top_coralnpu 17:02 → host_cmd_fsm 17:41 |
| 功能验证（xsim） | 最后阶段 **17:04→17:42 ≈ 38min**；多轮穿插累计约 1h 内 | tb_top.sv 17:04、xsim 17:42:15 退出（`.tao/logs/T010-sim-tb_top.log`） |
| 工程生成（tcl） | 跨度 **≈15:10→16:34 ≈ 1h24m**（含迭代） | build_top.tcl/resume_top.tcl mtime 16:34；build1（16:03）前需初版 |
| 机器202构建 build1 | 16:03–16:39 ≈36min | 首版 50MHz 时序违例（WNS -0.148ns/5 端点 + WHS -0.236ns/41 端点） |
| 机器202构建 build2 | 17:12–17:42 ≈30min | 降频 40MHz 迭代（期间机器201仍改 top_coralnpu/host_cmd_fsm） |
| 机器202构建 build3（最终成功） | 17:49–18:21 ≈32min | synth 12:54 + place/route + write_bitstream 1:31 |
| 机器202三次构建累计 | ≈2h18m | 含失败迭代与重试 |

> 注：`.tao/logs/T010-sim-tb_top.log` mtime 为 18:17（engineer 收尾重定向），内部 `Exiting xsim at 17:42:15` 为真实仿真结束点。

### 资源使用情况（实测）

- **机器202 synth_design（build3）**：峰值内存 PSS **10858MB**（VSS 19606MB），free physical 53659MB → 机器202 62GiB 余量充足
- **机器202 write_bitstream**：峰值 6992MB
- **机器201 xsim**：编译 `CoreMiniAxi.sv`（39835 行 firtool 产物）+ 顶层 + tb，VSS 虚拟内存峰值可达十几 GB；机器201 11G（可用 6.5G）跑通**无 OOM**（VSS 高、PSS 常驻可控）
- **设计规模**：Slice LUT 43,439（3.56%）、RAMB36 10、DSP48E1 6、IOB 8、MMCM 1

### 职责划分（2026-08-20 调整，用户决策）

- **当前**：RTL 生成（bazel）+ 仓库维护 + opencode + **板卡烧录** = **201**；**所有 Vivado 任务（xsim 仿真 + 综合/实现/bitstream）** = **202**
- **2026-08-20 变化**：① **xsim 仿真从 201 迁入 202**（原"xsim 归属机器201"的 ③"机器201无 OOM"不再成立——用户决策以 202 为 Vivado 专属机，201 受内存限制）；② 201 除烧录 bit/板卡连接外**非特殊情况不调用 Vivado**（特殊情况需咨询用户确认）
- **202 工作规范**：git 局域网同步 + 任务子目录 + .xpr 工程 + sudo 需用户允许（见上文「202 工作规范」）

### 各环节可迁移性分析（2026-08-18 评估，2026-08-20 落实）

| 环节 | 归属 | 依据 |
| --- | --- | --- |
| RTL 生成（bazel→SV） | 201（不可迁 202） | 依赖 bazel+Chisel/firtool+依赖缓存；202 无 bazel（2026-08-20 起外网已通，可装 bazelisk，但 RTL 生成职责仍归 201） |
| 适配设计（写 RTL/XDC） | 201 | 交互式开发；elab/lint 检查可放 202 分担 |
| 功能验证（xsim） | **202（已落实迁移）** | 202 Vivado + 62GiB；201 内存受限不跑 Vivado |
| 工程生成（tcl/.xpr） | 202 | Vivado 执行在 202；**按任务建 .xpr 工程** |

**趋势**：新增 IP → 仿真/综合内存需求↑ → 202（62GiB）独占 Vivado 职责，201 专注仓库/维护/烧录。
