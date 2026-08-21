# MEMORY

项目状态/进展摘要。任务完成后由主会话通过 `/complete` 更新。

## 当前进展（2026-08-21 现场快照）

- **阶段**：Phase4 板级 · **T012/T015/T016/T013/T014 全部已验证**（含 reviewer 审核），Phase4 完成
- **里程碑**：T007 标量+浮点程序在 S2C 板**上板运行 ALL PASS**（out_mul={700,1600,2700,4000}、fout={2.0,3.0,5.0,7.0}），模拟→综合→上板闭环打通；Debug 写 TCM（T016）上板 ALL PASS
- **T015 根因定案**：此前"host 写 ITCM 卡/无响应/SLVERR"全部源于 **uart_rx 亚稳态**（rx_in 无同步器，长命令偶发 RX 错），与 AXI/仲裁/直写无关；修复 = uart_rx 加 2 级同步器 + DIV 四舍五入 + phys_opt -hold_fix → W/DTCM/ITCM 全 16/16 稳定
- **方案 A 清理完成**：验证 AXI 写 ITCM 正常后移除 host_tcm 直写端口（coralnpu fork `8225240f`，ITCM/DTCM arbiter 3 端口），回到上游干净
- **当前 bit**：`synth/out/T010-clean/top_coralnpu.bit`（md5 9b2d8d0e...，WNS+0.950/hold 0/0 ERROR，proj 工程含 .xpr）；中间版本已归档 `out/_archive/`
- **reviewer 审核**：T015 Accepted、T013 Accepted、T016 Needs Revision→返工（202 仿真脚本 tb 文件名修正）→Accepted；审阅记录已写入任务文件
- **目录整理**（023c6bf）：`scripts/`（run202*.sh + 综合/烧录 tcl + t016_xsim*.sh）、sim/ 与 synth/sim 加任务前缀、build_top.tcl 产物精简、out/ 归档 `_archive/`
- **目录约定**（38a1c19）：**禁 ~/ 作临时目录**（用 /tmp/$USER/ 或仓库内目录，不清楚咨询用户）；202 家目录临时残留已清理
- **下一步**：Phase4 已完成；后续可选：完整 SoC 规划/试点（soc-analysis.md）、RVV 上板（需 RVV 版核）、LED 验证
- **环境**：bazel `CC=clang-14`；串口 `ttyUSB0` 需 `sg dialout`；202 所有 Vivado 任务；综合用 `scripts/run202.sh`（nohup 不等待）+ `scripts/run202_check.sh`（非阻塞查询）
- **详细调试**：`.tao/knowledge/board-debug-log.md`（根因证据链 + 修复链 + T007/T016 上板记录）

**机器分工**：机器201 = 仓库维护/opencode/板卡烧录；机器202 = 所有 Vivado 任务（xsim/综合/bitstream），git 局域网同步，sudo 需用户允许。
**Phase4 任务链**：T012/T015/T016/T013/T014 ✅ 全部已验证，Phase4 完成。
**上板纪律**：复位必先提醒+等确认；脚本 201 编写→git→202 执行；SRAM 复位不清；禁 ~/ 临时目录。

| 日期 | 项目/模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 2026-08-16 | Phase0 · T001 安装 bazelisk + bazel 8.6.0 | 已验证 | reviewer Accepted；产出 toolchain-notes.md；零代码改动 |
| 2026-08-17 | Phase0 · T002 跑通官方 Cocotb 快速开始 | 已验证 | 双模型交叉验收；方案 B csr_test PASSED；零代码改动 |
| 2026-08-17 | Phase0 · T003 跑通官方 Verilator C++ sim | 已验证 | 双模型交叉验收；hello_world ELF + sim 运行 exit 0；零代码改动 |
| 2026-08-17 | Phase1 · T004 架构文档研读与知识沉淀 | 已验证 | 双模型交叉验收；产出 coralnpu-architecture.md；零代码改动 |
| 2026-08-17 | Phase1 · T005 构建链路与验证体系梳理 | 已验证 | 双模型交叉验收；产出 coralnpu-build-map.md；零代码改动 |
| 2026-08-18 | Phase2 · T006 Cocotb 测试套件核心子集 | 已验证 | 三轮 reviewer 验收 + Mimo 复核；37/37 通过，产出 cocotb-test-matrix.md；零代码改动 |
| 2026-08-18 | Phase2 · T007 编写自定义测试程序 | 已验证 | 双模型交叉验收（含代码 review）；sim/ 新增 7 文件；见 changelog |
| 2026-08-18 | Phase3 · T008 机器202工作流搭建 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；synth/ 工作流脚本 + 拓扑三要素；见 changelog |
| 2026-08-18 | Phase3 · T009 fusesoc 生成 Vivado 工程并跑通官方器件综合 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；官方基线综合成功，产出 synth-notes.md；零代码改动 |
| 2026-08-18 | Phase3 · T010 目标器件适配与 bitstream 生成 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；上板 bitstream 产出（.bit/.bin）；synth/rtl/xdc/tcl/sim 新增；见 changelog |
| 2026-08-18 | Phase3 · T011 资源时序报告分析与知识沉淀 | 已验证 | 两轮 reviewer 验收 + Mimo 复核；资源构成/对比表/时序分析沉淀 synth-notes.md；零代码改动 |
| 2026-08-20 | Phase4 · T012 板卡加载 bitstream 与连通性验证 | 已验证 | reviewer Accepted + Mimo；DONE HIGH + IDCODE + LED1 点亮 |
| 2026-08-21 | Phase4 · T015 UART host 通路与程序加载 | 已验证 | reviewer Accepted；根因=uart_rx 亚稳态（同步器修复）；T007 上板 ALL PASS |
| 2026-08-21 | Phase4 · T016 Debug 抽象命令读写 TCM | 已验证 | reviewer Accepted（返工后）；阶段A xsim + 阶段B 上板 ALL PASS |
| 2026-08-21 | Phase4 · T013 NPU core AXI 桥接上板验证 | 已验证 | reviewer Accepted；T007 上板 + ADR-004 差异说明 |
| 2026-08-21 | Phase4 · T014 全流程回归与文档收尾 | ✅ 已验证 | reviewer Accepted（返工后）；README/复现指南/排除项清单；Phase4 完成 |
