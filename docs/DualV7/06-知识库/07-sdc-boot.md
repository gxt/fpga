# §07 SDC/SD Boot

## §07.1 DualV7 SD 硬件事实

DualV7 J8 子卡提供 MMC1/TF 卡槽，**已验证存在且可操作**。

| 信号 | J8 Pin | FPGA Pin | Bank | IO 电平 | 方向 | XDC |
|------|--------|----------|------|---------|------|-----|
| MMC1CLK | J8-55 | AT37 | 12 | LVCMOS18 | FPGA→Card | IOB TRUE |
| MMC1CMD | J8-53 | AT38 | 12 | LVCMOS18 | Bidir | IOB TRUE |
| MMC1D0 | J8-45 | BA43 | 11 | LVCMOS18 | Bidir | IOB TRUE |
| MMC1D1 | J8-47 | AY43 | 11 | LVCMOS18 | Bidir | IOB TRUE |
| MMC1D2 | J8-49 | AW44 | 11 | LVCMOS18 | Bidir | IOB TRUE |
| MMC1D3 | J8-51 | AW43 | 11 | LVCMOS18 | Bidir | IOB TRUE |
| TFCD | J8-21 | BA39 | 11 | LVCMOS18 | Card→FPGA | 无 IOB |

### 未确认项

- raw `sdio_cd` 极性和板级上拉仍未完全坐实；当前只验证了
  Linux `sdc_get_cd()` 的 software workaround 可行
- CLK/CMD/DAT 是否有板上外部上拉（SD spec 要求 10-100kΩ）
- TF 卡槽 VDD 是否由 FPGA 控制供电（原理图需查阅）

---

## §07.2 SD Controller 接线

| 属性 | 值 |
|------|----|
| AXI-Lite 地址 | `0x60000000` |
| BD 连接 | `IO/io_axi_s/M01_AXI → SD/S_AXI` |
| DMA master | `SD/M_AXI → io_axi_m/S00_AXI → RocketChip/DMA_AXI4` |
| 中断 | `SD/interrupt → xlconcat_0/In1` → IRQ 2 |
| `capabilies_reg` | `0x0001`（仅 bit0=1） |
| `sdio_card_detect_level` | 默认 1 |
| `sdio_reset` | **BD 无此端口**，控制器内部默认 `sdio_reset=0` → SD clock 始终使能 |
| `cap-mmc-hw-reset` in DTS | 无（合理） |

---

## §07.3 BootROM SD 启动链

标准 `bootrom/bootrom.c` 支持 SD 启动：
1. `ini_sd()` — 软件复位 + CMD0/CMD8/ACMD41/CMD2/CMD3/CMD7 初始化
2. `f_mount(&fatfs, "", 1)` — 挂载 FAT32
3. `f_open("BOOT.ELF")` — 打开 ELF
4. 解析 ELF 段 → 写入 DDR (`0x80000000+`) → 跳转入口

恢复方法：删除或移走 `board/dualv7/bootrom.inc`，Makefile 自动使用默认 `bootrom.c`。

---

## §07.4 032x Smoke / 033x Trace 测试结果

### 032x Smoke（硬件修复前）

| 检查项 | 结果 |
|--------|------|
| `RISC-V 64, Boot ROM V3.9` | ✅ CPU/DDR/UART 正常工作 |
| `Cannot access SD` | ❌ Timeout — CMD0 无响应 |
| `Cannot mount SD` | ❌ 必然结果 |
| `BOOT.ELF` 加载 | ❌ 未到达 |

日志：`RISC-V 64, Boot ROM V3.9` → `Cannot access SD: Timeout`（循环重试）

### 033x Trace（硬件修复后）

