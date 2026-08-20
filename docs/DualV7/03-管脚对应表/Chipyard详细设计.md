# Chipyard项目详细设计

## 项目目标
- 使用Chipyard 1.8.0及以上版本
- 在S2C Dual Virtex-7 TAI LM平台实现并运行Linux
- 核心配置：SmallBoomConfig
- 集成外设接口：DDR3、SPI、UART、USB、以太网
- FPGA综合工具：Vivado

## 目标平台与器件
### FPGA平台
- 平台：S2C Dual Virtex-7 TAI LM
- FPGA芯片型号：XC7V2000TFLG1925
- 内存条：DDR3 SO-DIMM

### 外设与PHY
- USB PHY：USB3318
- 网络PHY：KSZ8081MNX
- SPI Flash：W25Q32FV

## 系统功能范围
### 处理器与SoC
- 处理器核：BOOM（SmallBoomConfig）
- 运行目标：Linux
- 版本要求：Chipyard >= 1.8.0

### 存储与启动
- 外部存储：DDR3 SO-DIMM作为主存
- 启动介质：SPI Flash（W25Q32FV）
- 启动流程：BootROM或Bootloader从SPI Flash加载后进入Linux引导

### 外设功能
- UART：系统调试与控制台输出
- USB：通过USB3318 PHY实现USB连接
- 以太网：通过KSZ8081MNX PHY实现以太网连接
- SPI：连接SPI Flash用于启动与存储

## 设计实现要点
### Chipyard配置
- 使用SmallBoomConfig生成RTL与SoC集成
- 保持与目标FPGA资源匹配，避免超出资源与时序限制

### 外设集成策略
- DDR3：对接板卡DDR3 SO-DIMM，使用Chipyard/FMC DDR控制器方案
- SPI：连接W25Q32FV，配置为启动介质
- UART：作为主调试通道与Linux控制台
- USB：连接USB3318 PHY，接口模式需匹配板卡硬件定义
- 以太网：连接KSZ8081MNX PHY，接口模式需匹配板卡硬件定义

### FPGA实现要点
- 目标器件：XC7V2000TFLG1925
- 工具链：Vivado
- 约束：依据板卡硬件手册与管脚表完成时钟、IO与接口约束

## 系统架构设计
### 顶层结构
- Chipyard生成SoC：SmallBoomConfig为核心
- 片上互联：Chipyard默认互联结构，外设与内存挂接在系统总线
- 外部接口：DDR3、SPI Flash、UART、USB PHY、以太网PHY

### 启动与运行流程
1. FPGA上电与复位释放
2. BootROM或Bootloader初始化外设与时钟
3. 从SPI Flash加载启动镜像或引导程序
4. 初始化DDR3并加载Linux镜像
5. 通过UART输出Linux启动日志

### 软件栈与工件
- Bootloader：负责DDR初始化与Linux镜像加载
- Linux镜像：内核、设备树、根文件系统
- 设备树：描述DDR、SPI、UART、USB、以太网硬件节点

## 接口与时钟规划
### 时钟规划
- 系统时钟源：6对可编程差分时钟源（0.16~710MHz），另有6对差分SMB时钟输入与2个单端晶振座
- DDR参考时钟：支持DDR3-800/1066/1333/1600（400/533/667/800MHz，CL=6/7/9/11）
- USB PHY时钟：REFCLK 13MHz，ULPI CLKOUT 60MHz
- 以太网PHY时钟：KSZ8081MNX参考时钟25MHz，RMII参考时钟50MHz

### 复位规划
- 全局复位：由板卡复位源控制
- 外设复位：与PHY和控制器复位序列匹配

## 约束与引脚规划
### 约束输出清单
- 系统时钟输入引脚与频率
- DDR3 SO-DIMM接口引脚与时序约束
- SPI Flash引脚与片选
- UART TX/RX引脚
- USB PHY接口引脚与时序
- 以太网PHY接口引脚与时序

### 引脚来源
- J8/J9/J10插座管脚表
- Dual V7 Hardware Reference Manual

### 接口模式确认清单
- USB3318与FPGA连接信号列表与方向
- KSZ8081MNX与FPGA连接信号列表与方向
- SPI Flash引脚与片选绑定关系
- DDR3地址/数据/控制信号在J8/J9/J10的分配
- UART TX/RX引脚在J8/J9/J10的分配

