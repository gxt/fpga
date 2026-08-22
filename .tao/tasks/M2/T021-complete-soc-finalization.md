# T021: 完整 SoC 收尾验证

## 执行环境
**执行环境**：机器202（综合）＋ 机器201（上板烧录 + 完整 SoC 测试）

## 接口规范
- **输入**：
  1. T020 验证的 SRAM+外设 SoC（含 core + crossbar + sram 512KB-1MB + DDR3 + uart/gpio/clint/plic）
  2. 可选外设：`dma`（128→32）、`spi2tlul`（SPI 从机引导）、`spi_master`、`spi_master_flash`
  3. 裁剪：ISP 无摄像头，可仅保留 TLUL 端口留空或完全移除
  4. 完整测试集：
     - RVV 测试（92 个 TCM 可测 + matmul 7 个需 highmem）
     - 外设测试（UART、GPIO、中断）
     - DDR 测试（读写验证）
     - SRAM 测试（`.extdata` 段程序）
     - 综合测试（`t007_rvv_add_test.elf` + 其他代表性程序）
  5. 链接脚本：最终版 `coralnpu_tcm.ld.tpl`，支持 ITCM/DTCM/SRAM/DDR 各段
- **输出**：
  1. 完整 `CoralNPUChiselSubsystem.sv`（裁剪版，无 ISP）
  2. 综合报告（资源/时序）
  3. 完整 SoC 测试报告：所有测试通过
  4. 上板验证：完整 SoC 在 DualV7 上跑起来
- **约束**：
  1. **ISP 裁剪**：无摄像头输入，ISP 模块可移除或保留空 TLUL 端口
  2. **DMA/spi2tlul 可选**：根据资源和需求决定是否添加
  3. **资源预算**：确保总资源不超过 V7 限制（LUT 1221600，BRAM 1292 RAMB36）
  4. **时钟域管理**：main/isp/ddr/test 多域，ISP 域可接地处理
  5. **产物目录规范**：`synth/out/T021-complete-soc/`（201）与 `~/fpga/work/T021-complete-soc/`（202）

## 验收标准
1. **bazel 生成 SV 成功**：完整 SoC SV 生成无错误
2. **综合 0 ERROR**：综合+实现+bitstream 完成，无 ERROR
3. **时序收敛**：WNS ≥ 0（100MHz 目标）
4. **资源报告**：记录 LUT/FF/BRAM 使用量，评估是否在预算内
5. **完整测试集通过**：
   - RVV 测试：92 个 TCM 可测测试全部 PASS（xsim 或上板）
   - DDR 测试：读写验证成功
   - SRAM 测试：`.extdata` 段程序运行成功
   - 外设测试：UART、GPIO、中断工作正常
   - 综合测试：`t007_rvv_add_test.elf` 上板运行 ALL PASS
6. **matmul/highmem 测试**（可选）：若资源允许，可添加 highmem 配置测试 matmul 7 个测试
7. **稳定性**：多次运行无错误，无总线挂死，无时序违例

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