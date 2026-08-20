# §02 构建命令

## §02.1 环境初始化

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
source ./env.sh
export XILINXD_LICENSE_FILE=~/vivado_lic2037/vivado_lic2037.lic
```

远端机器 `zzx@162.105.89.151:10202` 的 `/home/zzx/vivado-risc-v/env.sh`
在 2026-05-02 检查时不存在。可用的环境初始化为：

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
```

## §02.2 构建步骤

```bash
# 生成 Verilog（Chisel → RTL）
make verilog BOARD=dualv7 CONFIG=rocket64b2

# 创建 Vivado 工程
make vivado-project BOARD=dualv7 CONFIG=rocket64b2

# 综合 + 布局布线 + 生成 bitstream
make bitstream BOARD=dualv7 CONFIG=rocket64b2
```

2026-05-02 任务 002x 观察到：`make bitstream BOARD=dualv7 CONFIG=rocket64b2`
可进入综合，但 `riscv_mig_7series_0_0_synth_1` 在 `Start Timing Optimization`
后超过 9 小时无日志推进；无 `ERROR:`，无 `.vivado.error.rst`，也无 `.bit` 产物。

## §02.3 软件构建

```bash
make sw BOARD=dualv7 CONFIG=rocket64b2
```

2026-05-16 复核到：202 机器上的 `~/vivado-risc-v/linux-stable`
**不是完整内核树**，只有 `.config` 和少量 `drivers/` overlay，
不能直接拿来执行 `make -C linux-stable oldconfig/all`。

202 上实际可用的完整内核源码树在：

```bash
/home/zzx/vivado/sw/linux
```

已确认：

- `make -C /home/zzx/vivado/sw/linux kernelversion` 返回 `6.1.166`
- `make -C /home/zzx/vivado/sw/linux ARCH=riscv \
  CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- oldconfig` 返回 `0`
- `make -C /home/zzx/vivado/sw/linux ARCH=riscv \
  CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- -n arch/riscv/boot/Image`
  返回 `Nothing to be done`

因此，**远端内核可以编译**，但要么：

1. 直接在 `/home/zzx/vivado/sw/linux` 下编译；要么
2. 先把 `~/vivado-risc-v/linux-stable` 正确指向完整内核树

当前 `~/vivado-risc-v/Makefile` 里的 `linux` 目标仍假定
`linux-stable/` 是完整源码树，这一点与 202 现场状态不一致。

## §02.4 硬件服务（需要实际板卡时）

```bash
hw_server -d &
cs_server &
```

## §02.5 bitstream 与 MCS 输出坑

2026-05-03 任务 015x 观察到：`make bitstream BOARD=dualv7
CONFIG=rocket64b2` 在 `.bit` 生成成功后，还会继续调用
`write_cfgmem -format mcs -interface SPIx4` 生成 MCS 文件。

若 bitfile 的 `BITSTREAM.Config.SPI_buswidth` 为 `1`，`write_cfgmem`
会报 `Writecfgmem 68-20`，因为 `SPIx4` 要求该属性为 `4`。此时
`dualv7-riscv.runs/impl_1/riscv_wrapper.bit` 已经可用，但
`workspace/rocket64b2/dualv7-riscv.mcs` 不会生成。

后台 wrapper 若写成 `make ... 2>&1 | tee ...` 且未启用 `pipefail`，
`BUILD EXIT: 0` 可能掩盖 `make` 失败。判断构建结果时必须检查
`/tmp/build-*.log` 尾部和目标文件。