### 约束与引脚输出清单
- XDC约束目标清单：系统时钟、DDR3、SPI、UART、USB、以太网
- IO电压Bank分配与约束来源
- 复位信号与时序约束要求

### 软件与镜像准备清单
- Bootloader类型与获取方式
- Linux镜像构建方式与版本
- 设备树生成方式与外设节点清单
- 启动介质镜像布局与烧录方法

## 验证与运行目标
- 验证Linux引导链路可用
- UART控制台可用，作为内核日志输出通道
- DDR3稳定读写
- SPI Flash可读写，满足启动需求
- 以太网链路建立并可进行网络通信
- USB链路建立并可被系统识别

## 工程流程与交付物
### 关键构建命令
- 生成核心：make CONFIG=SmallBoomConfig

### 交付里程碑
- RTL生成与外设集成完成
- FPGA实现与时序收敛
- Linux启动并通过串口输出日志
- DDR/SPI/UART/USB/以太网基础功能验证

### 生成与实现流程
- Chipyard生成RTL与SoC集成
- Vivado工程创建与约束导入
- 综合网表与时序检查
- Bitstream生成与板卡下载

### 交付物清单
- RTL与生成配置
- 约束文件与引脚映射
- Bootloader与Linux镜像
- 设备树与启动脚本
- 启动参数与烧录说明

## 关键待确认项
### 硬件参数
- 板卡系统时钟：6对可编程差分时钟源（0.16~710MHz），6对SMB差分时钟输入，2个单端晶振座
- DDR3 SO-DIMM：J14支持最大8GB，204-pin，容量1/2/4/8GB，VDD/VDDQ 1.5V或1.35V
- USB3318：ULPI 1.8V~3.3V，REFCLK 13MHz，CLKOUT 60MHz，VBAT 3.1~5.5V
- KSZ8081MNX：VDDIO_3.3/VDDA_3.3=3.135~3.465V，参考时钟25MHz
- SPI Flash：W25Q32FV，32M-bit，VCC 2.7~3.6V，4KB扇区
- UART电平标准：板卡手册未标注

### 设计约束
- 目标时钟域与跨域策略
- PHY接口时序约束策略
- IO电压与Bank分配

## 资料清单与用途
### 资料与路径
- 设计说明：Chipyard-doc/ai设计说明.txt
- 板卡/外设资料目录：Chipyard-doc/AI相关资料/

### 板卡与接口资料
- Dual V7 Hardware Reference Manual.pdf：板卡总体结构、时钟、IO、接口说明
- V7_FPGA_DDR3内存条.pdf：DDR3 SO-DIMM接口与参数
- S2C-V7-J8-EMMC插座管脚对应表20230801.xlsx：板卡J8插座管脚定义
- S2C-V7-J9-BIOS插座管脚对应表20201012.xlsx：板卡J9插座管脚定义
- S2C-V7-J10-PCI插座管脚对应表20200925.xlsx：板卡J10插座管脚定义

### 外设芯片资料
- USB3318.pdf：USB PHY接口、电气与时序要求
- KSZ8081MNX-RNB Data Sheet v1.0.pdf：以太网PHY接口与时序
- w25q32fv_3v3.pdf：SPI Flash容量、电气与命令集

## 已核对参数表（PDF）
### Dual V7 Hardware Reference Manual
| 参数 | 数值 | 说明 |
| --- | --- | --- |
| 可编程差分时钟源 | 6对，0.16~710MHz | 全局时钟资源 |
| 差分SMB时钟输入 | 6对 | 外部时钟输入 |
| 差分反馈时钟 | 6对 | 来自用户FPGA |
| 单端晶振座 | 2个 | 单端时钟 |
| DDR3 SO-DIMM插槽 | J14，最大8GB | DDR3 SO-DIMM |

### V7_FPGA_DDR3内存条
| 参数 | 数值 | 说明 |
| --- | --- | --- |
| VDD/VDDQ | 1.5V（SSTL） | DDR3标准电压 |
| 低压VDD | 1.35V | 1.35V产品可1.5V运行 |
| SODIMM容量 | 1/2/4/8GB | 204-pin DDR3 SODIMM |

| 速度等级 | 时钟频率 | CL | tRCD | tRP |
| --- | --- | --- | --- | --- |
| DDR3-800 | 400MHz | 6 | 6 | 6 |
| DDR3-1066 | 533MHz | 7 | 7 | 7 |
| DDR3-1333 | 667MHz | 9 | 9 | 9 |
| DDR3-1600 | 800MHz | 11 | 11 | 11 |

