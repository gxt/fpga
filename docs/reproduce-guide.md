# 复现指南（全流程关键命令）

日期：2026-08-21
目的：T014 验收——按文档从零执行关键命令的可复现性。每命令标注预期输出与环境要求。

## 1. bazel 构建 core_mini_axi SV（仿真/综合入口）

```bash
cd coralnpu && CC=clang-14 bazel build //hdl/chisel/src/coralnpu:core_mini_axi_cc_library_emit_verilog
```
- **预期**：`INFO: Elapsed time...`（首次 ~7min，增量 ~20s）；产物 `bazel-bin/hdl/chisel/src/coralnpu/CoreMiniAxi.sv`
- **环境**：bazel 8.6.0；Ubuntu 24.04 需 clang-14（`host_clang` wrapper 已改）；无 ERROR
- **执行地**：201（有外网下载依赖）

## 2. ELF 构建（T007 程序）

```bash
bash sim/build_t007.sh
```
- **预期**：产出 `sim/build/t007_scalar_fp_test.elf`、`t007_rvv_add_test.elf`
- **环境**：`riscv64-unknown-elf-gcc`（rv32imf_zve32f 工具链）
- **执行地**：201

## 3. xsim 仿真（上板 RTL 功能验证）

```bash
bash ~/fpga/scripts/t016_xsim.sh          # T016 阶段A：Debug 写 TCM
bash ~/fpga/scripts/t016_xsim_cont.sh     # T016 复现：40MHz 连续写 TCM
```
- **预期**：阶段A `=== T016-A: ALL CHECKS PASSED ===` exit 0；cont `DTCM/ITCM 16/16`
- **环境**：Vivado 2025.1 + license；`~/fpga/work/T016-xsim/` 工作目录
- **执行地**：202

## 4. 综合 + 实现 + bitstream

```bash
scripts/run202.sh <task> 'XILINXD_LICENSE_FILE=/tools/Xilinx_lic/vivado_all.lic \
  /tools/Xilinx/2025.1/Vivado/bin/vivado -mode batch -source scripts/build_top.tcl \
  -tclargs work/<task> rtl_out/core_mini_axi synth/rtl synth/xdc proj'
```
- **预期**：`work/<task>/top_coralnpu.bit` + `<task>.xpr` + `utilization_route/timing_route.rpt`；build.log 0 ERROR；WNS>0/hold 0（参考 T010-clean：WNS+0.950）
- **环境**：Vivado 2025.1 + license；预计 **25-35min**；查询 `scripts/run202_check.sh <task>`
- **执行地**：202（201 用 `scripts/run202.sh` 安排 nohup 后台，不等待）

## 5. 上板烧录

```bash
/tools/Xilinx/2025.1/Vivado/bin/vivado -mode batch -nolog -nojournal \
  -source scripts/program_top.tcl -tclargs <bit路径> program
```
- **预期**：`==> T012 program DONE`，End of startup status HIGH
- **环境**：板卡连接（Digilent J24）、电源；**执行前提醒用户**
- **执行地**：201

## 6. 上板加载程序并运行

```bash
sg dialout -c "python3 -u sim/T015-load_elf_uart.py sim/build/t007_scalar_fp_test.elf"   # 加载 232 字 + S 启动
sg dialout -c "python3 -u sim/T015-t007_result_check.py"                                  # 回读结果
```
- **预期**：加载全成功 + S OK；回读 `out_mul={700,1600,2700,4000}`、`fout={2.0,3.0,5.0,7.0}` → **ALL PASS**
- **环境**：板卡 SW1 复位（先提醒用户）；`/dev/ttyUSB0`（需 `sg dialout`）；**用 `-u` 保证实时输出**
- **执行地**：201

## 7. 上板 Debug 写 TCM（T016）

```bash
sg dialout -c "python3 -u sim/T016-debug_write_tcm.py"
```
- **预期**：Debug 写 ITCM[0x0]=DEADBEEF/[0x4]=CAFEBABE 读回一致 → **T016-B: ALL PASS**
- **环境**：同 6

## 未完成/被排除项（验收 4）

| 项 | 状态 | 原因 |
| --- | --- | --- |
| UVM 验证 | 排除 | 采用 Verilator/Cocotb + xsim 已覆盖验证目标 |
| 完整 SoC 移植 | 排除 | ADR-004：ISP/DDR/外设与板卡/目标无关，工程量巨大；规划见 soc-analysis.md |
| RVV 上板验证 | 未做 | 上板核 enableRvv=false；t007_rvv 仅仿真通过，需 RVV 版核综合 |
| DDR/ISP/外设上板 | 排除 | S2C 板无对应硬件 |
| LED 引脚修正 | 可选未做 | UART 通路已满足结果输出验证 |
| 完整 SoC 综合试点 | 未启动 | soc-analysis.md 有裁剪方案，后续可选 |
