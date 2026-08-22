# T018: TL-UL + Crossbar 集成验证

## 执行环境
**执行环境**：机器202（xsim 仿真 + 综合）＋ 机器201（上板烧录 + UART 测试）

## 接口规范
- **输入**：
  1. T017 验证的 RVV 核（`RvvCoreMiniAxi.sv` 可工作）
  2. coralnpu soc 目录：`CoreTlul`（TL-UL 接口）、`CoralNPUXbar`、`CrossbarConfig`（裁剪配置）
  3. 最少外设：`coralnpu_device`（核内 TCM）、小 SRAM 256KB（`TlulSram` 参数调整）
  4. 测试集：`coralnpu/tests/cocotb/BUILD` 中 `rvv_core_mini_axi_model` 相关的 92 个 RVV 测试（TCM 可测）
  5. 上板代表性程序：`t007_rvv_add_test.elf`（RVV 功能验证）
- **输出**：
  1. 裁剪版 `CoralNPUChiselSubsystem.sv`（仅含 core + crossbar + coralnpu_device + sram 256KB）
  2. 综合报告（资源/时序）
  3. xsim 仿真结果：92 个 RVV 测试全部 PASS
  4. 上板结果：`t007_rvv_add_test.elf` 运行成功
- **约束**：
  1. **最小改动**：仅修改 `CrossbarConfig` 和 `SoCChiselConfig` 以裁剪外设，不改核心 RTL
  2. **host 加载通路变更**：从 AXI 改为 TL-UL（需验证 `spi2tlul` 或 `test_host_32` 能加载程序到 TCM）
  3. **SRAM 容量**：256KB（约 57 个 RAMB36），确保不超出 V7 BRAM 限制
  4. **先仿真后上板**：xsim 跑完 92 个测试再综合
  5. **产物目录规范**：`synth/out/T018-tlul-crossbar/`（201）与 `~/fpga/work/T018-tlul-crossbar/`（202）

## 验收标准
1. **bazel 生成 SV 成功**：`bazel build //hdl/chisel/src/soc:coralnpu_chisel_subsystem_cc_library_emit_verilog` 无错误，产出裁剪版 `CoralNPUChiselSubsystem.sv`
2. **xsim 仿真通过**：
   - 新建 tb 模拟 TL-UL host（`test_host_32`）加载程序到 TCM
   - 运行 92 个 RVV 测试（`rvv_core_mini_axi_model` 测试集），全部 PASS
   - 重点验证 crossbar 路由/仲裁无死锁、无地址冲突
3. **综合 0 ERROR**：综合+实现+bitstream 完成，无 ERROR
4. **时序收敛**：WNS ≥ 0（100MHz 目标）
5. **资源报告**：记录 LUT/FF/BRAM 使用量，对比 T017（纯核）增量
6. **上板测试通过**：
   - UART 通路正常（`?` 响应 `HELP`）
   - `load_elf_uart.py` 加载 `t007_rvv_add_test.elf` 成功（TL-UL host 通路验证）
   - 程序运行 HALTED，结果自校验 ALL PASS
7. **crossbar 功能验证**：读写 SRAM（0x20000000）成功，地址映射正确

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