### USB3318
| 参数 | 数值 | 说明 |
| --- | --- | --- |
| REFCLK | 13MHz | 参考时钟输入 |
| ULPI接口电压 | 1.8V~3.3V | VDDIO |
| CLKOUT | 60MHz | ULPI时钟输出 |
| VBAT | 3.1~5.5V | 供电范围 |
| VDD18 | 1.8V | 外部供电 |
| VDD33 | 3.3V | 片上LDO输出 |

### KSZ8081MNX
| 参数 | 数值 | 说明 |
| --- | --- | --- |
| VDDIO_3.3/VDDA_3.3 | 3.135~3.465V | 3.3V供电范围 |
| VDDIO_2.5 | 2.375~2.625V | 2.5V供电范围 |
| VDDIO_1.8 | 1.710~1.890V | 1.8V供电范围 |
| 参考时钟 | 25MHz | KSZ8081MNX |
| RMII参考时钟 | 50MHz | RMII连续时钟 |

### W25Q32FV
| 参数 | 数值 | 说明 |
| --- | --- | --- |
| 容量 | 32M-bit | 4MB |
| VCC | 2.7~3.6V | 供电范围 |
| 页大小 | 256 bytes | 16,384页 |
| 扇区 | 4KB | 1,024扇区 |
| 块 | 32KB/64KB | 64块 |
| SPI时钟 | 最高104MHz | 单/双/四线 |
| 等效带宽 | 208MHz/416MHz | 双/四线等效 |
| 连续读带宽 | 50MB/s | 连续读 |
| 工作电流 | 4mA | Active |
| 休眠电流 | 1µA | Power-down |
| 接口模式 | SPI/双/四/QPI | 默认SPI，QPI需指令进入 |

## 已核对参数表（Excel）
### J8插座管脚表（EMMC）
| 插座管脚(单) | FPGA1管脚 | FPGA信号 | 插座管脚（双） | FPGA1管脚(双) | FPGA信号(双) |
| --- | --- | --- | --- | --- | --- |
| 1 | AW39 | MMC0D0 | 2 | AR36 | USBD0 |
| 3 | AW38 | MMC0D1 | 4 | AR35 | USBCLK |
| 5 | AY37 | MMC0D2 | 6 | AU37 | USBD1 |
| 7 | AY36 | MMC0D3 | 8 | AU36 | USBD2 |
| 9 | BA38 | MMC0D4 | 10 | AV37 | USBD3 |
| 11 | BA37 | MMC0D5 | 12 | AV36 | USBD4 |
| 13 | BB34 | MMC0D6 | 14 | BD41 | USBD5 |
| 15 | BA34 | MMC0D7 | 16 | BD40 | USBD6 |
| 17 | AV39 | MMC0CMD | 18 | BD39 | USBD7 |
| 19 | AV38 | MMC0CLK | 20 | BC39 | USBNXT |
| 21 | BA39 | TFCD | 22 | AT40 | USBDIR |
| 23 | AY38 |  | 24 | AT39 | USBSTP |
| 25 | BD38 |  | 26 | BB42 |  |
| 27 | BC38 |  | 28 | BA42 | BSYSRSTN |
| 29 | BB40 |  | 30 | AY42 |  |
| 31 | BB39 |  | 32 | AY41 |  |
| 33 | BC43 |  | 34 | BA40 |  |
| 35 | BC42 |  | 36 | AY40 | USBCLK |
| 37 | BC41 |  | 38 | AW41 |  |
| 39 | BB41 |  | 40 | AW40 |  |
| 41 | BB44 |  | 42 | AV41 |  |
| 43 | BA44 |  | 44 | AU41 |  |
| 45 | BA43 | MMC1D0 | 46 | AV42 | UART0SIN |
| 47 | AY43 | MMC1D1 | 48 | AU42 | UART0SOUT |
| 49 | AW44 | MMC1D2 | 50 | AU44 |  |
| 51 | AW43 | MMC1D3 | 52 | AT44 | UART1SIN |
| 53 | AT38 | MMC1CMD | 54 | AN38 | UART1SOUT |
| 55 | AT37 | MMC1CLK | 56 | AN37 |  |
| 57 | AV44 |  | 58 | AR41 |  |
| 59 | AV43 |  | 60 | AR40 |  |
| 61 | AU40 | QIDEIOWN | 62 | AT42 | QIDED0 |
| 63 | AU39 | QIDEIORN | 64 | AR42 | QIDED1 |
| 65 | AR38 | QIDEIORDY | 66 | AP36 | QIDED2 |
| 67 | AR37 | QIDEDMARQ | 68 | AN36 | QIDED3 |
| 69 | AP39 | QIDEDMACKN | 70 | AT43 | QICED4 |
| 71 | AP38 | QIDEINTRQ | 72 | AR43 | QICDD5 |
| 73 | AP40 |  | 74 | AH38 | DIDED6 |
| 75 | AN39 |  | 76 | AH37 | QIDED7 |
| 77 | AP41 | QIDECS0 | 78 | AK38 |  |
| 79 | AN41 | QIDECS1 | 80 | AJ38 |  |
| 81 | AP44 |  | 82 | AK37 | QIDED8 |
| 83 | AP43 |  | 84 | AK36 | QIDED9 |
| 85 | AN44 | QIDERESET | 86 | AL38 | QIDED10 |
| 87 | AN43 |  | 88 | AL37 | QIDED11 |
| 89 | AM44 | QIDEDLDIR | 90 | AM37 | QIDED12 |
| 91 | AL44 | QIDEDHDIR | 92 | AM36 | QIDED13 |
| 93 | AJ40 | QIDERSTDIR | 94 | AL43 | QIDED14 |
| 95 | AJ39 |  | 96 | AL42 | QIDED15 |
| 97 | AJ44 |  | 98 | AM41 |  |
| 99 | AJ43 |  | 100 | AM40 |  |
| 101 | AH44 | BLED1 | 102 | AK43 | QIDEA0 |
| 103 | AH43 | BLED2 | 104 | AK42 | QIDEA1 |
| 105 | AL40 | BLED3 | 106 | AN42 | QIDEA2 |
| 107 | AK40 |  | 108 | AM42 |  |
| 109 | AK41 |  | 110 | AM39 |  |
| 111 | AJ41 |  | 112 | AL39 |  |
| 113 | AM35 |  | 114 | AJ36 |  |
| 115 | AL35 |  | 116 | AH36 |  |
| 117 | AK35 |  | 118 | AJ34 |  |
| 119 | AJ35 |  | 120 | AJ33 |  |

