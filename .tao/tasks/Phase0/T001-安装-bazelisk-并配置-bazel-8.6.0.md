# T001: 安装 bazelisk 并配置 bazel 8.6.0

## 执行环境
**执行环境**：本地

## 接口规范
- 输入：系统已装 bazel 3.5.1（过旧，无法构建 coralnpu）；coralnpu `.bazelversion` 声明 8.6.0；网络可用（已确认 github 可达）
- 输出：可用的 bazelisk（自动按 `.bazelversion` 下载并切换 bazel 8.6.0），用户目录 `~/bin` 下；全局 `bazel` 命令指向 bazelisk
- 约束：不通过 apt/系统包管理改动系统 bazel；bazelisk 安装到用户目录；coralnpu/ 内文件零改动

## 验收标准
1. `bazel --version` 输出 `8.6.0`（经 bazelisk 下载），且退出码 0
2. `bazelisk version` 可执行并识别 coralnpu `.bazelversion`
3. 在 coralnpu/ 下执行 `bazel help` 不报版本不兼容错误
4. 记录安装方式与版本到 `.tao/knowledge/changelog.md` 或工具链笔记（选择一项，见任务完成区）

## 完成区
**状态**：待开始
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：

## 审阅记录

#### 第 1 轮 engineer 自审
（工程师自审 subagent 的意见、问题、判决及 finding 处置）

#### 第 1 轮 reviewer 验收
（审查者独立验证的重跑记录、约束核验、判决；Needs Revision 返工后，下一轮标 `第 2 轮`）
