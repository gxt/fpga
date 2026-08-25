# M1 审核矩阵（coralnpu 覆盖为上游 2290a286c 后）

日期：2026-08-25
背景：coralnpu submodule 已覆盖为上游 2290a286c（清除 fork 改动：clang-14 wrapper、CoreAxi tcmPortCount 拆分）。
上游 8/14 后引入大量改动（RV64 参数化、RetirementBuffer/MPACT/RVV 修复、clang-19 lint 等），
核 RTL 与 M1 基线（8225240f）不同。本矩阵判定 M1 各任务产物在覆盖后的状态。

判定：
- **保留** = 不依赖核 RTL / 独立产物，直接复用
- **适配** = 产物保留但需更新路径/构建链/重编译验证
- **重做** = 依赖核 RTL，覆盖后需重新生成/综合/上板

| 任务 | 内容 | 判定 | 说明 |
| --- | --- | --- | --- |
| T001 | bazelisk + bazel 8.6.0 配置 | 适配 | 验证 bazel 兼容上游 2290a286c；**clang-18 主机构建需实测**（wrapper 已恢复 exec clang） |
| T002 | Cocotb 快速开始 | 重做 | 依赖核 RTL，新核重新 cocotb |
| T003 | Verilator C++ sim hello world | 重做 | 依赖核 RTL，新核重编译 sim |
| T004 | 架构文档研读 | 保留 | 架构理解仍有效；RVV/ROB 部分需按新核更新 |
| T005 | 构建链路梳理（build-map） | 适配 | 上游 BUILD 目标可能变，需更新映射 |
| T006 | Cocotb 测试套件核心子集 | 重做 | 依赖核 RTL |
| T007 | 自定义测试程序（tests/） | 适配 | 程序源码保留（ISA 语义独立）；工具链版本可能变，重编译验证 |
| T008 | 远程综合工作流（sync/run202） | 适配 | 已更新 workspace/ 路径；待验证 |
| T009 | fusesoc 生成 Vivado 工程 + 综合 | 重做 | 依赖核 RTL 综合 |
| T010 | 目标器件适配 + bit 生成 | 重做 | top/xdc 保留，但核端口可能变；重新综合 |
| T011 | 资源时序报告分析 | 保留 | 分析方法保留；数据待重新综合后更新 |
| T012 | 板卡加载 bit + 连通性 | 重做 | 需新 bit |
| T013 | NPU core AXI 桥接上板 | 重做 | 桥接 RTL 对接核端口，需适配/重做 |
| T014 | 全流程回归收尾 | 适配 | 流程本身保留，随新流程重跑 |
| T015 | UART host 通路 + 程序加载 | 适配 | UART 协议独立（上板脚本保留）；host_cmd_fsm 对接核需验证 |
| T016 | Debug 命令读写 TCM | 适配 | tb 保留（tests 已迁移）；对新核验证 |

## 关键结论

1. **环境类（E0）**：T001 需先验证——bazel 兼容 + **clang-18 构建实测**（覆盖后 wrapper 用系统 clang，24.04 的 clang-18 modules 兼容性是首个待验证点）
2. **重做面**：T002/T003/T006（仿真）+ T009/T010/T012/T013（综合上板）——全部依赖核 RTL，共 7 个任务需重做，是新 M2 的主要工作量
3. **保留面**：T004/T011（知识）+ T007/T015/T016 的独立产物（测试源码/UART 脚本/tb）——已迁至 tests/、synth/tb/
4. **适配面**：T005/T008/T014（工具/流程）+ T001（环境）
