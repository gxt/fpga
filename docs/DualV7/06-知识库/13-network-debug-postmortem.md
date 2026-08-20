# §13 网络调试复盘

本文件只总结一件事：DualV7 网络 bring-up 这条线，哪些结论已经坐实，
哪些地方之前明显走了弯路，后面应该怎么更快收敛。

---

## §13.1 已坐实的事实链

### 1. Linux 网络本身是通的

当前已经坐实：

- Linux 驱动能 probe `eth0`
- Linux IPv4 数据面可用
- Linux 能：
  - `ping`
  - 挂载 `NFS root`
  - 进入 BusyBox 用户态

这意味着：

- `bit` 到 PHY/子卡/交换机/主机这一整条链**不是全局失效**
- 后续再遇到 U-Boot 网络异常，默认先怀疑 **U-Boot 软件路径**

### 2. U-Boot 网络问题主要是软件，不是 BootROM

已经坐实的关键点：

- 同一颗 bit，换不同 `boot.elf`，U-Boot 网络行为会变
- `boot-r2.elf` 之后：
  - `ping` 成功
  - `tftpboot` 成功
  - 可进入 Linux NFS root

所以：

- 后续不要再把网络问题优先压给 BootROM
- 对网络 bring-up，真正的版本锁定对象是：
  - `bit`
  - `boot.elf`
  - `Image`
  - `rootfs`

### 3. U-Boot RX ring 是这轮最关键的软件根因

当前已坐实的修补点：

1. `start()` 不能把 RX ring 填满  
2. `recv()` 消费后必须回补 RX buffer

这两处修完后，U-Boot `ping`/`tftpboot` 成功。

因此：

- 这轮问题主因不是 cache 主因
- 也不是“网络外围硬件整体不可信导致完全不通”
- 是 **U-Boot `vivado_mii` 的 RX ring 维护缺陷**

---

## §13.2 这轮明确走过的弯路

### 弯路 1：没有先锁定产物四元组

前期反复混用了不同的：

- bit
- `boot.elf`
- kernel
- rootfs

结果是：

- 看起来像“同一问题反复漂移”
- 实际上是在比较不同软件组合

后续规则：

> 任何网络结论都必须显式绑定  
> `bit + boot.elf + Image + rootfs`

### 弯路 2：把 U-Boot 结果过早外推成硬件结论

前期一度把：

- `U-Boot ping` 不通
- `No ethernet found`
- 抓包没看到包

外推成：

- `PHY/外围/子卡/交换机` 可能整体有问题

但后续 Linux IPv4、Linux NFS、BusyBox 都跑通了。

后续规则：

> U-Boot 不通，只能先说明 **U-Boot 路径有问题**  
> 不能直接推出“硬件全局有问题”

### 弯路 3：抓包窗口没有对齐命令时刻

最典型的一次误判是把结果写成 `no-wire`。

真实问题是：

- `tcpdump` 太早启动
- 抓包窗口太短
- 在 U-Boot 真正执行 `ping` 前就结束了

后续规则：

> 抓包必须和 `ping` / `tftpboot` / `booti` 的**实际发生时刻对齐**

### 弯路 4：过早把问题压给 BootROM

后来已经证明：

- 网络行为对 `boot.elf` 版本高度敏感
- 不依赖 BootROM 的 JTAG + U-Boot 路径完全可复现

后续规则：

> 网络 bring-up 默认走  
> `JTAG bit + boot.elf -> U-Boot -> TFTP/NFS`

### 弯路 5：把大脚本当成调试流程本身

前期 `py` 脚本有价值，但也带来了一个问题：

- 执行者能“跑通脚本”
- 但不一定知道每一步到底在验证什么

这在：

- U-Boot `ping`
- NFS root
- BusyBox bring-up

阶段都带来过噪音。

后续规则：

> runbook 必须先是**逐步命令流程**  
> 脚本只能是 helper，不是唯一入口

### 弯路 6：没有把 host 服务当作图谱实体

前期多次出现：

- `dnsmasq` / `tftpd-hpa` 混淆
- host 上 NFS server 条件未满足
- 导出目录和实际 rootfs 路径不一致

后续规则：

> `TFTP 服务`、`NFS export`、`主机 IP`、`交换机拓扑`
> 都必须进入知识图谱

### 弯路 7：没有及时把“外围环境不可信”写成一等规则

本项目里，默认不可信的不是只有 FPGA 内部逻辑，还包括：

- daughtercard
- RJ45/磁性器件/PHY 外围
- USB-UART/JTAG 链路
- 对端主机网卡
- 交换机

后续规则：

> 每轮实验都要记录：  
> 本轮用的是哪块板、哪条网线、哪个主机口、哪个 TFTP/NFS 服务

---

## §13.3 后续标准调试顺序

后面网络问题一律按这条顺序收敛：

1. **锁定产物四元组**
   - `bit`
   - `boot.elf`
   - `Image`
   - `rootfs`

2. **锁定本地环境**
   - UART
   - `hw_server`
   - `xsdb target`
   - host IP
   - TFTP/NFS 服务

3. **先分层，不跨层**
   - U-Boot `ping`
   - U-Boot `tftpboot`
   - Linux `eth0` probe
   - Linux IPv4
   - Linux NFS root

4. **先收证据，再下推断**
   - UART
   - `tcpdump`
   - host 服务日志
   - 驱动 instrumentation

5. **优先比较软件路径，不要先比较“感觉”**
   - 同 bit 不同 `boot.elf`
   - 同 `boot.elf` 不同 rootfs
   - 同主机服务不同脚本入口

---

## §13.4 当前推荐基线

### 单核 Rocket 基线

- `dualv7-r2-uboot-tftp-nfs`
- `dualv7-r2-hotfix`

用途：

- U-Boot TFTP 拉起内核
- Linux NFS root
- `REALCHECK hold`

### 双核 z2m 基线

- `dualv7-r3-z2m-busybox-netboot`

用途：

- 双核 bit
- U-Boot 网络引导
- BusyBox NFS root

后续如果不是在做 timing 收敛，默认从 `r3` 起步。
