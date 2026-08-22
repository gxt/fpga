# T020: SRAM 扩展与外设集成验证

## 执行环境
**执行环境**：机器202（综合）＋ 机器201（上板烧录 + 外设测试）

## 接口规范
- **输入**：
  1. T019 验证的 DDR3 集成 SoC（含 core + crossbar + sram 256KB + DDR3）
  2. SRAM 扩展：256KB → 512KB 或 1MB（根据资源评估决定）
  3. 外设：`uart0`/`uart1`（TLUL 接口）、`gpio`（8 位）、`clint`、`plic`
  4. 测试程序：
     - `.extdata` 段程序（使用外部 SRAM 存储）
     - 外设访问测试（UART 发送/接收、GPIO 输出、中断）
  5. 链接脚本：需修改 `coralnpu_tcm.ld.tpl` 以支持 `.extdata` 段映射到 SRAM（0x20000000）
- **输出**：
  1. 完整 SoC SV（含扩展 SRAM + 外设）
  2. 综合报告（资源/时序）
  3. 上板测试结果：SRAM 读写成功，外设工作正常
- **约束**：
  1. **SRAM 容量预估**：
     - 512KB ≈ 114 个 RAMB36（实用，留余量）
     - 1MB ≈ 228 个 RAMB36（较大，需评估资源）
     - 建议先 512KB，若资源充足再扩 1MB
  2. **外设最小化**：仅添加必要外设（uart0/1、gpio、clint、plic），不添加 DMA、spi2tlul 等
  3. **UART TLUL 接口**：需验证 TLUL UART 是否已存在，若不存在需复用现有 `host_cmd_fsm` 改造
  4. **链接脚本修改**：`.extdata` 段映射到 SRAM（0x20000000），确保程序可访问
  5. **产物目录规范**：`synth/out/T020-sram-periph/`（201）与 `~/fpga/work/T020-sram-periph/`（202）

## 验收标准
1. **bazel 生成 SV 成功**：添加 SRAM 扩展 + 外设后生成 SV 无错误
2. **综合 0 ERROR**：综合+实现+bitstream 完成，无 ERROR
3. **时序收敛**：WNS ≥ 0（100MHz 目标）
4. **资源报告**：记录 LUT/FF/BRAM 使用量，评估 SRAM 容量是否在预算内
5. **SRAM 功能验证**：
   - 写 SRAM（0x20000000）然后回读，数据一致
   - `.extdata` 段程序加载到 SRAM 并运行成功
6. **外设功能验证**：
   - UART：发送字符到主机串口接收正确
   - GPIO：输出模式控制 LED（可选）
   - CLINT/PLIC：中断触发与响应（可选，可后续验证）
7. **链接脚本验证**：程序链接后 `.extdata` 段地址在 SRAM 范围内（0x20000000 起）

## 完成区
**状态**：待开始
**Commit**：
**测试结果**：
**修改文件**：
**验收结果**：
**新发现/坑**：
**遗留问题**：

## 审阅记录

#### 第 1 轮 engineer 自审
（工程师自审 subagent 的意见、问题、判决及 finding 处置）

#### 第 1 轮 reviewer 验收
（审查者独立验证的重跑记录、约束核验、判决；Needs Revision 返工后，下一轮标 `第 2 轮`）