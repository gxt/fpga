# 机器路由表

远端任务路由表，dispatch/complete 据此同步/拉取任务文件。无远端任务时留空即可：

| 执行环境 | 传输命令（push 任务文件到远端） | 远端执行方 |
| --- | --- | --- |
| `远端综合 · zzx-NF5280` | `scp <file> gxt@192.168.200.202:~/<repo>/.tao/tasks/` | 远端智能体（Vivado 综合） |

- 传输命令**以本表为准**（可能是 scp / scp -P / rsync），不要假设一律 rsync
- pull（远端拉回本地）由 push 命令反推：`scp [-P port] user@host:remote_path/<file> <local_file>`
- 主机地址只写在本表，不写进命令/角色文件

## 综合服务器资源（zzx-NF5280 · 192.168.200.202）

- 连接：`ssh gxt@192.168.200.202`（密钥认证，免密）
- Vivado：v2025.1（Build 6140274），`/tools/Xilinx/2025.1/Vivado/bin/vivado`，与本地一致
- 资源：16 核 / 62 GiB 内存；`/` 空闲 691G、`/home` 空闲 319G
- 用途：Phase3 综合执行机（T008+）

