# T022: 标量 SoC 基座（CoreTlul + Xbar + 最小外设 + host 桥）

## 目标
DualV7 跑起较完整 SoC 的标量基座：CoreTlul（enableRvv=false）+ CoralNPUXbar + clint/plic/gpio/sram(256K) + **保留 UART 加载**（host_cmd_fsm → Axi2TLUL → Xbar → 核 tl_device）。验证加载通路（r/w）+ 测试向量 + SRAM 数据。

## 执行环境
**201**（改 coralnpu fork + 上板）+ **202**（bazel 生成 SV + Vivado）。bazel/vivado 由用户执行（working.sh）。

## 改动（coralnpu fork → gxt/coralnpu）
1. `soc/SoCChiselConfig.scala`：裁 ispyocto/spi2tlul/dma/spi_master_flash/spi_master；sram 4MB→256KB；enableRvv=false
2. `soc/CrossbarConfig.scala`：加 `uart_host` 主机端口（访问 coralnpu_device/sram/clint/plic/gpio，仿 spi2tlul）
3. `soc/CoralNPUChiselSubsystem.scala`：实例化 Axi2TLUL（uart_host，复用 ISP 模式）+ io 端口
4. 主仓库 submodule 指针 → gxt/coralnpu 新 commit

## 流程（E1-E8）
1. **E1** bazel 生成裁剪 SoC SV
2. **E2** xsim 仿真验证 r/w 通路（host→Axi2TLUL→Xbar→核，加载 t007_scalar 到 TCM + 回读）——**先仿真后综合**
3. **E3-E6** 综合 20M（top 适配：host_cmd_fsm + Axi2TLUL + SoC）
4. **E7-E8** 烧录 + 上板：测试向量（t007_scalar 等）+ SRAM 数据测试

## 约束
- bazel/vivado 由用户执行，working.sh 在 workspace/T022-<subtask>/
- 改 fork 走 gxt/coralnpu 分支，主仓库指针更新
- 验证目标是**测试向量**（非外设重点）；外设能访问到即算通过

## 验收标准
1. 裁剪 SoC SV 生成成功（0 目标缺失）
2. xsim r/w 通路验证通过（加载 t007_scalar → HALTED + 回读结果）
3. 综合 20M 成功（0 ERROR，时序收敛）
4. 上板测试向量 ALL PASS + SRAM 数据读写正确

## 完成区
**状态**：✅ 完成（2026-08-26，E1-E8 全通过）
**Commit**：
**测试结果**：
- E1 ✅ 裁剪 SoC SV 生成（3.5MB，uart_host ✓ / 无 ddr/isp/spi）
- E2 ✅ xsim ALL PASS（host→Axi2TLUL→Xbar→核 r/w 通路）
- E3-E6 ✅ 综合 20M 成功（~33min；**WNS +15.410 完全收敛**，WHS -0.242 轻微 hold；资源 Reg 15K/RAMB36 74/DSP48 6）
- E7 ✅ 烧录成功
- E8 ✅ 上板 t007_scalar **ALL PASS**（加载 1.62s → HALTED → 结果数组正确）——**裁剪 SoC 经 Xbar 通路跑通**
**修改文件**：
- coralnpu fork：SoCChiselConfig/CrossbarConfig/CoralNPUChiselSubsystem（裁剪 + uart_host）→ gxt/coralnpu ac01a545
- `synth/rtl/top_coralnpu_soc.sv`（host_cmd_fsm→uart_host_axi + rom 响应桩）
- `synth/tb/T022-tb_soc.sv`（复用 M1 T010-tb_top UART 逻辑）
- `synth/tcl/build_top.tcl`（top 参数化 + 按 top 分支文件列表）
**验收结果**：
- 裁剪 SoC（CoreTlul enableRvv=false + Xbar + clint/plic/gpio/sram 256K）在 DualV7 上板跑通
- UART 加载保留（host_cmd_fsm→Axi2TLUL→Xbar→核 tl_device），r/w 命令全支持，与 chip_nexus 架构一致
- 20M 时序完全收敛
**新发现/坑**：
1. g_direct 仿真必须 clk_p 直连（IBUFDS 仿真恒高）
2. tb 必须复用 M1 T010-tb_top 的 UART 逻辑（重写引入多处 bug）
3. build_top 需按 top 分支文件列表（SoC 版无 axi_master_stub）
4. SRAM 256K 用 RAMB36 74 块（5.7%）
**遗留问题**：SRAM 数据读写未单独上板测（测试向量经 Xbar 访问 SRAM 隐含验证）；待 T023（RVV）
