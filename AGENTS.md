# fpga 仓库工作规范（项目级 AGENTS.md）

本仓库承载 coralnpu（Google 开源 NPU/RISC-V 核）在 S2C DualV7 板卡上的上板验证与 FPGA/EDA 流程工作。机器分工：**201** = 仓库维护/git/上板烧录；**202**（ssh gxt@192.168.200.202）= Vivado 综合/仿真宿主。

本文件与全局规范（`~/.config/opencode/AGENTS.md`）共同生效，冲突时以**本文件（更具体）**为准。

## 一、核心工作方式（强制）

### 1. bazel / vivado 命令由用户单独执行

- **所有 bazel（构建、生成 SV）与 vivado（综合、仿真、烧录）相关命令，由用户在 terminal 单独执行**
- **脚本文件规范**：我在执行地机器的 `workspace/<task>-<subtask>/` 目录下生成脚本文件 **`working.sh`**，log 统一为 **`working.log`**（重定向在脚本内完成）
- 用户执行：`bash ~/fpga/workspace/<task>-<subtask>/working.sh`（201 与 202 各自在对应机器的 `~/fpga/workspace/<task>-<subtask>/` 下运行）
- **生成 working.sh 时必须展示其内容**给用户（用户可确认命令无误）
- **working.sh 不依赖运行时路径**：一律用绝对路径（`~/fpga/...`），不依赖执行时的 cwd
- 执行完成后**用户通知我**，我读取 `working.log` 做分析
- 我的职责：
  1. 生成 `working.sh`（含要执行的命令 + log 重定向 + 预期产出注释，清晰、单条可读）
  2. 用户执行后，读取 `working.log` 分析/诊断
  3. 给出下一步建议
- **禁止**自行 ssh 到 202 直接执行 bazel/vivado 命令

### 2. 202 workspace 目录规范

- 工作目录：`~/fpga/workspace/<task>-<subtask>/`
- **首次 subtask 用 `first`**（如 `workspace/T018-first/`）
- 每次任务的每次调整 = 独立子目录（`<task>-<subtask>` 每次不一样）
- **Vivado 必须在 `workspace/<task>-<subtask>/` 目录内运行**（先 `cd` 进去，杜绝在仓库根目录产生杂散文件）
- 禁止在 `~/fpga` 根目录、仓库根目录运行 vivado/bazel 留下 log

### 3. Vivado 生成物：保留 vs 清理

| 保留 | 清理 |
| --- | --- |
| `*.bit`/`*.bin`（比特流） | `vivado_*.backup.log`/`.jou` |
| `post_route.dcp` / `post_synth.dcp` | `vivado.log`/`vivado.jou`（已被任务 build.log 重定向） |
| `*.rpt`（utilization/timing/drc/clock 报告） | `.cache/` `.hw/` `.ip_user_files/` `.Xil/` |
| `build.log`（构建日志） | `clockInfo.txt` `tight_setup_hold_pins.txt` |
| `.xpr`（proj 工程，可选） | `xsim.dir/` `*.pb` |

## 二、EDA 阶段序号（E0-E8）

| 序号 | 阶段 | 内容 | 产出 |
| --- | --- | --- | --- |
| E0 | 环境 | 工具链/clang/bazel/Vivado 检查 | 环境就绪 |
| E1 | 构建 | bazel 生成 SV / 编译 ELF | `.sv`、`.elf` |
| E2 | 仿真 | xsim/cocotb 功能验证 | HALTED / ALL PASS |
| E3 | 综合 | synth_design | post_synth.dcp |
| E4 | 实现 | place + route | post_route.dcp |
| E5 | 签核 | 时序 WNS/WHS + DRC | timing 报告 |
| E6 | 比特流 | write_bitstream | `.bit`/`.bin` |
| E7 | 烧录 | 上板配置 | 板卡运行 |
| E8 | 上板验证 | UART 加载/回读 | 结果 PASS |

序号可融入目录命名（如 `workspace/T018-E3-first/`），实践过程中可调整。

## 三、执行纪律

1. **长任务/硬件操作**（综合 >30min、烧录、复位、上电断电）：执行前提醒 + 预计耗时 + **等用户确认**
2. **命令不存在**：告知用户该命令缺失、为什么需要、如何处理；**禁止自行换等价命令**
3. **结论分级**：说"事实"必须有日志/回读证据；说"推断"要明确标注——不得过早定案
4. **一次只做一件事**：改动最小化，不"顺手优化"周围代码
5. **每一步要可见**：动手前给流程图（做什么/多久/为什么），过程中主动汇报，不黑盒

## 四、目录结构

```
fpga/
├── coralnpu/   # submodule（当前 = 上游 2290a286c，清除了 fork 改动）
├── docs/       # DualV7 板卡资料（权威）、reproduce-guide
├── tests/      # 测试程序（t007_*.c/ld/build/run）+ 上板脚本（通用去前缀、诊断保留前缀）
├── synth/      # 综合工程：rtl/ xdc/ tb/ tcl/ out/
├── scripts/    # 通用工具：sync.sh、run202*.sh 等
└── .tao/       # 知识库 + 任务（M1 归档、M2）
```

**202 侧 `~/fpga/`**：`coralnpu/`（源码）、`synth/`（镜像）、`workspace/`（全部工作产物）：
```
workspace/
├── rtl_out/<key>/     # 共享 RTL 输入库（sync.sh push rtl，只读）
└── <task>-<subtask>/  # 任务工作目录（Vivado 工程/日志/bit，首次 first）
```

## 五、201 ↔ 202 同步时机

1. **git 仓库**：master 仅 201 提交。**201 每次提交后主动同步 202**（`git pull`），202 开始任务前确认已最新
2. **RTL 产物**：核 SV 有更新时 `sync.sh push rtl <key>`（覆盖同名文件）
3. **synth 目录**：rtl/xdc/tb/tcl 有更新时 `sync.sh push synth`
4. **workspace working.sh**：agent 生成的脚本/任务目录需 rsync/scp 到执行地机器（workspace 是本地目录，不走 git）

（目录重组过程中此结构会随改动更新）