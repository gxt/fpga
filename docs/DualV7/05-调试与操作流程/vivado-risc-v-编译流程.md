# vivado-risc-v 编译流程

本文档基于当前实际工程状态整理，目标是把
`vivado-risc-v` 在 `DualV7` 板上的完整编译流程写清楚，
尤其是实际调用 `Vivado` 的步骤和命令。

适用对象：

- 本地管理仓：`/home/data/vivado-risc-v`
- 远端编译仓：`zzx@192.168.200.202:~/vivado-risc-v`
- 板卡：`dualv7`
- 默认配置：`rocket64b2`

注意：本文档写的是**当前工程的真实执行路径**，不是上游 README
的泛化描述。

---

## 1. 环境初始化

### 1.1 进入远端编译机

```bash
ssh zzx@192.168.200.202
```

### 1.2 初始化 Vivado 环境

当前远端**不要**用 `env.sh`，直接用下面这组命令：

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
cd ~/vivado-risc-v
```

### 1.3 常用基础依赖

工程 `Makefile` 里给出的系统依赖包括：

```bash
sudo apt update
sudo apt install \
  device-tree-compiler curl gawk openjdk-17-jdk \
  libmpc-dev libssl-dev gcc gcc-riscv64-linux-gnu \
  flex bison bc parted udev dosfstools \
  python-is-python3
```

如果要构建 Linux / U-Boot / OpenSBI，这些依赖要先满足。

---

## 2. 关键变量和目录

### 2.1 板级默认值

`board/dualv7/Makefile.inc` 当前定义：

```make
XILINX_PART ?= xc7v2000tflg1925-1
CFG_DEVICE  ?= SPIx4 -size 32
CFG_PART    ?= w25q32fv-spi-x1_x2_x4
MEMORY_SIZE ?= 0x40000000
```

### 2.2 CONFIG 到 Scala 类名的映射

`Makefile` 通过下面这条规则把 `rocket64b2` 变成 Scala 配置类：

```make
CONFIG_SCALA := $(subst rocket,Rocket,$(CONFIG))
```

例如：

- `rocket64b2` -> `Rocket64b2`
- `rocket64z1` -> `Rocket64z1`
- `rocket64z2m` -> `Rocket64z2m`

### 2.3 重要输出目录

以 `BOARD=dualv7 CONFIG=rocket64b2` 为例：

```text
workspace/rocket64b2/system.dts
workspace/rocket64b2/system-dualv7.dts
workspace/rocket64b2/system-dualv7/RocketSystem.fir
workspace/rocket64b2/system-dualv7.v
workspace/rocket64b2/rocket.vhdl
workspace/rocket64b2/system-dualv7.tcl
workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.xpr
workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit
workspace/rocket64b2/dualv7-riscv.mcs
workspace/boot.elf
```

---

## 3. 推荐的完整命令序列

### 3.1 软件侧产物

如果你要的是 SD 启动 Linux，而不是只出一个裸 bit，通常先做：

```bash
make -j"$(nproc)" linux
make -j"$(nproc)" u-boot
make -j"$(nproc)" bootloader
```

含义：

- `linux`：生成 `linux-stable/arch/riscv/boot/Image`
- `u-boot`：生成 `u-boot/u-boot-nodtb.bin`
- `bootloader`：生成 `workspace/boot.elf`

### 3.2 HDL 生成

当前工程里**没有** `make verilog` 目标。

也就是说，这条历史上常见的命令：

```bash
make verilog BOARD=dualv7 CONFIG=rocket64b2
```

在当前 202 远端仓库里会直接报：

```text
make: *** No rule to make target 'verilog'.  Stop.
```

当前正确的 HDL 目标应当是文件目标：

```bash
make -j"$(nproc)" \
  workspace/rocket64b2/system-dualv7.v \
  BOARD=dualv7 CONFIG=rocket64b2

make \
  workspace/rocket64b2/rocket.vhdl \
  BOARD=dualv7 CONFIG=rocket64b2
```

### 3.3 创建 Vivado 工程

```bash
make vivado-project BOARD=dualv7 CONFIG=rocket64b2
```

### 3.4 只生成 `.bit`

如果只需要 bit，不想顺带生成 MCS：

```bash
make MAX_THREADS=1 \
  workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit \
  BOARD=dualv7 CONFIG=rocket64b2
