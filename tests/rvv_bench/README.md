# tests/rvv_bench/ —— RVV 评测工具（M4）

## bench_rvv.py —— 上板评测框架（201 上板，RVV SoC 20MHz）

### 用法
```bash
# 自动分流评测：有 csr_cycle_count 的 → 性能模式，无 → smoke 模式
python3 bench_rvv.py <elf列表.txt>
```
- ELF 列表：每行一个 .elf 绝对路径（如 tests/rvv_bench/ 生成的）
- 输出：每用例一行 `<名> PASS/FAIL 加载Xs 执行Yms [cycles=N]`

### 关键设计（重要，勿改坏）
1. **reset_core**（每个用例前）：
   - **wfi 唤醒**：写 CLINT MTIMECMP（0x02004000 = MTIME+1000）触发定时器中断 → 核退出时钟门控（否则 wfi 类用例后 host 写卡）
   - **保持复位**：写 CTRL=1（0x30000）**不释放**——加载时核不运行（CTRL=0 释放后核立即跑，占用 TCM 仲裁致 W 写卡）
   - 加载完由 S 命令释放启动
2. **自动分流**：`get_cycle_addr`（readelf 查 csr_cycle_count 符号）——有 → 性能模式（HALTED + cycles 回读），无 → smoke 模式（加载 + S + 无 fault）
3. **失败重试**：W_FAIL/未HALTED → reset + 重载，最多 3 次
4. HALTED 轮询 20s（200×0.1s）；CSR_STATUS=0x30008 bit0

### 关键坑
- wfi 类用例（汇编 RVV 测试）用 wfi 结束（无 HALTED）→ smoke 判定
- 故意 fault 测试（load_store8_fault/vill_test）smoke 判 FAIL 是预期

## seg_analysis.py —— ELF 段统计
```bash
python3 seg_analysis.py   # 分析 621 个 RVV ELF 的 ITCM/DTCM 段 → elf_segments.json
```
- 分区：ITCM 0x0-0x2000（8K）、DTCM 0x10000-0x18000（32K 默认配置）
- **注意**：highmem 用例的 DTCM 在 0x100000（1MB）——不在此分区，算入 other 段
- 用途：筛选默认 TCM 能跑的用例（fit/over）

## elf_segments.json —— 用例段数据
- fit：默认 TCM 能跑（606 个）
- over：超限（15 个：gemma 11 + highmem 4）
