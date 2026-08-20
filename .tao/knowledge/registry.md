# 机器路由表

远端任务路由表，dispatch/complete 据此同步/拉取任务文件。无远端任务时留空即可：

| 执行环境 | 传输命令（push 任务文件到远端） | 远端执行方 |
| --- | --- | --- |
| `远端 Vivado · zzx-NF5280 (202)` | **git 局域网同步为主**（202 从 201 `git pull`；**fpga 主仓库仅限 201 局域网 push/pull**，coralnpu submodule 及其他软件走外网）；`synth/sync.sh`（rsync）辅助推产物 | 本机 ssh 直连执行（路径 A，无远端 opencode；拓扑见 `synth-server.md`） |

- 传输命令**以本表为准**（git 局域网同步 / scp / rsync），不要假设一律 rsync
- pull（远端拉回本地）由 push 命令反推：`scp [-P port] user@host:remote_path/<file> <local_file>`
- 主机地址只写在本表，不写进命令/角色文件

## 机器职责分工（2026-08-20 调整）

### 201（192.168.200.201 · fpga201，本机）

- **职责**：fpga 仓库维护、opencode 运行、**板卡烧录与连接**（Vivado Hardware Manager、JTAG）
- **Vivado 约束（内存受限）**：除烧录 bit/板卡连接等任务外，**非特殊情况不调用 Vivado**；特殊情况需先咨询用户确认

### 202（192.168.200.202 · zzx-NF5280，Vivado 机）

- **职责**：**所有 Vivado 任务**——仿真（xsim）、综合、实现、bitstream 生成
- **202 fpga 目录**：与 201 git 仓库一致并同步（局域网 git：202 从 201 pull）；按任务建子目录，**尽可能创建 Vivado 工程（.xpr）**
- **sudo 约束**：202 上所有 `sudo` 命令必须经过用户允许
- 资源：16 核（Xeon E5620）/ 62 GiB 内存；`/` 空闲 691G、`/home` 空闲 319G

## 综合服务器资源（zzx-NF5280 · 192.168.200.202）

- 连接：`ssh gxt@192.168.200.202`（密钥认证，免密）
- Vivado：v2025.1（Build 6140274），`/tools/Xilinx/2025.1/Vivado/bin/vivado`，与本地一致
- 工具：git 2.43.0、rsync 3.2.7、scp、Python 3.12.3；**无 bazel/bazelisk/fusesoc**（2026-08-18 实测）
- 用途：Vivado 仿真 + 综合执行机（T008+，2026-08-20 起含 xsim 仿真）

### 文件交换方式（2026-08-20 更新：git 同步为主；2026-08-20 外网已通）

- **网络现状（2026-08-20 澄清）**：202 **外网已连通**（github/pypi 实测可达）；但 **fpga 主仓库 git 同步只允许经 201**（201↔202 局域网），**coralnpu submodule 及其他软件/依赖可直接外网获取**
- **主路径（git）**：fpga 主仓库 202 从 201 `git pull`（局域网）；coralnpu submodule 走外网（github gxt/coralnpu，与 .gitmodules 一致）
- **辅助**：`synth/sync.sh`（rsync 增量）推大产物（RTL 生成物、网表、报告）
- 远端工作根：`~/fpga/`（git 仓库）；任务子目录与 Vivado 工程规范见 `synth-server.md` §202 工作规范
- 交换不写密码/密钥，依赖密钥免密（BatchMode）

