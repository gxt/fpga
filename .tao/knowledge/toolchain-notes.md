# 工具链笔记

## Bazel / Bazelisk

### 安装方式（2026-08-16，本机）

- **bazelisk**：`v1.29.0`（官方 release 预编译二进制）
  - 下载：`https://github.com/bazelbuild/bazelisk/releases/download/v1.29.0/bazelisk-linux-amd64`
  - 安装路径：`~/.local/bin/bazelisk`（任务原定 `~/bin`，经用户指示改为 `~/.local/bin`，已在 PATH 中）
  - `~/.local/bin/bazel` 为指向 bazelisk 的符号链接，全局 `bazel` 命令即 bazelisk
- **bazel**：`8.6.0`（由 bazelisk 按 `.bazelversion` 自动下载，缓存于 `~/.cache/bazelisk/`）
  - coralnpu `.bazelversion` 声明 `8.6.0`
- **前置检查**：python3 = `3.10.12`；系统 `srec_cat` **不存在**（coralnpu 通过 bazel 拉取 `@srecord` 源码自行构建，非硬依赖，缺失不阻塞）；系统无 `/usr/bin/bazel`（环境说明中所述 bazel 3.5.1 已不存在，本机现无系统 bazel）

### 使用方式

- 在任意含 `.bazelversion` 的目录下直接 `bazel <cmd>`，bazelisk 自动切换对应版本
- 首次运行自动下载对应 bazel，下载输出含 "Signed by Bazel Developer"（签名校验通过）

### 坑 / 经验

- `bazelisk version` 与 `bazel help` 并发执行会争用同一 output base lock，后者会等待前者，属正常现象