### UART引脚汇总
| UART | 插座管脚 | FPGA1管脚 | FPGA信号 |
| --- | --- | --- | --- |
| UART0 RX | J8-46 | AV42 | UART0SIN |
| UART0 TX | J8-48 | AU42 | UART0SOUT |
| UART1 RX | J8-52 | AT44 | UART1SIN |
| UART1 TX | J8-54 | AN38 | UART1SOUT |

### J9插座管脚表（BIOS）
| 插座管脚(单) | FPGA1管脚 | FPGA信号 | 插座管脚（双） | FPGA1管脚(双) | FPGA信号(双) |
| --- | --- | --- | --- | --- | --- |
| 1 | AV22 | ICE86TMS | 2 | BA18 | SYSRSTN |
| 3 | AU22 | ICE86TDI | 4 | AY18 |  |
| 5 | AW18 | ICE86BGI | 6 | BD18 | DE2R0 |
| 7 | AW19 | ICE86TDO | 8 | BC18 | DE2R1 |
| 9 | AU19 | ICE86BGO | 10 | BD19 | DE2R2 |
| 11 | AT19 | ICE86RST | 12 | BC19 | DE2R3 |
| 13 | BB19 |  | 14 | BD20 | DE2R4 |
| 15 | BA19 |  | 16 | BD21 | DE2R5 |
| 17 | AY20 | ICEUNITRSTN | 18 | BC21 | DE2R6 |
| 19 | AW20 | ICEUNITMS | 20 | BB21 | DE2R7 |
| 21 | AV18 | ICEUNITDI | 22 | BD23 |  |
| 23 | AV19 | ICEUNITDO | 24 | BC23 |  |
| 25 | AY21 |  | 26 | BA23 | DE2G0 |
| 27 | AW21 |  | 28 | BA22 | DE2G1 |
| 29 | AY23 | DE2CLK | 30 | BC22 | DE2G2 |
| 31 | AY22 |  | 32 | BB22 | DE2G3 |
| 33 | AW23 |  | 34 | AW24 | DE2G4 |
| 35 | AV23 | DE2B0 | 36 | AV24 | ICEUNITCK |
| 37 | AT22 | DE2B1 | 38 | BB20 | DE2G5 |
| 39 | AR22 | DE2B2 | 40 | BA20 | DE2G6 |
| 41 | AN23 | DE2B3 | 42 | BD25 | DE2G7 |
| 43 | AN22 | DE3B4 | 44 | BD24 |  |
| 45 | AN21 | DE2B5 | 46 | BC24 | DE2BLK |
| 47 | AM21 | DE2B6 | 48 | BB24 | DE2CS |
| 49 | AM22 | DE2B7 | 50 | BD26 | DE2HS |
| 51 | AL22 |  | 52 | BC26 | DE2VS |
| 53 | AM24 |  | 54 | BD29 | DE2PS |
| 55 | AL24 |  | 56 | BD28 |  |
| 57 | AK22 |  | 58 | BC29 |  |
| 59 | AK21 |  | 60 | BB29 |  |
| 61 | AT24 | FLED1 | 62 | AU27 | MACTXEN |
| 63 | AT23 | MACRXCLKI | 64 | AU26 | ICE86TCK |
| 65 | AJ24 | FLED3 | 66 | BC28 | MACRXER |
| 67 | AJ23 | FLED2 | 68 | BC27 |  |
| 69 | AR23 |  | 70 | BB25 | MACCOL |
| 71 | AP23 | MACMDIO | 72 | BA24 | MACCRS |
| 73 | AL23 | MACMDC | 74 | BA25 | MACTXD0 |
| 75 | AK23 |  | 76 | AY25 | MACTXD1 |
| 77 | AT25 | MACRXD0 | 78 | BB27 | MACTXD2 |
| 79 | AR25 | MACRXD1 | 80 | BB26 | MACTXD3 |
| 81 | AY27 | MACRXD2 | 82 | AU25 | MACRXDV |
| 83 | AY26 | MACRXD3 | 84 | AU24 |  |
| 85 | AW26 | TM1 | 86 | BA28 | SPICLK |
| 87 | AV26 | TM2 | 88 | BA27 | SPIDI |
| 89 | AP24 | TM3 | 90 | BA29 | SPIDO |
| 91 | AN24 | TM4 | 92 | AY28 | SPICS |
| 93 | AN26 | MSCLK | 94 | AW29 |  |
| 95 | AM26 | MSDATA | 96 | AW28 |  |
| 97 | AM27 | KBCLK | 98 | AR27 |  |
| 99 | AL27 | KBDATA | 100 | AR26 | MACTXCLKI |
| 101 | AN28 |  | 102 | AV28 |  |
| 103 | AN27 | TM5 | 104 | AV27 | I2CSCL1 |
| 105 | AM25 | TM6 | 106 | AP26 | I2CSDA1 |
| 107 | AL25 | TM7 | 108 | AP25 |  |
| 109 | AL28 | TM8 | 110 | AU29 |  |
| 111 | AK27 | TM9 | 112 | AT29 | I2CSCL2 |
| 113 | AK26 | TM10 | 114 | AT28 | I2CSDA2 |
| 115 | AJ26 | USPIDO | 116 | AT27 | USPICLK |
| 117 | AK25 | USPICS0 | 118 | AR28 | USPIDI |
| 119 | AJ25 |  | 120 | AP28 |  |

