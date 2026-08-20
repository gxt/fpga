# DualV7 从头上板流程包

这套流程包覆盖一条**可重复执行**的路径：

1. 在 `202` 上创建**干净 sandbox**
2. 从仓库生成 `Verilog -> VHDL wrapper -> Vivado project -> bit`
3. 从仓库生成 `boot.elf`
4. 在本地生成 `Image` 和 `ramdisk`
5. 本地通过 JTAG 下载并观察 UART，完成 smoke test

这套流程的默认快速基线是：

- `BOARD=dualv7`
- `CONFIG=rocket64b2`
- 主工程 commit：
  `137a01660c63948368aafd31fdabaf742314acd1`

选择这条基线的原因：

- 板级链路已经验证过
- `rocket64b2` 比 `Mega` 更快，适合从头复现
- bitstream 产物已经有可用的实机验证参考

## 1. 目录内容

```text
doc/dualv7-from-scratch-kit/
├── README.md
└── scripts/
    ├── 01_prepare_remote_clean_sandbox.sh
    ├── 02_build_remote_rocket64b2.sh
    ├── 03_build_local_linux_ramdisk.sh
    ├── 04_board_smoke_jtag_boot.py
    └── run_r1_end_to_end.sh
```

## 2. 环境假设

### 2.1 远端 202

- 主机：`zzx@192.168.200.202`
- 主仓：`~/vivado-risc-v`
- Vivado：
  `/tools/Xilinx/2025.1/Vivado/settings64.sh`
- License：
  `/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic`
- **202 不能联网**

### 2.2 本地

- 本地仓：
  `/home/data/vivado-risc-v`
- UART：
  `/dev/serial/by-id/usb-1a86_5523-if00-port0`
- 串口访问：
  当前用户对 `/dev/ttyUSB0` 无直接权限，板测步骤默认通过
  `sudo -n` 调起
- JTAG：
  本地 `hw_server` on `localhost:3121`
- 内核源码：
  `/home/data/vivado-risc-v/linux-stable`
- ramdisk 源码：
  `/home/data/vivado-risc-v/ramdisk-realcheck-src`

## 3. 快速用法

整套流程一条命令：

```bash
cd /home/data/vivado-risc-v
doc/dualv7-from-scratch-kit/scripts/run_r1_end_to_end.sh
```

默认输出目录：

- 本地：
  `/home/data/vivado-risc-v/workspace/from-scratch-kit-r1`
- 远端：
  `/home/zzx/dualv7-from-scratch-r1`

## 4. 分步执行

### 4.1 创建远端干净 sandbox

```bash
doc/dualv7-from-scratch-kit/scripts/01_prepare_remote_clean_sandbox.sh
```

这一步会：

- 用 top-level commit `137a016...` 导出干净工作树
- 用本地 git object / 本地 submodule clone 还原需要的子仓
- 对 202 离线环境做**最小 sbt 插件修补**
  - 保留 `sbt-assembly`
  - 去掉 `scalafix / bloop / mima / buildinfo`
  - 去掉 `build.sbt` 里仅用于 scalafix 的 settings
- 从 `202` 主仓复制一组**已知可用的 Scala/SBT target 缓存**
  - 这是当前 202 离线环境的现实要求
  - 不复制这些缓存，干净 sandbox 会卡在 sbt/Zinc 编译桥问题
- 不碰 `~/vivado-risc-v` 主工作树

### 4.2 在 202 上生成 bit 和 boot.elf

```bash
doc/dualv7-from-scratch-kit/scripts/02_build_remote_rocket64b2.sh
```

默认会依次执行：

1. `make verilog`
2. `make workspace/rocket64b2/rocket.vhdl`
3. `make vivado-project`
4. `make .../impl_1/riscv_wrapper.bit`
5. `make JTAG_BOOT=1 bootloader`

注意：

- 这里**直接构建 `.bit` 目标**
- 不走 `make bitstream` 的 `.mcs` 生成支路
- 避免触发 `SPI_buswidth` / `write_cfgmem` 相关假失败
- `make verilog` 会先尝试**纯仓库路径**
- 如果 202 离线环境仍卡在 sbt/Zinc 编译桥，
  脚本会退到：
  - 使用同一源码快照下的 seeded `target/scala-2.13/system.jar`
  - 直接执行 `runMain/FIRRTL`
  继续生成 RTL

### 4.3 本地生成 `Image` 和 `ramdisk`

```bash
doc/dualv7-from-scratch-kit/scripts/03_build_local_linux_ramdisk.sh
```

### 4.4 本地 JTAG + UART smoke

```bash
sudo -n python3 doc/dualv7-from-scratch-kit/scripts/04_board_smoke_jtag_boot.py \
  --bit /home/data/vivado-risc-v/workspace/from-scratch-kit-r1/rocket64b2.bit \
  --bootelf /home/data/vivado-risc-v/workspace/from-scratch-kit-r1/boot.elf \
  --image /home/data/vivado-risc-v/linux-stable/arch/riscv/boot/Image \
  --ramdisk /home/data/vivado-risc-v/ramdisk-realcheck-src/out/ramdisk-realcheck \
  --out-dir /home/data/vivado-risc-v/workspace/from-scratch-kit-r1/smoke
```

## 5. 成功判据

### 5.1 构建

远端应得到：

- `workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit`
- `workspace/boot.elf`

### 5.2 上板

UART 日志中至少应看到：

- `U-Boot`
- `Starting kernel ...`
- `Run /init as init process`

更理想的成功标志：

- `REALCHECK: READY`

## 6. 这套流程验证了什么

如果整套流程跑通，说明以下链路同时成立：

1. `vivado-risc-v` 仓库源码可在隔离环境重建 Rocket DualV7 bit
2. `bootrom -> OpenSBI -> U-Boot` 的 `boot.elf` 构建可复现
3. 本地内核与 ramdisk 可复现
4. JTAG 下载与 UART 接收链路正常
5. 当前板级 Rocket 路线仍具备从仓库到上板的闭环能力

## 7. 当前已知限制

1. 这套流程是 **Rocket 快速基线**，不是 Mega / BOOM 路线
2. 目标是验证“从仓库到板子”的闭环，不覆盖：
   - 网络引导
   - NFS root
   - 频率 profile
   - BOOM-stop
3. 若要追求完全一致的 release 哈希，需要同时冻结：
   - top-level commit
   - 每个 submodule commit
   - Vivado minor version
   - 本地内核/ramdisk commit