| Step | CMD | Arg | st | r0 | 结果 |
|------|-----|-----|----|----|------|
| SDDBG0 | init | - | - | cap=0x2201 cd=0x08 | 初始状态 |
| 1 | CMD0 (0) | 0 | 0x01 CC | 0 | ✅ Go idle |
| 2 | CMD8 (8) | 0x1AA | 0x01 CC | 0x1AA | ✅ 电压匹配 |
| 3 | ACMD41 (169) | 0x40300000 | 0x01 CC | 0xc0ff8000 | ✅ OCR, CCS=1 |
| 4 | CMD2 (2) | 0 | 0x01 CC | 0x03534453 | ✅ CID |
| 5 | CMD3 (3) | 0x12340000 | 0x01 CC | var | ✅ RCA |
| 6 | CMD7 (7) | var | 0x01 CC | 0x00000700 | ✅ 选中 |
| 7 | ACMD6 (134) | 0 | 0x01 CC | 0x00000920 | ✅ 1-bit bus |
| 8 | CMD16 (16) | 0x200 | 0x01 CC | 0x00000900 | ✅ 512B block |

8/8 全部通过 → BootROM → `BOOT.ELF` → **OpenSBI → U-Boot → Linux 启动**。

两次独立上板测试（不同 SD 卡，RCA 分别为 0x5048 / 0xaaaa），均通过。

### 结论

**硬件问题导致 032x SD init Timeout**。用户更换硬件后，SOC 侧 bootrom.c 和 SD controller RTL 均无问题。根因不在 FPGA/软件侧。

### 关键寄存器值（033x 确认）

| 寄存器 | 值 | 含义 |
|--------|----|------|
| `capability` | `0x00002201` | bit0=4-bit, bit9=0x200, bit13=0x2000 |
| `card_detect` | `0x08` | bit3=CARD_REMOVE_INT_REQ（插拔中断） |
| `control` | `0` (init), `0` (after CMD7) | SD 4-bit 未使能，SD reset 未使能 |
| `clock_divider` | `0x7c` (init), `0x03` (high-speed) | init ~806kHz, high-speed 25MHz |



## §07.6 Genesys2 vs DualV7 SDC 对比

| 维度 | Genesys2 | DualV7 | 风险 |
|------|----------|--------|------|
| SD IO 电平 | LVCMOS33 | LVCMOS18 | J8 子卡电平匹配需确认 |
| `sdio_reset` | ✅ 有(P28) | ❌ 无 | 无硬件复位 |
| `sdio_card_detect_level` | 0 (CD=0=有卡) | 默认 1 (CD=1=有卡) | 仍是后续硬件验证方向 |
| `capabilies_reg` | 更大 | `0x0001` | 缺 HW reset capability bit |
| controller 地址 | `0x60000000` | `0x60000000` | ✅ |
| DMA 接法 | 同 | 同 | ✅ |
| XDC IOB | CLK+CMD+DAT | CLK+CMD+DAT | ✅ |
| DRC (sdio_*) | 通过 | 通过 | ✅ |

## §07.6 已验证 CONFIG

| CONFIG | 核心 | OpenSBI HART Count | Linux CPU | LUT | WNS | SDC→BootROM→OpenSBI→U-Boot→Linux | rootfs |
|--------|------|--------------------|-----------|-----|-----|------|--------|
| `rocket64b2` | Big Rocket | 32 | **2** | 6.90% | **+0.099ns** ✅ | ✅ 全链路通过 | ⚠️ 旧内核落 initramfs；Debian 未复测 |
| `rocket64z1` | MegaBoom Z1 | 32 | **1** | 35.71% | **-9.83ns** ❌ | ✅ 全链路通过 | ⚠️ 旧内核落 initramfs；Debian 未复测 |
| `rocket64z2m` | 2×MegaBoom Z1 | 32 | **2** | **67.94%** | **-0.755ns** ❌ | ✅ 全链路通过 | ✅ patched kernel + `sdc_get_cd` workaround 后启动 Debian 11 |

### §07.6.1 关键发现

**b2 vs z1 总线差异**：
- b2: `WithEdgeDataBits(64)` → 64-bit 三总线直连 MIG
- z1/z2m: `WithEdgeDataBits(256)` → 256-bit → SmartConnect 转 64-bit → MIG（见 §06.7）

**z1 Timing 违例根因**（WNS=-9.8ns）：
- 全部 14 个失败端点在 `phy_rx_clk` 域（25MHz）
- `mii_rxd[*]` input_delay=30ns + route=23ns > 40ns 周期
- 不影响 SDC 启动和 DDR 操作，仅影响以太网接收可靠性

**z2m Timing**：WNS=-0.755ns（6 端点），推测同样在 MII 路径，比 z1 大幅改善

