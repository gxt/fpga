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
**状态**：进行中（E1✅ E2✅）
**Commit**：
**测试结果**：
- E1 ✅ 裁剪 SoC SV 生成（CoralNPUChiselSubsystem.sv 3.5MB，uart_host ✓ / 无 ddr/isp/spi）
- E2 ✅ xsim **ALL CHECKS PASSED**：W 加载 4 指令→S→Q HALTED(status=1)→R 回读 DTCM[0x10000]=42→LED→HELP/ERR
  - **r/w 通路验证通过**：host_cmd_fsm → Axi2TLUL → Xbar → 核 tl_device → TCM
  - 仿真耗时 6:48（cpu 0.89s，主要是 115200 波特慢 + SoC 大模型调度）
**修改文件**：
- coralnpu fork（SoCChiselConfig/CrossbarConfig/CoralNPUChiselSubsystem）→ gxt/coralnpu ac01a545
- `synth/rtl/top_coralnpu_soc.sv`（host_cmd_fsm→uart_host_axi + rom 响应桩）
- `synth/tb/T022-tb_soc.sv`（复用 M1 T010-tb_top UART 逻辑）
- `synth/tcl/build_top.tcl`（top 参数化）
**验收结果**：
**新发现/坑**：
1. **g_direct 仿真必须 clk_p 直连**（IBUFDS 输出仿真恒高，clk_core 不翻转）——M1 已验证的写法
2. **tb 必须复用 M1 T010-tb_top 的 UART 逻辑**（队列接收器 + recv task）——重写引入多处 bug
3. xsim 耗时：115200 波特 + 3.5MB SoC → ~6-7min（正常）
**遗留问题**：待 E3-E6 综合（20M）→ E7-E8 上板