```

### 3.5 生成 `.bit + .mcs`

```bash
make MAX_THREADS=1 bitstream BOARD=dualv7 CONFIG=rocket64b2
```

注意：`bitstream` 目标不仅出 `.bit`，还会继续调用
`write_cfgmem` 生成 `.mcs`。

---

## 4. 详细构建链

## 4.1 软件链

### 4.1.1 Linux

```bash
make -C linux-stable \
  ARCH=riscv \
  CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- \
  oldconfig

make -C linux-stable \
  ARCH=riscv \
  CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- \
  all
```

### 4.1.2 U-Boot

```bash
make -C u-boot \
  CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- \
  BOARD=vivado_riscv64 \
  vivado_riscv64_config

make -C u-boot \
  BOARD=vivado_riscv64 \
  CC=/usr/bin/riscv64-linux-gnu-gcc \
  CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- \
  KCFLAGS='-O1 -gno-column-info' \
  u-boot-nodtb.bin
```

### 4.1.3 OpenSBI / boot.elf

```bash
make -C opensbi \
  CROSS_COMPILE=/usr/bin/riscv64-linux-gnu- \
  PLATFORM=vivado-risc-v \
  FW_PAYLOAD_PATH="$(realpath u-boot/u-boot-nodtb.bin)"
```

然后复制成：

```text
workspace/boot.elf
```

---

## 4.2 HDL 链

### 4.2.1 生成默认 DTS

第一段 Chisel 运行会生成：

```text
workspace/rocket64b2/system.dts
```

实际命令：

```bash
cp rocket-chip/bootrom/bootrom.img workspace/bootrom.img

/usr/lib/jvm/java-17-openjdk-amd64/bin/java \
  -Xmx12G -Xss8M \
  -Dsbt.io.virtual=false \
  -Dsbt.server.autostart=false \
  -jar /home/zzx/vivado-risc-v/sbt-launch.jar \
  "runMain freechips.rocketchip.diplomacy.Main \
   --dir $(realpath workspace/rocket64b2/tmp) \
   --top Vivado.RocketSystem \
   --config Vivado.Rocket64b2"
```

### 4.2.2 拼板级 DTS 并构建 BootROM

工程会把：

- `workspace/rocket64b2/system.dts`
- `board/dualv7/bootrom.dts`

拼成 `bootrom/system.dts`，然后用 `sed` 改：

- DDR 容量
- `clock-frequency`
- `timebase-frequency`
- 可选 `local-mac-address`
- 可选 `phy-mode`

之后调用：

```bash
make -C bootrom \
  CROSS_COMPILE=/home/zzx/vivado-risc-v/workspace/gcc/riscv/bin/riscv64-unknown-elf- \
  CFLAGS="-march=rv64imac -mabi=lp64" \
  BOARD=dualv7 \
  clean bootrom.img
```

生成的 `bootrom.img` 会被移动到：

```text
workspace/bootrom.img
```

### 4.2.3 生成 FIRRTL

第二段 Chisel 运行会读取新的 `workspace/bootrom.img`：

```bash
/usr/lib/jvm/java-17-openjdk-amd64/bin/java \
  -Xmx12G -Xss8M \
  -Dsbt.io.virtual=false \
  -Dsbt.server.autostart=false \
  -jar /home/zzx/vivado-risc-v/sbt-launch.jar \
  "runMain freechips.rocketchip.diplomacy.Main \
   --dir $(realpath workspace/rocket64b2/system-dualv7) \
   --top Vivado.RocketSystem \
   --config Vivado.Rocket64b2"
```

得到：

```text
workspace/rocket64b2/system-dualv7/RocketSystem.fir
```

### 4.2.4 FIRRTL 转 Verilog

```bash
/usr/lib/jvm/java-17-openjdk-amd64/bin/java \
  -Xmx12G -Xss8M \
  -cp "$(realpath target/scala-*/system.jar)" \
  firrtl.stage.FirrtlMain \
  -i workspace/rocket64b2/system-dualv7/RocketSystem.fir \
  -o RocketSystem.v \
  --compiler verilog \
  --annotation-file workspace/rocket64b2/system-dualv7/RocketSystem.anno.json \
  --custom-transforms firrtl.passes.InlineInstances \
  --target:fpga
```

然后复制成：

```text
workspace/rocket64b2/system-dualv7.v
```

### 4.2.5 Verilog 包一层 VHDL wrapper

```bash
/usr/lib/jvm/java-17-openjdk-amd64/bin/javac \
  -g -nowarn \
  -sourcepath vhdl-wrapper/src \
  -d vhdl-wrapper/bin \
  -classpath vhdl-wrapper/antlr-4.8-complete.jar \
  vhdl-wrapper/src/net/largest/riscv/vhdl/Main.java