**早期 rootfs / initramfs 现象**：
- 三版早期测试都能到内核 + initramfs
- 当时表象是落入 `(initramfs)`，一度怀疑 root UUID / SD 镜像问题
- 该假设已在 037x 调试中排除：本地挂载确认 UUID 匹配
- 最终收敛到的已验证软件根因是 Linux `sdc_get_cd()` 返回 0，
  导致 MMC 根本没有完成枚举
- 在 `rocket64z2m` 上，patched kernel + `sdc_get_cd` workaround
  已经验证可启动 Debian 11

**地址空间差异**：
- b2/z1: PMP Address Bits=32（4GB 寻址）
- z2m: PMP Address Bits=36（256GB 寻址，WithExtMemSize）

## §07.7 SDC Kernel 驱动调试完整过程

> 任务：037x，2026-05-11~12，deepseek
> 最终状态：✅ Debian 11 成功启动

### §07.7.1 最终根因

**当前已验证的软件根因：Linux `sdc_get_cd()` 返回 0。**

DualV7 并不缺 `sdio_cd` 这根线；`TFCD -> sdio_cd` 已存在。
当前被验证的失败路径是：驱动 `sdc_get_cd()` 从
`host->regs->card_detect` 取值后返回 0（无卡）→ MMC 核心跳过
`mmc_rescan` → 永远不发送 SD 命令 → 无 `mmcblk0` 设备
→ rootfs 挂载失败。

**修复**（1 行）：
```c
// fpga-axi-sdc.c: sdc_get_cd()
static int sdc_get_cd(struct mmc_host * mmc) {
    return 1; /* card always present */
}
```

### §07.7.2 错误前提修正

调试过程中澄清的误解：

| 初始假设 | 实际 |
|---------|------|
| SD 卡 UUID 不匹配 | UUID 完全匹配（本地挂载确认） |
| 预编译内核不含 `fpga-axi-sdc` 驱动 | 驱动确实不在旧内核中，但自编译后仍失败 |
| DTB `max-frequency` 过高 | 与频率无关——probe 后连 CMD0 都没发 |
| 需要 `broken-cd` | 加上后更差——`mmc_rescan` 直接跳过 |
| `io-bus` address-cells 不匹配 | 确实不匹配，修复后 probe 被调用，但仍有后续问题 |
| BusyBox/initramfs 问题 | 与 initramfs 无关——设备节点都没创建 |

### §07.7.3 调试时间线

#### 阶段 1：表象阶段——"rootfs UUID 缺失"
- **现象**：三版 CONFIG 均落入 initramfs shell
- **假设 1**：SD 卡分区 UUID 与 extlinux.conf 不匹配
- **验证 1**：本地 `mount /dev/sdb2` → UUID 完全匹配 → **排除**
- **假设 2**：预编译内核不含 SD 卡驱动
- **验证 2**：`strings` 确认旧内核有驱动字符串；但内核 dmesg 无任何 MMC 消息

#### 阶段 2：内核重编译——驱动 probe 是否被调用
- **动作**：本地编译 linux 5.15.4，应用 patches，修复 API 兼容问题
- **验证 3**：自编译内核启动，仍无 MMC 消息 → probe 根本没被调用

#### 阶段 3：DTB 结构问题——OF 平台设备创建
- **假设 3**：Chisel DTS + bootrom.dts `cat` 合并导致 address-cells 不匹配
- **发现**：Chisel DTS root 有 `#address-cells=<2>`，bootrom.dts `io-bus` 用 `<1>`
  且 `ranges` 为空 → dtc 无法正确翻译 → OF 不创建 MMC platform device
- **修复 3**：将 io-bus 和子节点全部改为 `<2>` + 2-cell reg
- **验证 4**：probe 被调用了！`AXI-SDC: probe enter` ✅

#### 阶段 4：probe 成功但无卡检测——在哪一步中断
- **假设 4a**：`io-bus` 的 `simple-bus` 枚举失败
- **假设 4b**：`mmc_of_parse()` 解析 DTB 属性失败
- **假设 4c**：`mmc_add_host()` fail
- **假设 4d**：`mmc_rescan()` 调度后不执行
- **方法**：驱动内加探针（KERN_ERR printk）→ probe 全链路成功
- **方法**：MMC 核心加探针（KERN_EMERG printk）→ 追踪 `mmc_rescan_try_freq`

