# T019: DDR3 集成验证

## 执行环境
**执行环境**：机器202（综合）＋ 机器201（上板烧录 + DDR 测试）

## 接口规范
- **输入**：
  1. T018 验证的 TL-UL crossbar SoC（含 core + crossbar + sram 256KB）
  2. DDR3 控制器：`ddr_ctrl`（TLUL→AXI 桥）+ `ddr_mem`（AXI→MIG）
  3. MIG 配置：`docs/DualV7/06-知识库/03-board-dualv7.md` §03.7 已验证的 `dualv7mig.prj`（MT41K256M16XX-125，64-bit，400MHz/800MT/s）
  4. 测试程序：写 DDR（0x80000000）然后回读验证的简单程序
- **输出**：
  1. 含 DDR3 的完整 SoC SV（`CoralNPUChiselSubsystem.sv`）
  2. MIG IP 核（由 Vivado 生成）
  3. 综合报告（资源/时序，重点关注 MIG 相关约束）
  4. 上板测试结果：DDR 读写成功
- **约束**：
  1. **最小改动**：仅添加 `ddr_ctrl`、`ddr_mem` 模块到 crossbar，修改 `CrossbarConfig` 地址映射
  2. **MIG 配置**：使用已验证的 `dualv7mig.prj`，注意 TargetFPGA 格式（ISE 格式：`xc7v2000t-flg1925/-1`）
  3. **时钟域**：DDR 域需单独时钟（MIG 参考时钟 200MHz，由 clk_wiz 提供）
  4. **CLOCK_DEDICATED_ROUTE**：需在 post_opt.tcl 中设置（见 §03.7.5）
  5. **XADC 冲突**：MIG PRJ 中 XADC_En 需改为 Disabled（避免与 IO 层级 XADC wizard 冲突）
  6. **产物目录规范**：`synth/out/T019-ddr3/`（201）与 `~/fpga/work/T019-ddr3/`（202）

## 验收标准
1. **bazel 生成 SV 成功**：添加 DDR 模块后生成 SV 无错误
2. **MIG IP 生成成功**：Vivado 生成 MIG IP 核，无错误
3. **综合 0 ERROR**：综合+实现+bitstream 完成，无 ERROR（MIG 相关 CRITICAL WARNING 可接受）
4. **时序收敛**：WNS ≥ 0（100MHz 目标），特别关注 MIG UI 时钟（100MHz）与系统时钟同步
5. **资源报告**：记录 LUT/FF/BRAM 使用量，对比 T018 增量（MIG 资源开销）
6. **上板测试通过**：
   - UART 通路正常
   - 加载 DDR 测试程序（写 0x80000000 某个地址，然后回读比较）
   - 程序运行成功，回读数据一致
7. **DDR 稳定性**：多次读写无错误，无总线挂死

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