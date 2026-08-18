# 机器路由表

远端任务路由表，dispatch/complete 据此同步/拉取任务文件。无远端任务时留空即可：

| 执行环境 | 传输命令（push 任务文件到远端） | 远端执行方 |
| --- | --- | --- |
| `远端综合 · zzx-NF5280` | `synth/sync.sh`（rsync 增量为主 + scp 单文件，远端根 `~/fpga/`；传输命令以脚本为准） | 本机 ssh 直连执行（路径 A，无远端 opencode；拓扑见 `synth-server.md`） |

- 传输命令**以本表为准**（可能是 scp / scp -P / rsync），不要假设一律 rsync
- pull（远端拉回本地）由 push 命令反推：`scp [-P port] user@host:remote_path/<file> <local_file>`
- 主机地址只写在本表，不写进命令/角色文件

## 综合服务器资源（zzx-NF5280 · 192.168.200.202）

- 连接：`ssh gxt@192.168.200.202`（密钥认证，免密）
- Vivado：v2025.1（Build 6140274），`/tools/Xilinx/2025.1/Vivado/bin/vivado`，与本地一致
- 资源：16 核（Xeon E5620）/ 62 GiB 内存；`/` 空闲 691G、`/home` 空闲 319G
- 工具：git 2.43.0、rsync 3.2.7、scp、Python 3.12.3；**无 bazel/bazelisk/fusesoc**（2026-08-18 实测）
- 用途：Phase3 综合执行机（T008+）

### 文件交换方式（T008 确认）

- **标准入口：主仓库 `synth/sync.sh`**（从本表自动解析服务器地址，提供 `info/push/pull/exec`）
- push（本机→远端）：rsync 增量（首选）`rsync -a -e "ssh -o BatchMode=yes" <local>/ gxt@192.168.200.202:~/fpga/<path>/`；单文件用 `scp <file> gxt@192.168.200.202:~/fpga/`
- pull（远端→本机）：`rsync -a -e "ssh -o BatchMode=yes" gxt@192.168.200.202:~/fpga/work/ <local>/`（默认拉回 `synth/out/`）
- 远端工作根：`~/fpga/`（布局见 `synth/README.md`：`coralnpu/`、`rtl_out/<key>/`、`work/`）
- 交换不写密码/密钥，依赖密钥免密（BatchMode）

