# Chipyard 1.13.0 × DualV7 最小 bit 集成与上板报告

> 任务：046x | 日期：2026-05-14 | 执行者：deepseek

---

## 1. 整体结论

**状态：部分成功**

- `SmallBoomV4Config` `make verilog` 可复现通过
- 202 上隔离 sandbox 建立完成
- Vivado 合成、布局、布线全流程通过
- 生成有效 `.bit`（11.4MB）
- FPGA 配置成功，xc7v2000t 被 JTAG 正确识别
- **但**：UART 无输出（60秒）、JTAG DTM 不可达

**阻塞根因**：
1. 当前设计 AXI4 MEM 全部 tied off，CPU 无法访问 DDR/内存
2. bootrom.rv64.img 仅 192 字节（几乎为空引导代码）
3. JTAG pins 全部 tied off，debug 链路不工作
4. 100MHz 时序 WNS=-4.588ns，频率不可靠

---

## 2. 远端构建环境

| 项目 | 值 |
|------|-----|
| 机器 | `zzx@192.168.200.202` |
| Chipyard 源树 | `~/work/chipyard-dualv7-bootstrap/chipyard-1.13.0-src` |
| Sandbox | `~/work/chipyard-dualv7-bootstrap/dualv7-minbit/` |
| 报告目录 | `~/work/chipyard-dualv7-bootstrap/reports/046x/` |
| Vivado 版本 | 2025.1 |
| FPGA | xc7v2000tflg1925-1 |

---

## 3. ChipTop 端口处理表

基于实际生成的 `ChipTop.sv` 端口（SmallBoomV4Config + AbstractConfig）：

| ChipTop 端口 | 方向 | 位宽 | 处理方式 | 备注 |
|-------------|------|------|---------|------|
| `clock_uncore` | input | 1 | 接 IBUFGDS → sys_clk (100MHz) | ✓ |
| `reset_io` | input | 1 | 接 SW1（取反，active-low→high） | ✓ |
| `uart_0_txd` | output | 1 | 接 FPGA pin AU42 | ✓ |
| `uart_0_rxd` | input | 1 | 接 FPGA pin AV42 | ✓ |
| `axi4_mem_0_*` | AXI4 | 64-bit | **全部 tied off** | ✗ 无 DDR |
| `jtag_TCK/TMS/TDI` | input | 各1 | **tied to 0** | ✗ 无 debug |
| `jtag_TDO` | output | 1 | **悬空** | ✗ |
| `custom_boot` | input | 1 | **tied to 0** | — |
| `clock_tap` | output | 1 | **悬空** | — |
| `serial_tl_0_*` | bidir | 32-bit | **全部 tied off** | — |

---

## 4. FPGA 顶层集成

**文件**：`src/dualv7_top.v`

```
s2cclk_1_p/n (L4/L3) → IBUFGDS → sys_clk (100MHz)
SW1 (AP31)            → 取反 → reset_io
uart_0_txd/rxd        → AU42/AV42
ChipTop               → 直接实例化
其他端口              → tied off
```

**特点**：
- 纯 RTL 流程（无 Vivado BD/IP）
- 无 MIG / DDR
- 无 MMCM / PLL（直接 100MHz）
- 极简约束：仅 clock + reset + UART pin

---

## 5. Vivado 构建结果

### 5.1 构建命令

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
cd ~/work/chipyard-dualv7-bootstrap/dualv7-minbit
nohup bash -lc 'vivado -mode batch -source build.tcl \
  -log /tmp/046x-vivado.log -journal /tmp/046x-vivado.jou' \
  >/tmp/046x-nohup.out 2>&1 &
