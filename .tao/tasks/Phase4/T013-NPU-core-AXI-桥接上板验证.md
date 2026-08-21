# T013: NPU core + AXI 桥接上板验证

## 执行环境
**执行环境**：机器201（机器201直接连接板卡）＋ 机器202（综合产物）

## 接口规范
- 输入：T010 bitstream（core_mini_axi + AXI 桥接版本）；T012 验证的板卡环境；**T015 验证的 UART host 通路（host 方案已定 = UART 状态机主控，T010 决策 + T015 落实，本任务不再细化 host 方案）**；T007 自定义测试程序（同一 ELF 上板对照）；**前置：LED 引脚修正（led_halted/fault/locked → AH44/AH43/AL40 低电平点亮，硬件工程师 2026-08-20，需机器202 重综合）**
- 输出：上板运行 NPU 程序并回读/观察结果；与 RTL 仿真结果对照记录（`.tao/knowledge/board-notes.md`）
- 约束：集成方式遵循 ADR-004（NPU core + AXI 桥接，不做完整 SoC）；host 侧驱动方式 = **UART 状态机主控（已定，见 T015）**

## 验收标准
1. 板卡上 NPU core 成功执行自定义测试程序（T007 的 ELF 或等价程序），结果通过 AXI 读回（或 UART/LED 等板载外设输出）
2. **上板结果与 Verilator/Cocotb 仿真结果位精确一致**；若有差异必须给出具体数值差与根因分析，不允许以"数值级一致"模糊通过
3. 记录完整验证链路：ELF → TCM 加载 → 运行 → 结果读回的命令/脚本（主仓库 `sim/` 或 `synth/` 下可复现）
4. 说明与上游 SoC 验证的差异（ADR-004 影响）与覆盖范围

## 完成区
**状态**：✅ **已验证**（验收 1-4 全部完成，2026-08-21；T007 上板运行 ALL PASS + ADR-004 差异说明）
**说明**：T013 的验收标准 1-3（NPU core 执行 T007、与仿真位精确一致、脚本可复现）在 T015 完成时已达成——T007 上板运行 out_mul={700,1600,2700,4000}/fout={2.0,3.0,5.0,7.0} **ALL PASS**（与机器202 仿真一致），脚本见 `sim/`（load_elf_uart/t007_result_check 等）。前置 LED 引脚修正（AH44/AH43/AL40）为可选项（UART 通路已满足结果输出验证），如需 LED 验证可后续做
**Commit**：主仓库 T015 系列；coralnpu fork `8225240f`
**测试结果**：T007 上板运行 ALL PASS（bit `T010-clean`）
**修改文件**：无新增（复用 T015 产物与脚本）
**验收结果**：
- ✅ 验收 1：NPU core 执行 T007 成功，结果 AXI 读回
- ✅ 验收 2：与仿真位精确一致（out_mul/fout 逐值一致）
- ✅ 验收 3：脚本已入库 `sim/` 可复现
- ✅ 验收 4：**与上游 SoC 验证差异说明（ADR-004）见下**
**新发现/坑**：T013 与 T015 的验证目标有重叠（T007 上板运行），实际由 T015 一并完成
**遗留问题**：LED 引脚修正（AH44/AH43/AL40）可选；RVV 版（t007_rvv）上板未做

### 验收 4：与上游 SoC 验证的差异说明（ADR-004 影响与覆盖范围）

**设计差异**（按 ADR-004，详见 `.tao/knowledge/adr-004-board-integration.md`）：
| 维度 | 上游完整 SoC（coralnpu_soc） | 本验证（top_coralnpu / core_mini_axi） |
| --- | --- | --- |
| 总线 | TL-UL crossbar（6 主机 × 16 从） | AXI4 slave 直连 + m_axi 响应桩 |
| 外设 | UART×2/SPI×2/GPIO/I2C/DMA/CLINT/PLIC | 仅 UART host（host_cmd_fsm） |
| 存储 | ITCM/DTCM + ROM + SRAM 4MB + DDR | ITCM/DTCM + CSR（无外部大存储） |
| 时钟域 | main/isp/ddr/test 多域 | 单时钟（MMCM 100MHz→40MHz core） |
| 核 | CoreTlul（enableRvv=true） | CoreMiniAxi（enableRvv=false，含 FPU） |

**验证覆盖范围**：
- ✅ **已覆盖**：NPU 核计算正确性（T007 标量+浮点上板位精确一致）；程序加载（AXI 写 ITCM/DTCM 16/16）；Debug 写 TCM（T016 ALL PASS）；UART host 通路稳定（同步器修复后 20/20）
- ❌ **未覆盖**：外设访问（SPI/GPIO/I2C/DMA）、DDR、中断（CLINT/PLIC 无）、crossbar 多主机仲裁、RVV 上板（`t007_rvv_add_test.elf` 仅仿真通过，未上板）

