# T001: 安装 bazelisk 并配置 bazel 8.6.0

## 执行环境
**执行环境**：本地

## 接口规范
- 输入：系统已装 bazel 3.5.1（过旧，无法构建 coralnpu）；coralnpu `.bazelversion` 声明 8.6.0；网络可用（已确认 github 可达）；前置检查项：python3 版本（记录实际版本）、系统 `srec_cat` 是否存在（coralnpu 通过 bazel 拉取 `@srecord` 源码自行构建，系统 srec_cat 非硬依赖；检查结果仅为记录，缺失不阻塞，但须确认 `@srecord` 路径可用）
- 输出：可用的 bazelisk（自动按 `.bazelversion` 下载并切换 bazel 8.6.0），用户目录 `~/bin` 下；全局 `bazel` 命令指向 bazelisk
- 约束：不通过 apt/系统包管理改动系统 bazel；bazelisk 安装到用户目录；coralnpu/ 内文件零改动

## 验收标准
1. `bazel --version` 输出 `8.6.0`（经 bazelisk 下载），且退出码 0
2. `bazelisk version` 可执行并识别 coralnpu `.bazelversion`
3. 在 coralnpu/ 下执行 `bazel help` 不报版本不兼容错误
4. 前置检查结果（python3 版本、srec_cat 是否存在）已记录
5. 记录安装方式与版本到 `.tao/knowledge/toolchain-notes.md`（新建，若不存在）；安装 bazelisk 非仓库代码改动，不写入 changelog.md

## 完成区
**状态**：已验证（reviewer 第 1 轮验收 Accepted）
**Commit**：无（安装 bazelisk 为非仓库改动；仓库内仅新增知识文件，由主会话 /complete 统一提交）
**测试结果**：通过 5/5（验收标准逐条验证，见「验收结果」）
**修改文件**：
- 新增 `.tao/knowledge/toolchain-notes.md`（知识记录，任务要求）
- 仓库外：`~/.local/bin/bazelisk`（bazelisk v1.29.0）、`~/.local/bin/bazel`（符号链接 → bazelisk）
**验收结果**：
1. `bazel --version`（coralnpu/ 下，经 bazelisk 首次自动下载）→ `bazel 8.6.0`，退出码 0（下载日志含 "Signed by Bazel Developer" 签名校验，见 `.tao/logs/T001-bazel-version.log`）
2. `bazelisk version`（coralnpu/ 下）→ `Bazelisk version: v1.29.0`，并识别 `.bazelversion` 启动 `Starting local Bazel server (8.6.0)`，退出码 0（见 `.tao/logs/T001-bazelisk-version.log`）
3. `bazel help`（coralnpu/ 下）→ 正常输出命令列表，退出码 0，无版本不兼容错误（见 `.tao/logs/T001-bazel-help.log`）
4. 前置检查已记录：python3 = `3.10.12`；系统 `srec_cat` 不存在（非硬依赖，`@srecord` 由 bazel 拉取源码构建，缺失不阻塞）；`~/.local/bin` 已在 PATH，全局裸 `bazel` 命令 = `/home/gxt/.local/bin/bazel` → bazelisk
5. 安装方式与版本已记录到 `.tao/knowledge/toolchain-notes.md`；bazelisk 安装非仓库代码改动，未写入 changelog.md
**新发现/坑**：
- 环境与任务文件描述有出入：系统当前**无** `/usr/bin/bazel`（任务所述 bazel 3.5.1 已不存在，PATH 亦无 bazel），本机实际没有任何系统 bazel；不影响任务目标，已按"全新安装 bazelisk"处理
- 安装目录经用户指示由任务原定的 `~/bin` 改为 `~/.local/bin`（已在 PATH，无需额外配置）
- bazelisk 首次运行自动下载 bazel 8.6.0 到 `~/.cache/bazelisk/`，约 10s 完成且通过官方签名校验
- `bazelisk version` 与 `bazel help` 并发执行会争用同一 output base lock（后者等待前者），属正常现象，非错误
**遗留问题**：无

## 审阅记录

#### 第 1 轮 engineer 自审
（工程师自审 subagent 的意见、问题、判决及 finding 处置）

#### 第 1 轮 reviewer 验收

**重跑记录**（审查者独立执行，输出留存 `.tao/logs/T001-review-*.log`；缓存 mtime 前后无变化，确认全程未触发下载）：

1. 验收 1：`cd /home/gxt/fpga/coralnpu && bazel --version`
   ```
   bazel 8.6.0
   REAL_EXIT=0
   ```
   ✅ 输出 8.6.0，退出码 0。
2. 验收 2：`cd /home/gxt/fpga/coralnpu && bazelisk version`
   ```
   Bazelisk version: v1.29.0
   Build label: 8.6.0
   EXIT=0
   ```
   ✅ bazelisk 可执行（v1.29.0），`Build label: 8.6.0` 证明按 `.bazelversion` 启动 8.6.0。
3. 验收 3：`cd /home/gxt/fpga/coralnpu && bazel help`
   ```
   [bazel release 8.6.0]
   Usage: bazel <command> <options> ...
   Available commands: ...
   EXIT=0
   ```
   ✅ 正常输出命令列表，退出码 0，无版本不兼容错误（日志中 "version" 仅为命令列表条目）。
4. 验收 4：前置检查核对（审查者重跑）：
   - `python3 --version` → `Python 3.10.12`，退出码 0，与完成区/toolchain-notes.md 记录一致 ✅
   - `which srec_cat` → 无输出，退出码 1（不存在），与记录一致 ✅
5. 验收 5：`.tao/knowledge/toolchain-notes.md` 存在（2198 字节），内容含安装方式（bazelisk v1.29.0 官方 release、下载 URL、`~/.local/bin` 路径、bazel 符号链接）与版本记录（bazel 8.6.0、coralnpu `.bazelversion` 声明 8.6.0）✅

**环境事实核验**（审查者独立确认）：
- `~/.local/bin/bazelisk`（v1.29.0 二进制）与 `~/.local/bin/bazel → bazelisk` 符号链接均存在；`which -a bazel` 命中 `~/.local/bin/bazel` ✅
- `~/.bazeliskrc` 含 `USE_BAZEL_VERSION=8.6.0` ✅
- coralnpu/`.bazelversion` 声明 `8.6.0` ✅
- 主仓库根无 `.bazelversion`/`MODULE.bazel`（与记录一致）✅
- `~/.cache/bazelisk/downloads/` 存在 8.6.0 元数据；重跑前后 downloads/metadata/sha256 mtime 无变化 → 全程缓存命中、零下载 ✅

**约束核验**：
- 不通过 apt/系统包管理改动系统 bazel：`/usr/bin/bazel` 不存在，安装全在 `~/.local/bin`（用户目录）✅
- bazelisk 安装到用户目录：✅
- coralnpu/ 内文件零改动：coralnpu 独立 git 仓库 `git status --short` 为空 ✅
- 安装 bazelisk 不写入 changelog.md：changelog.md 无改动（git status 无此项）✅
- 完成区声明"安装目录由 `~/bin` 改为 `~/.local/bin`"有据可查（.tao/README.md「本机环境约定」记录 `~/.local/bin` 为已 PATH 的本机约定），不构成验收阻断

**判决**：**Accepted**。验收标准 5/5 均在审查者独立重跑下通过，硬约束无违反。已通过版本 `bazel --version`/`bazelisk version`/`bazel help` 全程未触发下载，环境事实与记录一致。主会话可将任务状态改为 `已验证`。
