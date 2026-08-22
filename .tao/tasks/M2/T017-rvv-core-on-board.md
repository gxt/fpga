# T017: RVV 核上板验证

## 执行环境
**执行环境**：机器202（bazel 生成 SV + 综合）＋ 机器201（上板烧录 + UART 测试）

## 接口规范
- **输入**：
  1. coralnpu 仓库中 `rvv_core_mini_axi_cc_library` 目标（已有 `--enableRvv=True` 等 gen_flags）
  2. 测试程序 `sim/t007_rvv_add_test.c`（需编译为 ELF）
  3. M1 已验证的 T010-clean bit（UART 同步器修复，host 通路正常）
- **输出**：
  1. RVV 版 `RvvCoreMiniAxi.sv`（由 bazel 生成）
  2. 综合报告（资源利用率、时序 WNS/WHS）
  3. 上板测试结果：`t007_rvv_add_test.elf` 运行成功（自校验返回 0）
- **约束**：
  1. **RTL 零改动**：仅使用现有 `rvv_core_mini_axi_cc_library` 配置，不修改 Chisel 源码
  2. **无 SRAM/DDR/外设**：仅测试 RVV 核本身（ITCM/DTCM + RVV 后端）
  3. **先仿真后上板**：先用 xsim 跑 `t007_rvv_add_test.elf` 确认功能正确，再综合上板
  4. **遵循 flow-guide**：综合任务用 `run202.sh` nohup 启动，不阻塞等待
  5. **产物目录规范**：`synth/out/T017-rvv-core/`（201）与 `~/fpga/work/T017-rvv-core/`（202）

## 验收标准
1. **bazel 生成 SV 成功**：`bazel build //hdl/chisel/src/coralnpu:rvv_core_mini_axi_cc_library_verilog` 无错误，产出 `RvvCoreMiniAxi.sv`
2. **xsim 仿真通过**：新建 tb 加载 `t007_rvv_add_test.elf`，运行至 HALTED，自校验返回 0（ALL PASS）
3. **综合 0 ERROR**：`build_top.tcl` 综合+实现+bitstream 完成，无 ERROR（CRITICAL WARNING 可接受）
4. **时序收敛**：WNS ≥ 0（setup）且 WHS ≥ 0（hold），目标频率 100MHz（与 M1 一致）
5. **资源报告**：记录 LUT/FF/BRAM/DSP 使用量，评估 RVV 核在 V7 上的资源开销
6. **上板测试通过**：
   - 烧录 bit 后 UART 通路正常（`?` 命令响应 `HELP`）
   - `load_elf_uart.py` 加载 `t007_rvv_add_test.elf` 成功（ITCM 204 字 + DTCM 28 字）
   - 程序运行后 HALTED（STATUS=1），`t007_result_check.py` 读回 DTCM 结果与预期一致（整数加法 101,202,...；浮点加法 1.5,3.0,...；标量浮点 2.0,3.0,5.0,7.0）

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