#### 阶段 5：MMC 核心路径追踪（关键突破）
- **验证 5**：
  ```
  MMC: RESCAN-START    ✅   mmc_rescan 跑了
  MMC: CHECK-bus_ops   ✅   bus_ops 检查通过
  MMC: CLAIM2-DONE     ✅   claim_host 成功
  MMC: pre-getcd       ←   卡在这里！getcd != NULL 且返回 0
  ```
- **发现**：`host->ops->get_cd = 0xffffffff804b4ee2`——驱动有 `sdc_get_cd`
- **验证**：`nm vmlinux | grep 804b4ee2` → `sdc_get_cd`——是 driver 自己的回调！
- **根因**：`sdc_get_cd` 读 `card_detect` 寄存器 → 返回 0 → `mmc_rescan`
  在 `get_cd` 检查处 goto out → 跳过所有 SD 命令

#### 阶段 6：修复
- **修复**：`sdc_get_cd()` 改为 `return 1`
- **验证**：
  ```
  MMC: ENTER-LOOP                     ← for 循环到达
  mmc0: new high speed SDHC card      ← SD 卡识别
  mmcblk0: mmc0:aaaa SC16G 14.8 GiB   ← 块设备创建
  Welcome to Debian GNU/Linux 11       ← 启动成功！
  ```

### §07.7.4 经验教训

1. **逐级探针是调试内核驱动的唯一可靠方法**——从表象到根因经历了
   6 个阶段、10+ 次假设-验证循环

2. **KERN_EMERG 不会被过滤**——当 `loglevel=8` 都看不到消息时，
   可能是代码路径根本没走到，而不是被过滤

3. **OF 平台设备创建依赖 address-cells 一致**——Chisel DTS 和
   bootrom.dts 的 `cat` 合并会引入不一致，UART 因 `earlycon` 特殊
   路径而工作，不意味着其他设备也能正常

4. **driver 的回调比预想的多**——最初检查 ops 时漏看了 `.get_cd`，
   实际驱动确实有 `sdc_get_cd`，它读硬件寄存器作为卡检测依据

5. **控制器 `card_detect` 语义不能直接当“卡在位”使用**——033x
   已证明该寄存器不是 raw `sdio_cd` 引脚电平；U-Boot /
   bare-metal 能用 SD 卡，不代表 Linux `sdc_get_cd()`
   这样读取后就能正确判断“卡在位”

6. **旧的日志混入新日志会误导判断**——早期测试中旧内核的 CMD13
   "card removed too slowly" 消息被误读为新内核的行为

### §07.7.5 硬件卡检测：待验证的跨板假设

RTL 默认 `sdio_card_detect_level = 1`（HIGH = 卡在位）。
BD TCL 可覆盖；XDC 可加 PULLUP；硬件可能带外部上拉。

| 板子 | TCL override | XDC PULLUP | 硬件上拉 | 结果 |
|------|-------------|-----------|---------|------|
| **vc707** | 无（默认 1） | 无 | 未坐实 | ✅ 正常 |
| **genesys2** | **`0`**（显式） | 无 | — | ✅ 正常 |
| **dualv7** | 无（默认 1） | 无 | 未坐实 | 当前 Linux 需 software workaround |

当前能确认的事实：
1. genesys2 TCL 显式设置了 `sdio_card_detect_level=0`
2. dualv7 当前 board 文件里没有看到对应 override / `PULLUP TRUE`

因此 dualv7 后续值得验证的硬件方向是：
1. BD TCL 缺 `CONFIG.sdio_card_detect_level {0}`
2. XDC 缺 `PULLUP TRUE` on `sdio_cd`

但这两条目前仍属于**待验证假设**，不是本轮已坐实的最终根因。

**软件 workaround**（已验证可用）：
- `sdc_get_cd()` 改为 `return 1`
  - `rocket64z2m` 已验证可启动 Debian 11

**硬件修复方向**（待单独 bit / 上板验证）：
- RTL `sdio_card_detect_level` 1→0
- XDC 加 `PULLUP TRUE` on BA39