```

### 5.2 阶段耗时

| 阶段 | 耗时 |
|------|------|
| synth_design | 23分07秒 |
| opt_design | ~5分 |
| place_design | ~16分 |
| route_design | ~19分 |
| write_bitstream | 2分28秒 |
| **总计** | **~1小时10分** |

### 5.3 时序

| 指标 | 值 |
|------|-----|
| WNS (setup) | **-4.588ns** ✗ |
| WHS (hold) | +4.171ns ✓ |
| 最差路径 | L2 cache MSHRs (29级逻辑, 14.566ns) |
| SLR 跨越 | 1条 SLR1→SLR0 |
| 等效可运行频率 | ~68MHz |

### 5.4 资源占用

| 资源 | 已用 | 总量 | 利用率 |
|------|------|------|--------|
| Slice LUTs | 85,701 | 1,221,600 | 7.02% |
| LUT as Logic | 82,122 | 1,221,600 | 6.72% |
| Slice Registers | 50,390 | 2,443,200 | 2.06% |
| Block RAM | 186 | 1,292 | 14.40% |
| DSP | 55 | 2,160 | 2.55% |
| IO | 5 | 1,200 | 0.42% |

所有资源集中在 SLR0（单 SLR 内布局）。

### 5.5 产物

| 文件 | 大小 | 路径 |
|------|------|------|
| `dualv7_top.bit` | 11,918,551 bytes | sandbox 根目录 |
| `dualv7_top_timing_final.rpt` | — | sandbox 根目录 |
| `dualv7_top_util_final.rpt` | — | sandbox 根目录 |
| sha256 | `7904ad43...` | 已校验 |

---

## 6. 本地上板 smoke

### 6.1 JTAG 下载

| 项目 | 值 |
|------|-----|
| 工具 | xsdb (Vivado 2025.1) |
| 命令 | `xsdb -eval "connect; targets; fpga -file <bit>"` |
| 结果 | ✓ FPGA 配置成功 |
| JTAG ID | `xc7v2000t` 正常识别 |

### 6.2 UART 采集

| 项目 | 值 |
|------|-----|
| 串口 | `/dev/ttyUSB2` (CH341) |
| 波特率 | 115200 |
| 采集时长 | 60 秒 |
| 输出 | **0 字节** ✗ |

### 6.3 JTAG debug fallback

| 项目 | 值 |
|------|-----|
| 尝试 | jtagterminal, DTM 寄存器读取 |
| 结果 | "Target doesn't support Jtag Uart" |
| 原因 | jtag_TCK/TMS/TDI 均 tied to 0，DTM 不可达 |

---

## 7. 失败分析

### 7.1 无 UART 输出的直接原因

1. **bootrom 几乎为空**：`bootrom.rv64.img` 仅 192 字节
   - Chipyard `AbstractConfig` 生成的默认 bootrom 不含 UART 初始化序列
   - ChipTop 内建 BootROM 依赖 DDR（stack @ 0x80002000）
2. **AXI4 MEM tied off**：CPU 发起的任何内存访问均无响应
   - 若 bootrom 代码访问 DDR → 总线挂死
3. **时序不满足**：WNS=-4.588ns 可能导致 L2 cache 路径随机错误

### 7.2 时序失败根因

- 最差路径在 L2 InclusiveCache 的 MSHRs/requests 模块
- 29 级组合逻辑 + SLR crossing → 14.566ns 延迟
- 100MHz 周期仅 10ns，需要降到 ~68MHz 或优化 RTL

### 7.3 集成设计不足

- JTAG pins tied off → 无法进行任何 debug
- AXI4 MEM tied off → 无法验证 DDR/内存路径
- No frequency scaling → 100MHz 不可达

---

## 8. 下一轮应收方向

1. **P0 — 降低时钟频率**：改为 50MHz 或更低，解决时序问题
2. **P1 — 接入 DDR/MIG**：至少接 1 个 AXI4 MEM 端口到 MIG + DDR3
3. **P1 — 启用 JTAG**：接入 BSCANE2 + debug_bridge，恢复 debug 能力
4. **P2 — 自定义 bootrom**：编写包含 UART 初始化的最小 bootrom
5. **P3 — 添加 MMCM**：使用 PLL 生成合适时钟频率

---

## 9. 对 045x 状态的修正

045x 报告称 bootrom.rv64.img 的 "192B" 为"大小192B"，但当时未核实其内容。
实际这 192 字节仅包含基本的 trap vector 设置 + hang loop，**不含 UART 初始化**。
这在 045x 报告中被标记为"✓"但并未验证，046x 上板已证明该 bootrom 无法产生 UART 输出。

下一轮需自行构建包含 UART TX 初始化的最小 bootrom，或复用 vivado-risc-v 的 bootrom。

---

*报告结束*