/usr/lib/jvm/java-17-openjdk-amd64/bin/java \
  -Xmx4G -Xss8M \
  -cp vhdl-wrapper/src:vhdl-wrapper/bin:vhdl-wrapper/antlr-4.8-complete.jar \
  net.largest.riscv.vhdl.Main \
  -m Rocket64b2 \
  workspace/rocket64b2/system-dualv7.v \
  > workspace/rocket64b2/rocket.vhdl
```

---

## 4.3 Vivado 工程创建

### 4.3.1 生成入口 Tcl

`make vivado-project` 前会先生成：

```text
workspace/rocket64b2/system-dualv7.tcl
```

当前实例如下：

```tcl
set vivado_board_name dualv7
set xilinx_part xc7v2000tflg1925-1
set rocket_module_name Rocket64b2
set riscv_clock_frequency 40.0
set memory_size 0x40000000
cd [file dirname [file normalize [info script]]]
source ../../vivado.tcl
```

### 4.3.2 实际 Vivado 命令

`make vivado-project BOARD=dualv7 CONFIG=rocket64b2`
最终调用的是：

```bash
env XILINX_LOCAL_USER_DATA=no \
vivado \
  -mode batch \
  -nojournal \
  -nolog \
  -notrace \
  -quiet \
  -source workspace/rocket64b2/system-dualv7.tcl
```

### 4.3.3 `vivado.tcl` 实际做了什么

`../../vivado.tcl` 会：

1. 创建工程 `workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.xpr`
2. 加入源文件：
   - `rocket.vhdl`
   - `system-dualv7.v`
   - `uart.v`
   - `axi_sdc_controller.v`
   - `ethernet.v`
   - `ethernet-dualv7.v`
   - `mem-reset-control.v`
   - `fan-control.v`
3. 加入约束：
   - `board/dualv7/top.xdc`
   - `board/dualv7/sdc.xdc`
   - `board/dualv7/ddr3.xdc`
   - `board/dualv7/uart.xdc`
   - `board/dualv7/ethernet.xdc`
   - `board/timing-constraints.tcl`
4. source：
   - `board/dualv7/ethernet-dualv7.tcl`
   - `board/dualv7/riscv-2025.1.tcl`
5. 生成 block design
6. `make_wrapper`
7. 设置顶层 `riscv_wrapper`

---

## 4.4 Vivado 综合

当前工程通过生成 `make-synthesis.tcl` 来驱动综合。

等效 Tcl 内容为：

```tcl
set_param general.maxThreads 1
open_project workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.xpr
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs -jobs 1 synth_1
wait_on_run synth_1
```

对应的 Vivado 调用命令：

```bash
env XILINX_LOCAL_USER_DATA=no \
vivado \
  -mode batch \
  -nojournal \
  -nolog \
  -notrace \
  -quiet \
  -source workspace/rocket64b2/vivado-dualv7-riscv/make-synthesis.tcl
```

输出 DCP：

```text
workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/synth_1/riscv_wrapper.dcp
```

---

## 4.5 Vivado 实现和 bitstream

当前工程通过生成 `make-bitstream.tcl` 来驱动实现。

等效 Tcl 内容为：

```tcl
set_param general.maxThreads 1
open_project workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.xpr
reset_run impl_1
launch_runs -to_step write_bitstream -jobs 1 impl_1
wait_on_run impl_1
```

对应的 Vivado 调用命令：

```bash
env XILINX_LOCAL_USER_DATA=no \
vivado \
  -mode batch \
  -nojournal \
  -nolog \
  -notrace \
  -quiet \
  -source workspace/rocket64b2/vivado-dualv7-riscv/make-bitstream.tcl
```

bit 产物路径：

```text
workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit
```

---

## 4.6 生成 MCS

如果使用 `make bitstream`，在 `.bit` 成功后还会继续跑：

```tcl
open_project workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.xpr
write_cfgmem \
  -format mcs \
  -interface SPIx4 \
  -loadbit {up 0x0 workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit} \
  -file workspace/rocket64b2/dualv7-riscv.mcs \
  -force
```

对应调用命令：

```bash
env XILINX_LOCAL_USER_DATA=no \
vivado \
  -mode batch \
  -nojournal \
  -nolog \
  -notrace \
  -quiet \
  -source workspace/rocket64b2/vivado-dualv7-riscv/make-mcs.tcl
```

---

## 5. 当前推荐的实际使用方式

### 5.1 只想要 bit

```bash
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
cd ~/vivado-risc-v

make -j"$(nproc)" linux
make -j"$(nproc)" u-boot
make -j"$(nproc)" bootloader

