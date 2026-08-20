# §01 项目结构

## §01.1 仓库导航

| 路径 | 用途 |
|------|------|
| `/home/data/vivado-risc-v/` | 本地管理仓库（知识库/任务/文档） |
| `~/vivado-risc-v/`（远端 `zzx@192.168.200.202`） | FPGA 工程主仓库 |

## §01.2 本地目录结构

```
/home/data/vivado-risc-v/
├── CHATGPT.md              # AI 工作规则（每次任务前必读）
├── CLAUDE.md               # 协调者角色 + 构建命令
├── README.md               # 本地 4 类内容总览
├── code-agent/
│   ├── knowledge/          # 知识库（§xx 引用）
│   └── tasks/              # 任务文件（NNNx-描述.md）
├── doc/                    # 流程文档 / 调研报告 / 板级资料
│   ├── archive/            # 历史散落记录归档
│   ├── AI相关资料/         # datasheet / 手册 / xlsx
│   └── V7子卡原理图和PCB/  # 原理图 / PCB / pin 对照
├── tests/                  # 本地辅助脚本
│   ├── telnet_cmd.py
│   ├── telnet_cmd.sh
│   └── legacy/             # 旧脚本归档
├── workspace/
│   ├── releases/           # release 工件真实目录
│   ├── experiments/        # 单任务实验真实目录
│   ├── metadata/           # 图谱 / staging 真实目录
│   ├── toolchains/         # 大体积工具工件真实目录
│   ├── release-*           # 兼容旧路径的符号链接
│   ├── dualv7-test/        # 兼容旧路径的符号链接
│   ├── knowledge-graph/    # 兼容旧路径的符号链接
│   └── 066x/ 070x/ ...     # 兼容旧路径的符号链接
├── linux-stable/           # 本地内核源码仓
├── busybox-nfsroot-src/    # BusyBox NFS root 源仓
├── ramdisk-realcheck-src/  # 旧 REALCHECK rootfs 源仓
├── bootrom/                # bootrom 相关源码/工件
├── patches/                # U-Boot / OpenSBI / 驱动补丁源码
└── .research/              # 调研缓存（任务预取文件）
```

### 当前整理原则

1. `code-agent/` 作为项目管理区，不移动
2. `doc/ + tests/` 作为流程与脚本区
3. `workspace/` 作为测试二进制、NFS、日志区
4. 源码仓保持原路径，避免打断已有绝对路径引用

历史散落文件已归档：

- `doc/archive/`
- `tests/legacy/`

`workspace/` 已进一步分层，但保留兼容符号链接：

- 真实目录：
  - `workspace/releases/`
  - `workspace/experiments/`
  - `workspace/metadata/`
  - `workspace/toolchains/`
- 兼容路径：
  - `workspace/release-*`
  - `workspace/dualv7-test`
  - `workspace/knowledge-graph`
  - `workspace/066x` / `070x`
  - `workspace/gcc`

## §01.3 远端主工程路径

```
~/vivado-risc-v/ （zzx@192.168.200.202）
├── board/dualv7/            # DualV7 板级文件
│   ├── riscv-2025.1.tcl     # BD TCL（带备份 .bak / .009x-bak）
│   ├── mig.prj              # DDR3 MIG 配置（从 chipyard 复制）
│   ├── ddr3.xdc             # CLOCK_DEDICATED_ROUTE + DRC 降级
│   ├── top.xdc              # 时钟 + 复位约束
│   ├── sdc.xdc              # SD 卡约束（"No SD card on dualv7"）
│   ├── uart.xdc             # UART rx/tx 约束
│   ├── ethernet.xdc         # 以太网 MII 引脚约束
│   └── bootrom.dts          # 板级 DTS
├── bootrom/                 # Boot ROM 源码（所有板子共享）
├── src/main/scala/          # Rocket 配置 (rocket.scala)
├── vivado.tcl               # Vivado 工程创建 + XDC 加载（带备份 .bak）
├── Makefile                 # 顶层构建
└── workspace/rocket64b2/    # 构建产物
    ├── vivado-dualv7-riscv/
    │   └── dualv7-riscv.runs/impl_1/riscv_wrapper.bit
    └── system-dualv7/       # Chisel 生成文件
```

## §01.4 远端工程注意事项

- dirty worktree：远端 `~/vivado-risc-v/` 有未提交修改，不得 reset 或覆盖
- 备份文件：`riscv-2025.1.tcl.bak` 和 `.009x-bak` 保留原始版本
- `vivado.tcl.bak` 保留原始 XDC 加载配置
- 不得修改 `board/dualv7/` RTL/TCL/XDC（已有 008x-009x 修改记录）

## §01.5 当前本地入口建议

后续看本地目录，优先按下面顺序进入：

1. `code-agent/`
2. `doc/DualV7-FPGA本地操作流程.md`
3. `doc/DualV7-Release清单.md`
4. `workspace/release-*`
5. `linux-stable/` / `busybox-nfsroot-src/`

## §01.6 知识库引用约定

- 格式：`§文件号.小节号`（如 `§03.2`），不写行号
- 知识库文件编码：UTF-8，单行 ≤ 80 字符
- 新知识优先追加到已有主题文件末节
