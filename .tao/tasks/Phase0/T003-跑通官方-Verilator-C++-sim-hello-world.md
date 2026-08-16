# T003: 跑通官方 Verilator C++ sim（hello world add floats）

## 执行环境
**执行环境**：本地

## 接口规范
- 输入：coralnpu 源码；bazel 8.6.0（T001 完成）
- 输出：hello_world 可执行 ELF + Verilator C++ 仿真器 `core_mini_axi_sim` 构建产物，并成功运行
- 约束：不改 coralnpu/ 内文件；RISC-V 工具链已在 T002 首次构建中完成（本任务可复用缓存，若先于 T002 执行则同样耗时）

## 验收标准
1. `bazel build //examples:coralnpu_v2_hello_world_add_floats` 成功，产物 ELF 存在于 `bazel-out/.../bin/examples/`
2. `bazel build //tests/verilator_sim:core_mini_axi_sim` 成功
3. 运行：
   ```
   bazel-bin/tests/verilator_sim/core_mini_axi_sim \
     --binary bazel-bin/examples/coralnpu_v2_hello_world_add_floats.elf
   ```
   退出码 0，日志/回读输出符合 hello world 语义（如加法结果正确）
4. 记录运行方式与输出样例到 `.tao/knowledge/`（sim 运行笔记）

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
