# vivado-risc-v 编译流程（简版）

本文档只保留**在正确环境下编译出 bit** 的最核心流程。  
目标板卡：`dualv7`  
默认配置：`rocket64b2`

---

## 1. 登录并初始化环境

```bash
ssh zzx@192.168.200.202
source /tools/Xilinx/2025.1/Vivado/settings64.sh
export XILINXD_LICENSE_FILE=/home/zzx/vivado/Xilinx_lic/vivado_lic2037.lic
cd ~/vivado-risc-v
```

---

## 2. 一条命令直接编译出 bit

```bash
make BOARD=dualv7 CONFIG=rocket64b2 MAX_THREADS=$(nproc) \
  workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit
```

这条命令会自动串起下面这些步骤：

- 生成 `system.dts`
- 生成 `bootrom.img`
- 生成 FIRRTL / Verilog
- 生成 `rocket.vhdl`
- 创建 Vivado 工程
- 跑 `synth_1`
- 跑 `impl_1`
- 生成 `riscv_wrapper.bit`

---

## 3. 分步执行版本

如果你想分开跑，按下面顺序：

### 3.1 生成 HDL

```bash
make -j"$(nproc)" BOARD=dualv7 CONFIG=rocket64b2 \
  workspace/rocket64b2/system-dualv7.v

make BOARD=dualv7 CONFIG=rocket64b2 \
  workspace/rocket64b2/rocket.vhdl
```

### 3.2 创建 Vivado 工程

```bash
make BOARD=dualv7 CONFIG=rocket64b2 vivado-project
```

### 3.3 生成 bit

```bash
make BOARD=dualv7 CONFIG=rocket64b2 MAX_THREADS=$(nproc) \
  workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit
```

---

## 4. Vivado 实际执行入口

### 4.1 创建工程时

`make vivado-project` 实际会调用：

```bash
env XILINX_LOCAL_USER_DATA=no vivado \
  -mode batch -nojournal -nolog -notrace -quiet \
  -source workspace/rocket64b2/system-dualv7.tcl
```

### 4.2 综合时

Vivado 实际执行的 Tcl 核心内容：

```tcl
open_project workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.xpr
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs -jobs <MAX_THREADS> synth_1
wait_on_run synth_1
```

### 4.3 实现并生成 bit 时

Vivado 实际执行的 Tcl 核心内容：

```tcl
open_project workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.xpr
reset_run impl_1
launch_runs -to_step write_bitstream -jobs <MAX_THREADS> impl_1
wait_on_run impl_1
```

---

## 5. 产物位置

最终 bit 文件：

```text
workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit
```

中间几个常用文件：

```text
workspace/rocket64b2/system.dts
workspace/rocket64b2/system-dualv7.v
workspace/rocket64b2/rocket.vhdl
workspace/rocket64b2/system-dualv7.tcl
workspace/rocket64b2/vivado-dualv7-riscv/dualv7-riscv.xpr
```

---

## 6. 常用变体

### 6.1 换配置

例如 `rocket64z1`：

```bash
make BOARD=dualv7 CONFIG=rocket64z1 MAX_THREADS=$(nproc) \
  workspace/rocket64z1/vivado-dualv7-riscv/dualv7-riscv.runs/impl_1/riscv_wrapper.bit
```

### 6.2 顺带生成 `.mcs`

```bash
make BOARD=dualv7 CONFIG=rocket64b2 MAX_THREADS=$(nproc) bitstream
```

这会在出 `.bit` 之后继续生成：

```text
workspace/rocket64b2/dualv7-riscv.mcs
```

