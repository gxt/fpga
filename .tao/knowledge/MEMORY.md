# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-18）

- **阶段**：Phase3 综合
- **下一步**：`/dispatch T009`（fusesoc 生成 Vivado 工程并跑通官方器件综合，资源基线）
- 说明：Phase0/1/2 完成；T008 已验证（远程综合工作流：服务器纯 Vivado、本地 bazel 产物推送、sync.sh 同步）；license 已验证 xc7v2000t 与 xcvu13p 均 RECOGNIZED

| 日期 | 项目/模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 2026-08-16 | Phase0 · T001 安装 bazelisk + bazel 8.6.0 | 已验证 | reviewer Accepted；产出 toolchain-notes.md；零代码改动 |
| 2026-08-17 | Phase0 · T002 跑通官方 Cocotb 快速开始 | 已验证 | 双模型交叉验收；方案 B csr_test PASSED；零代码改动 |
| 2026-08-17 | Phase0 · T003 跑通官方 Verilator C++ sim | 已验证 | 双模型交叉验收；hello_world ELF + sim 运行 exit 0；零代码改动 |
| 2026-08-17 | Phase1 · T004 架构文档研读与知识沉淀 | 已验证 | 双模型交叉验收；产出 coralnpu-architecture.md；零代码改动 |
| 2026-08-17 | Phase1 · T005 构建链路与验证体系梳理 | 已验证 | 双模型交叉验收；产出 coralnpu-build-map.md；零代码改动 |
| 2026-08-18 | Phase2 · T006 Cocotb 测试套件核心子集 | 已验证 | 三轮 reviewer 验收 + Mimo 复核；37/37 通过，产出 cocotb-test-matrix.md；零代码改动 |
| 2026-08-18 | Phase2 · T007 编写自定义测试程序 | 已验证 | 双模型交叉验收（含代码 review）；sim/ 新增 7 文件；见 changelog |
| 2026-08-18 | Phase3 · T008 远程综合服务器工作流搭建 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；synth/ 工作流脚本 + 拓扑三要素；见 changelog |
