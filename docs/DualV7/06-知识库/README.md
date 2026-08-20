# 知识库索引

| 文件 | 主题 |
|------|------|
| `01-project-structure.md` | 仓库结构、board 文件布局、submodule 说明 |
| `02-build-commands.md` | 构建命令、环境变量、Vivado 路径 |
| `03-board-dualv7.md` | DualV7 板卡硬件规格、引脚约束、PHY 信息 |
| `04-ethernet.md` | 以太网 IP、MII 接口、调试记录 |
| `05-uart.md` | UART 实现对比（vivado-risc-v vs Chipyard）、CTS 修复、推荐方案 |
| `06-bus-architecture.md` | 总线架构对比（TileLink vs AXI4）、MEM/IO/DMA 分工 |
| `07-sdc-boot.md` | SDC/SD Boot：硬件事实、控制器接线、smoke 测试结果、排查方向 |
| `08-dual-fpga.md` | DualV7 双 FPGA 架构：F1/F2 硬件资源、Inter-FPGA 直连、Shared I/O、可行路径 |
| `09-boom-stop.md` | boom_stop 接入验证：纯替换不可行，API 代际差异分析 |
| `10-changelog.md` | 任务变更记录 |
| `11-boom-version-alignment.md` | BOOM 版本对齐方案：Chipyard 1.13.0 适配策略（042x 调研结论）|
| `12-knowledge-graph-method.md` | 知识图谱抽取方法：实体/关系/证据/推断的记录规范，以及外围硬件环境、旧文档、命令式实验的证据纪律 |
| `13-network-debug-postmortem.md` | 网络调试复盘：本轮走弯路的主要原因、已证伪推断、后续标准调试顺序 |
| `14-sshd-rootfs-research.md` | sshd Rootfs 技术路线调研（071x 结论）：Alpine/Buildroot/Debian/Dropbear 4 路线对比，核 有行不、熵坑 |

| `15-mega-dualcore-cache-coherence.md` | Mega 双核 Cache Coherence 分析：TileLink 广播协议、L1 MSHR/ProbeUnit、L2 InclusiveCache、TLBroadcast coherence manager、权限状态机 toN/toB/toT |
| `16-closed-work-and-current-baseline.md` | 已收口工作与当前基线：BOOM-stop、Mega/z2m 工作闭环，当前 release/bit/流程文档入口，以及新 DualV7 工作默认起点 |
| `21-single-v7-porting.md` | SingleE V7 移植基线：与 DualV7 的关系、首轮只做板载时钟/复位/LED/JTAG smoke、后续 J8/J7/DDRx 迁移顺序 |

引用格式：**`§文件号.章节号`**（如 `§03.2`），不要写行号。