**差异影响**：
- NPU 计算核（CoreAxi）在两种集成方式下**相同**，故 T007 计算结果可外推至完整 SoC 的核行为
- 差异集中于集成层（总线/外设/存储），不影响"NPU 核计算正确性"这一上板验证核心结论
- 核配置差异：本验证核 enableRvv=false（与上游 enableRvv=true 不同），RVV 计算未在上板验证——如需完整 SoC RVV 上板，需完整 SoC 移植或 RVV 版 core_mini_axi 综合

## 审阅记录

#### 第 1 轮 engineer 自审
（工程师自审 subagent 的意见、问题、判决及 finding 处置）

#### 第 1 轮 reviewer 验收

**判决：Accepted**（上板实测以已记录证据复核，未独立重跑——需板卡复位）

**1. 重跑记录 / 独立核验（真实输出/退出码）**

- **T007 程序与 T015 脚本一致性**：
  - `t007_scalar_fp_test.c` 计算核验：out_mul = {100,200,300,400}×{7,8,9,10} = {700,1600,2700,4000}（0x2BC/0x640/0xA8C/0xFA0）✅；fout = {1.5,2.25,3.125,4.5}+{0.5,0.75,1.875,2.5} = {2.0,3.0,5.0,7.0}（0x40000000/0x40400000/0x40A00000/0x40E00000）✅
  - readelf 独立核对符号地址：`out_mul@0x10030`、`fout@0x10000`，与 `T015-load_elf_uart.py`/`T015-t007_result_check.py` 的 checks 地址一致 ✅
  - `build_t007.sh`（riscv64-unknown-elf-gcc + t007_tcm.ld + coralnpu/toolchain/crt 只读复用）与 `run_t007.sh`（Verilator C++ sim）与 T015 上板加载/回读脚本为同一 ELF 链路，一致 ✅
- **验收 4（ADR-004 差异说明）独立核验**（对照实际设计而非仅文档）：
  | 验收4 声明 | 实际设计证据 |
  |---|---|
  | AXI4 slave 直连 + m_axi 响应桩 | `top_coralnpu.sv` L205 `host_cmd_fsm u_host`、L277 `CoreMiniAxi u_core`、L415 `axi_master_stub u_mstub`（防 core 外部访问挂死）✅ |
  | 仅 UART host（host_cmd_fsm） | top 无 SPI/GPIO/I2C/DMA/CLINT/PLIC ✅ |
  | ITCM/DTCM + CSR（无外部大存储） | 无 DDR/SRAM 外挂 ✅ |
  | 单时钟（MMCM 100MHz→40MHz） | top 参数 CLK_IN_HZ=100MHz/CORE_CLK_HZ=40MHz、USE_MMCM=1 ✅ |
  | CoreMiniAxi（enableRvv=false，含 FPU） | 202 rtl_out `VCoreMiniAxi_parameters.h`：`KP_enableRvv=false`、`KP_enableFloat=true` ✅ |
  | 覆盖范围（未覆盖 RVV 上板/DDR/外设/中断） | 与设计事实一致，表述准确 ✅ |
  - coralnpu fork 当前 `8225240f`（方案 A 清理后，与完成区一致）✅
- **上板实测（T007 ALL PASS：out_mul={700,1600,2700,4000}、fout={2.0,3.0,5.0,7.0}）**：以 board-debug-log + T015 验收链复核，未独立重跑（需板卡复位）。当前上板 bit `synth/out/T010-clean/top_coralnpu.bit` md5=`9b2d8d0e8c2c7c2060984b29d92f2772`（T015 已核）✅

**2. 约束核验**

- 集成方式遵循 ADR-004（NPU core + AXI 桥接，不做完整 SoC）：top_coralnpu = CoreMiniAxi + host_cmd_fsm + axi_master_stub，符合 ✅
- host 侧 = UART 状态机主控（T010 决策 + T015 落实）：host_cmd_fsm 驱动 s_axi ✅
- 验收 1（NPU 执行 T007 + AXI 读回）：T007 上板 ALL PASS 记录 ✅
- 验收 2（与仿真位精确一致）：out_mul/fout 逐值一致（700/1600/2700/4000、2.0/3.0/5.0/7.0），无"数值级一致"模糊 ✅
- 验收 3（完整验证链路脚本入库）：load_elf_uart/t007_result_check 等 `sim/` 下可复现 ✅
- 验收 4（ADR-004 差异与覆盖范围）：见上表，与设计一致 ✅

**3. 发现（非阻塞）**

- 与 T015 验证目标重叠（T007 上板运行由 T015 一并完成）——任务文件已如实披露，属合理的验收依赖复用，不构成缺陷。
- 遗留项（LED 引脚修正 AH44/AH43/AL40、RVV 上板 t007_rvv）已如实列明为可选项/未覆盖，与验收 4 覆盖范围一致。

**边界说明**：上板实测以已记录证据复核（未独立重跑）；T016 返工项（阶段 A 验收脚本路径）不影响本任务验收——本任务产物/脚本与 T015 链路一致且完整。