### J10插座管脚表（PCI）
| 插座管脚(单) | FPGA1管脚 | FPGA信号 | 插座管脚（双） | FPGA1管脚(双) | FPGA信号(双) |
| --- | --- | --- | --- | --- | --- |
| 1 | AU10 |  | 2 | AJ10 |  |
| 3 | AT10 | TP1 | 4 | AJ11 | PCIAD0 |
| 5 | AJ15 | TP2 | 6 | BD10 | PCIAD1 |
| 7 | AJ16 | TP3 | 8 | BD11 | PCIAD2 |
| 9 | AK12 | TP4 | 10 | AL12 | PCIAD3 |
| 11 | AK13 | TP5 | 12 | AL13 | PCIAD4 |
| 13 | AK10 | TP6 | 14 | AT13 | PCIAD5 |
| 15 | AK11 |  | 16 | AR13 | PCIAD6 |
| 17 | AM10 |  | 18 | AP14 | PCIAD7 |
| 19 | AL10 |  | 20 | AN14 |  |
| 21 | AT12 |  | 22 | AL14 |  |
| 23 | AR12 | PCIAD16 | 24 | AL15 | PCIAD8 |
| 25 | AM11 | PCIAD17 | 26 | BB10 | PCIAD9 |
| 27 | AM12 | PCIAD18 | 28 | BA10 | PCIAD10 |
| 29 | AR10 | PCIAD19 | 30 | AK15 | PCIAD11 |
| 31 | AP10 | PCIAD20 | 32 | AK16 | PCIAD12 |
| 33 | AN11 | PCIAD21 | 34 | AU11 | PCIAD13 |
| 35 | AN12 | PCIAD22 | 36 | AU12 | PCIAD14 |
| 37 | AY10 | PCIAD23 | 38 | AN16 | PCIAD15 |
| 39 | AW10 |  | 40 | AN17 |  |
| 41 | AY11 | PCIAD24 | 42 | AV11 |  |
| 43 | AW11 | PCIAD25 | 44 | AV12 |  |
| 45 | AR11 | PCIAD26 | 46 | AW14 |  |
| 47 | AP11 | PCIAD27 | 48 | AV14 |  |
| 49 | AP13 | PCIAD28 | 50 | AY13 | PCICBE0 |
| 51 | AN13 | PCIAD29 | 52 | AW13 | PCICBE1 |
| 53 | AM16 | PCIAD30 | 54 | BA12 | PCICBE2 |
| 55 | AM17 | PCIAD31 | 56 | AY12 | PCICBE3 |
| 57 | AU14 |  | 58 | BC12 |  |
| 59 | AT14 |  | 60 | BB12 |  |
| 61 | AU15 |  | 62 | AY16 |  |
| 63 | AT15 | CLK33MI | 64 | AW16 | PCIINTA |
| 65 | BB14 |  | 66 | BA13 | PCIINTB |
| 67 | BB15 | PCIFRAME | 68 | BA14 | PCIINTC |
| 69 | BD15 | PCIIRDY | 70 | AP15 | PCIINTD |
| 71 | BD16 | PCIPAR | 72 | AP16 | PCIREQ0 |
| 73 | BC16 | PCIPER | 74 | AT17 | PCIREQ1 |
| 75 | BC17 | PCISER | 76 | AR17 | PCIREQ2 |
| 77 | BB16 | PCITRDY | 78 | BA17 | PCIREQ3 |
| 79 | BB17 | PCIDEVSEL | 80 | AY17 | PCISMIXI |
| 81 | BA15 | PCISTOP | 82 | AL17 |  |
| 83 | AY15 |  | 84 | AK17 | FLED1 |
| 85 | AW15 |  | 86 | AR21 |  |
| 87 | AV16 | TP7 | 88 | AP21 | FLED2 |
| 89 | AM14 | TP8 | 90 | AP19 |  |
| 91 | AM15 | TP9 | 92 | AP20 | FLED3 |
| 93 | AL18 | TP10 | 94 | AN19 |  |
| 95 | AK18 | TP11 | 96 | AM20 | PCIADDIR0 |
| 97 | AT20 | TP12 | 98 | AM19 | PCIADDIR8 |
| 99 | AR20 |  | 100 | AL19 |  |
| 101 | AU20 |  | 102 | AL20 | PCIADDIR16 |
| 103 | AU21 |  | 104 | AK20 | PCIADDIR24 |
| 105 | AR15 | PCIGNT0 | 106 | AJ19 | PCIBEDIR |
| 107 | AR16 | PCIGNT1 | 108 | AJ20 | PCIFRAMEDIR |
| 109 | AU16 | PCIGNT2 | 110 | BC11 | PCIIRDYDIR |
| 111 | AU17 | PCIGNT3 | 112 | BB11 | PCITARGEDIR |
| 113 | AP18 | PCIRSTN | 114 | BD13 | PCIPARDIR |
| 115 | AN18 |  | 116 | BC13 | PCIPERDIR |
| 117 | AT18 | CLK33MO | 118 | BD14 | PCISERDIR |
| 119 | AR18 |  | 120 | BC14 |  |

## 验证与运行目标
- 验证Linux引导链路可用
- UART控制台可用，作为内核日志输出通道
- DDR3稳定读写
- SPI Flash可读写，满足启动需求
- 以太网链路建立并可进行网络通信
- USB链路建立并可被系统识别

## 约束与风险
- 资源与时序：SmallBoomConfig在XC7V2000T上仍需评估时序裕量
- DDR与高速外设：需严格对照板卡时钟与布线约束
- PHY接口：USB/以太网PHY接口模式需与板卡硬件一致
- 启动介质：SPI Flash容量与分区需满足Linux镜像需求
