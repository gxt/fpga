# T006: 跑通 Cocotb 测试套件核心子集

## 执行环境
**执行环境**：本地

## 接口规范
- 输入：T002 已验证的 bazel/cocotb 环境；coralnpu `tests/cocotb/BUILD` 中定义的测试 target 清单
- 输出：核心子集测试的运行记录与结果矩阵（`.tao/knowledge/cocotb-test-matrix.md`），子集全绿
- 约束：不新增测试代码（新增属 T007）；子集选择须有理由（优先标定 2 分钟级以内、不依赖 VCS 的 target）；内存 11G，避免并行跑 large 测试导致 OOM

## 验收标准
1. 从 `bazel query //tests/cocotb:all` 列出全部可运行测试，依据执行时长与依赖筛选出核心子集（建议覆盖：nop/align 等基础、scalar 算术、至少一个 rvv 相关、一个中断/异常相关）
2. 子集内每个测试 `bazel test //tests/cocotb:<target>` 退出码 0
3. 结果矩阵记录：target、测试内容、运行时长、结果（通过/跳过及原因）、对应 RTL 配置
4. 说明哪些 target 被排除及其原因（如依赖 VCS、耗时过长、已知失败并附上游 issue 证据）

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
