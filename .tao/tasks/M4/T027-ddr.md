# T027: DDR 通路增加 + 验证（不含评测）

## 目标
SoC 增加 DDR 通路（0x80000000），xsim + 上板验证通过。评测在 T028。

## 背景（已查证）
- **上游已规划**：`ddr_ctrl`（0x70000000，4KB，clockDomain=ddr）+ `ddr_mem`（0x80000000，2GB，clockDomain=ddr，width=128）
- **CDC 已内建**：DeviceConfig.clockDomain → Xbar async 端口（async_ports_devices）+ TlulFifoAsync——零手写
- **桥已有**：`bus/TLUL2Axi.scala`（TL→AXI，CoreTlul 在用）
- **MIG 资料**：chipyard 验证的 mig.prj（MT41K256M16XX-125、DDR3-800、64bit、双 rank）+ ddr3.xdc（rank-0 只约束，rank-1 MIG 内部）
- **上游 DDR 未完成**：io_ddr_mem_axi 在 coralnpu_soc.sv 悬空——需完整实现（核 ext 通路 → Xbar → TLUL2Axi → MIG）
- **加载**：UART（方案 A，10MB 15min）/ SPI（T026 后可秒级）
- **AXI interconnect**：评测场景分时单 master（加载 UART、运行核），MIG 直连足够；ISP/DMA 并发时再加（非本次）

## 工作清单

### ① 桥接与 Xbar（fork）
- CrossbarConfig：加 `ddr_ctrl`（0x70000000）+ `ddr_mem`（0x80000000，clockDomain=ddr，width=128）
- connections：`coralnpu_core` → ddr_mem/ddr_ctrl；`uart_host` → ddr_mem/ddr_ctrl
- 核 ext 通路：核访问 0x80000000（非 TCM/CSR）= ext → tl_host → Xbar（Debug.scala 已支持，无需改 MemoryRegion）

### ② MIG 集成（综合侧）
- MIG 7 series IP 生成（mig.prj 参数）
- top_coralnpu_soc.sv：实例化 MIG + clk_wiz（200MHz 参考）+ ddr_clk/ddr_rst 接 Xbar async 端口
- build_top.tcl：MIG 文件 + ddr3.xdc
- 拥塞：RVV 已有拥塞问题，加 MIG 更挤——用 T025 手段（ReduceCongestion/AggressiveExplore）

### ③ 验证（本任务）
1. xsim：核/UART 经 Xbar → TLUL2Axi → MIG 写读回验（0x80000000）
2. 综合（长任务，RVV + MIG，拥塞攻坚）
3. 上板：MIG calibration（init_calib_complete）+ DDR 写读回验

### ④ 软件（评测前，T028 用）
- load_elf/bench_rvv.py：支持 0x80000000 段 + 加载超时（10MB 15min 或 SPI 秒级）

## 依赖
- T025：拥塞攻坚经验（64K/1M + route directive）
- T026：SPI 加载（可选，大用例加速）

## 完成区
**状态**：待开始
**Commit**：
**综合资源**：
**测试结果**（xsim/上板验证）：
**验收结果**：
**新发现/坑**：
**遗留问题**：
