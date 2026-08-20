# coralnpu 完整 SoC（Nexus 风格）模块拆解与差距分析

日期：2026-08-20
参考对象：`coralnpu/hdl/chisel/src/soc/`（CoralNPUChiselSubsystem，OpenTitan TileLink-UL 架构）
目标：评估"仿照 Nexus SoC 做一个完整 SoC"的可行性，先输出模块拆解 + 差距 + 上板路径。

## 1. 完整 SoC 架构

CoralNPUChiselSubsystem = **TileLink-UL（TL-UL）crossbar 主干** + 多主机 + 多从设备 + 边界 AXI 桥 + 多时钟域 + 中断架构。

### 1.1 主机（Hosts / master）

| 主机 | 宽度 | 时钟域 | 说明 |
| --- | --- | --- | --- |
| `rvv_core`（coralnpu_core） | 128 | main | NPU 核（CoreTlul：TL-UL 版，含 RVV + FPU） |
| `spi2tlul` | 128 | main | SPI 从机引导接口（外部 SPI flash/主机加载） |
| `dma` | 128→32 | main | DMA 引擎（host 128 / device 32） |
| `ispyocto_m1/m2` | 64 | isp_axi_clk | ISP 图像处理器 AXI 主机（外部） |
| `autoboot` | 32 | main | 自动引导主机 |
| `test_host_32` | 32 | test | 仅 test harness 启用 |

### 1.2 从设备（Devices / slave）+ 地址映射

| 设备 | 地址 | 大小 | 宽度 | 实例化 | 时钟域 |
| --- | --- | --- | --- | --- | --- |
| `coralnpu_device` | 0x00000000（ITCM）/ 0x00010000（DTCM）/ 0x00030000（periph） | 8KB+32KB+4KB | 128 | 核内（CoreTlul） | main |
| `rom` | 0x10000000 | 32KB | — | 外部提供 | main |
| `sram` | 0x20000000 | 4MB | 128 | 内部 TlulSram | main |
| `uart0` | 0x40000000 | 4KB | 32 | 外部提供 | main |
| `clk_table` | 0x40001000 | 4KB | 32 | 外部提供 | main |
| `uart1` | 0x40010000 | 4KB | 32 | 外部提供 | main |
| `spi_master` | 0x40020000 | 4KB | 32 | 内部 bus.SpiMaster | main |
| `gpio` | 0x40030000 | 4KB | 8 | 内部 bus.GPIO | main |
| `i2c_master` | 0x40040000 | 4KB | 32 | 外部提供 | main |
| `dma` | 0x40050000 | 4KB | 32 | 内部 bus.DmaEngine | main |
| `spi_master_flash` | 0x40070000 | 4KB | 32 | 内部 bus.SpiMaster | main |
| `clint` | 0x02000000 | 64KB | 32 | 内部 bus.Clint | main |
| `plic` | 0x0c000000 | 64MB | 32 | 内部 bus.Plic（31 中断） | main |
| `ispyocto_ctrl` | 0x50000000 | 1MB | — | 外部（TLUL 端口） | isp_axi_clk |
| `ddr_ctrl` | 0x70000000 | 4KB | 32 | TLUL2Axi 桥 → AXI | ddr |
| `ddr_mem` | 0x80000000 | 2GB | 128→256 | 宽度桥 + TLUL2Axi → AXI | ddr |

### 1.3 内部实例化模块（SoCChiselConfig.modules）

`rvv_core`、`spi2tlul`、`spi_master`、`gpio`（8 位）、`dma`、`spi_master_flash`、`clint`、`plic`（31 int）、`sram`（4MB）。

**外部提供**（子系统不实例化，由集成方挂 TLUL）：`rom`、`uart0`、`uart1`、`clk_table`、`i2c_master`。

**特殊桥接**：`ddr_ctrl/ddr_mem`（TLUL→AXI）、`ispyocto_m1/m2`（AXI→TLUL）。

### 1.4 架构图（文本）

```
                    ┌────────────── CoralNPUChiselSubsystem ──────────────┐
 main 时钟域        │                                                    │
 ┌──────┐  TL128   ┌──────────────────────────────────────────────────┐ │
 │CoreTlul│ ───────►│              CoralNPUXbar（TL-UL）                │ │
 │(RVV+FPU)│        │  hosts: core/spi2tlul/dma/autoboot               │ │
 │ITCM/DTCM│◄───────│  devices: 见 1.2 地址映射                        │ │
 └──────┘  TL128   └──────────────────────────────────────────────────┘ │
      │ mtip/msip/irq（CLINT→timer/software，PLIC→irq）                  │
      ├─► clint / plic / gpio / spi_master / dma / sram / spi2tlul     │
      │                                                               │
      ├─► [外部] rom / uart0 / uart1 / clk_table / i2c_master        │
      │                                                               │
      ├─► ddr_ctrl/ddr_mem：TLUL→(宽度桥)→TLUL2Axi→AXI→DDR（ddr 域）   │
      └─► ispyocto_ctrl：TLUL 端口；ispyocto_m1/m2：AXI2TLUL→xbar     │
                         （isp_axi_clk 域）                             │
```

## 2. 与当前上板设计（CoreMiniAxi）的差距