make -j"$(nproc)" \
  workspace/rocket64b2/system-dualv7.v \
  BOARD=dualv7 CONFIG=rocket64b2

make \
  workspace/rocket64b2/rocket.vhdl \
  BOARD=dualv7 CONFIG=rocket64b2

make vivado-project BOARD=dualv7 CONFIG=rocket64b2

make MAX_THREADS=1 \
  workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit \
  BOARD=dualv7 CONFIG=rocket64b2
```

### 5.2 想连 `.mcs` 一起出

```bash
make MAX_THREADS=1 bitstream BOARD=dualv7 CONFIG=rocket64b2
```

### 5.3 长任务推荐后台运行

```bash
nohup bash -lc '
set -euo pipefail
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
cd ~/vivado-risc-v
make vivado-project BOARD=dualv7 CONFIG=rocket64b2
make MAX_THREADS=1 \
  workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit \
  BOARD=dualv7 CONFIG=rocket64b2
' >/tmp/build-rocket64b2.log 2>&1 &
```

---

## 6. 并行度说明

当前工程里有两个不同层面的“并行”：

### 6.1 外层 `make`

可以对 Linux / U-Boot / 某些普通文件目标使用：

```bash
make -j"$(nproc)" ...
```

### 6.2 Vivado 内部线程

Vivado 不是由 `make -j` 控制，而是由：

```make
MAX_THREADS ?= 1
```

控制，并被写进：

- `set_param general.maxThreads $(MAX_THREADS)`
- `launch_runs -jobs $(MAX_THREADS) ...`

当前 `Makefile` 原注释写得很明确：

```text
Multi-threading appears broken in Vivado.
It causes intermittent failures.
```

所以：

- **工程默认值是 `MAX_THREADS=1`**
- 如果你要主动尝试多线程，可以显式写：

```bash
make MAX_THREADS=8 bitstream BOARD=dualv7 CONFIG=rocket64b2
```

但这不是当前工程默认安全值。

---

## 7. 常见坑

### 7.1 `make verilog` 不存在

当前远端仓库没有 `verilog` 目标。不要再沿用历史任务里的写法。

### 7.2 `bitstream` 不等于只出 `.bit`

`make bitstream` 会继续出 `.mcs`。如果你只想检查实现结果，
直接打 `.bit` 文件目标更稳。

### 7.3 `.bit` 成功但 `.mcs` 失败

`write_cfgmem` 可能因为 `SPI_buswidth` 和 `SPIx4` 不一致失败。
此时 `.bit` 可能已经是可用的，不要把整个构建一概判死。

### 7.4 远端不要 `source ./env.sh`

当前 202 远端按我们已有验证，不依赖 `env.sh`。

### 7.5 Vivado 日志判断

仅看 `tee` 退出码不够，最好同时检查：

- `workspace/<CONFIG>/vivado-.../timestamp.txt`
- `*.runs/synth_1/runme.log`
- `*.runs/impl_1/runme.log`
- `riscv_wrapper_timing_summary_routed.rpt`
- `riscv_wrapper_drc_routed.rpt`
- 最终 `.bit` 文件是否存在

---

## 8. 可选：JTAG 启动 Linux

如果 bit 已经有了，想临时通过 JTAG 启 Linux：

```bash
make jtag-boot BOARD=dualv7 CONFIG=rocket64b2
```

它实际会调用：

```bash
env HW_SERVER_URL=tcp:localhost:3121 xsdb -quiet board/jtag-freq.tcl

env BITSTREAM=<bit路径> \
env HW_SERVER_URL=tcp:localhost:3121 \
xsdb -quiet board/jtag-boot.tcl
```

`board/jtag-boot.tcl` 的关键动作是：

1. 下载 bitstream
2. `dow -data` 下载 Linux `Image`
3. `dow -data` 下载 ramdisk
4. `dow -clear workspace/boot.elf`
5. 设置 `a0/a1/s0`
6. `con` 启动 CPU

---

## 9. 最短结论

如果只记三件事：

1. 远端环境用：
   ```bash
   source /tools/Xilinx/2025.1/Vivado/settings64.sh
   export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
   cd ~/vivado-risc-v
   ```
2. 当前工程**没有** `make verilog`，要改用实际文件目标或
   `make vivado-project`
3. Vivado 真正的核心命令分三步：
   - `vivado -source workspace/<CONFIG>/system-<BOARD>.tcl`
   - `vivado -source .../make-synthesis.tcl`
   - `vivado -source .../make-bitstream.tcl`