| 维度 | 当前（top_coralnpu） | Nexus 完整 SoC | 差距 |
| --- | --- | --- | --- |
| 核接口 | CoreMiniAxi（AXI4 slave） | CoreTlul（TL-UL host/device） | 接口体系不同 |
| 总线 | 无（AXI 直连+响应桩） | TL-UL crossbar（多主机多从） | 需 crossbar |
| 指令扩展 | RVV/FPU 配置同核 | enableRvv=true + enableFloat=true | 需确认 CoreMiniAxi 是否已含 |
| 外设 | 仅 UART（host_cmd_fsm） | UART×2/SPI×2/GPIO/I2C/CLINT/PLIC/DMA | 全部缺失 |
| 存储 | ITCM+DTCM | + ROM/SRAM 4MB/DDR | 缺大存储 |
| 引导 | UART host 加载 | spi2tlul / autoboot | 可并存/替换 |
| 中断 | 无 | CLINT(定时/软) + PLIC(31) | 缺 |
| 调试 | host_cmd_fsm + DM 内部 | DM 端口暴露（dm_req/rsp external） | CoreMiniAxi 有 dm 内部 |
| 时钟域 | 单时钟 | main/isp/ddr/test 多域 | 多域管理 |
| 资源 | 43.5K LUT / 10 RAMB | 估计 100-300K LUT（含 RVV/FPU） | 需实测 |

## 3. 上板可行性评估

### 有利条件
1. **代码全部现成**：soc/ 目录完整（subsystem/xbar/config/外设），已通过 lint/build（CoralNPU 项目 CI）
2. **构建链路已验证可行**：`bazel build //hdl/chisel/src/soc:coralnpu_chisel_subsystem_cc_library_emit_verilog` 可生成完整 SoC SV（与 CoreMiniAxi 同链路，`--action_env=CC=clang-14`）
3. **参数可裁剪**：TlulSramParameters（4MB 可缩小）、PlicParameters、GPIO 宽度均可调；DDR/ISP 是外部接口，上板可不接
4. **S2C 资源充足**：7V690T = 1221600 LUT（现用 3.56%）

### 风险与挑战
1. **资源**：RVV+FPU 完整核 + crossbar + 外设，预估 LUT 用量（可能 10-25%），需综合实测；**4MB SRAM ≈ 910 RAMB36 会爆**（总数 1292）→ 必须缩小（如 256KB ≈ 57 块）
2. **DDR/ISP 上板不可用**：S2C 板无 DDR 控制器 IP 与摄像头 → 裁剪掉，或仅保留 TLUL 端口留空
3. **多时钟域**：isp/ddr 域需外部时钟源或接地处理
4. **UART 外设缺失**：uart0/uart1 需自己写 TLUL UART（或复用现有 host_cmd_fsm 改造成 TLUL 从）
5. **调试链**：DM 端口（dm_req/dm_rsp）暴露需外部 debug 主机；现有 UART host 通路可改造为 uart1 从访问
6. **综合时长**：比 CoreMiniAxi 大，202 综合时间显著增加

## 4. 推荐路线（裁剪版完整 SoC）

**目标**：先在 S2C 板跑通"NPU 核 + TL-UL crossbar + 基础外设 + UART 加载"的完整 SoC，DDR/ISP 后续按需。

### 阶段 A：最小完整 SoC（MVP）
- CoreTlul（含 RVV/FPU，ITCM/DTCM 8KB/32KB）
- CoralNPUXbar（TL-UL）
- 外设：**clint + plic + gpio + spi_master + sram（缩小 256KB）**
- **TLUL UART**（新建，或把现有 host_cmd_fsm 挂到 uart1 位置）
- 引导：保留 **spi2tlul**（SPI 从机）+ 现有 **UART host 加载**双通道
- 裁剪：DDR/ISP/i2c/dma/spi_master_flash（先不接）
- 上板：bazel 生成 SV → top 例化（S2C 时钟/UART/LED 引脚）→ 综合 → 烧录

### 阶段 B：扩展
- DMA、i2c、spi_master_flash、autoboot
- SRAM 扩大、DDR（如引入外部 DDR IP）

### 阶段 C：完整
- ISP（如有外部输入源）、多时钟域 DDR

### 关键前置验证（阶段 A 前）
1. bazel 生成 `CoralNPUChiselSubsystem.sv`（裁剪配置）成功
2. 综合时序（CoreTlul RVV/FPU 在 100MHz 收敛？）
3. UART 通路（TLUL UART 或 host_cmd_fsm 改造）可加载程序到 ITCM
4. T007 程序在完整 SoC 上跑通

## 5. 待确认问题
- [x] CoreMiniAxi 是否已含 RVV/FPU：`Parameters.scala` enableRvv/enableFloat 默认 **false**，但 CoreMiniAxi.sv 已含 float 端口（io_float_rd...，3 处 rvv/float 模块）→ **FPU 已开、RVV 未开**；CoreTlul 配置 enableRvv=true → 完整 SoC 核差异 = 多 RVV + TL-UL 接口
- [ ] S2C 板是否有可用 SPI flash/GPIO 引出（spi2tlul 引导可行性）
- [ ] 阶段 A 是否保留 DMA（不保留可简化）
- [ ] UART 外设采用"自写 TLUL UART"还是"host_cmd_fsm 改造"
