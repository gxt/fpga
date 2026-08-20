# Chipyard 1.13.0 指定 BOOM 版本适配方案报告

> 生成日期：2026-05-13
> 任务编号：042x

## 1. 版本事实

### 1.1 当前 vivado-risc-v 工程依赖栈

| 组件 | Commit | 日期 | 备注 |
|------|--------|------|------|
| vivado-risc-v (主仓库) | `32bd1e886` | — | DualV7 SoC build support |
| riscv-boom | `18c48bb41` (v3.0.0-129) | 2023-11-19 | PR #664 TLB fix |
| rocket-chip | `dbcb06afe` (v1.6-399) | — | PTW Hypervisor bug fixes |
| testchipip | `1952231569` | — | add-SimTLMem-66 |
| sifive-cache | `dd1ecafc0` | — | |
| gemmini | `709bc56b6` | — | |
| Chisel | 3.6.1 | — | `edu.berkeley.cs` |
| Scala | 2.13.10 | — | |
| CDE | 内嵌于 rocket-chip/cde | — | `org.chipsalliance.cde.config` |

### 1.2 目标 BOOM 版本（Chipyard 1.13.0 锁定）

| 组件 | Commit | 日期 | 备注 |
|------|--------|------|------|
| **riscv-boom** | `d2a64f7ca` | 2024-08-14 | "Fix v4 fdiv taking correct rm" |
| rocket-chip | `72690b07c` | — | chipsalliance/rocket-chip |
| testchipip | `c94c1e3fa9` | — | |
| hardfloat | `4225367ed` | — | berkeley-hardfloat |
| diplomacy | `6b7dc988a` | — | chipsalliance/diplomacy |
| CDE | `2bcaeae2b` | — | 独立 tools/cde（非 rocket-chip 内嵌） |
| Chisel | **6.5.0** | — | `org.chipsalliance`（非 `edu.berkeley.cs`） |
| Scala | **2.13.12** | — | |
| sbt | 1.8.2 | — | |
| Chipyard 版本 | 1.13.0 | 2024-09-30 | Release tag |

### 1.3 差距量级

| 维度 | 当前 | 目标 | 差距 |
|------|------|------|------|
| BOOM commits | `18c48bb` | `d2a64f7` | **250 commits** (ahead) |
| BOOM 时间跨度 | 2023-11-19 | 2024-08-14 | **~9 个月** |
| Chisel 主版本 | 3.6.1 | **6.5.0** | **跨越主版本** |
| Chisel 组织 | edu.berkeley.cs | **org.chipsalliance** | 完全改名 |
| Scala | 2.13.10 | 2.13.12 | 小版本 |
| rocket-chip | `dbcb06afe` | `72690b07c` | 完全不同的分支点 |
| testchipip | `1952231569` | `c94c1e3fa9` | 不同的 fork/commit |

**关键发现：目标 BOOM commit `d2a64f7` 正是 Chipyard 1.13.0 的 `.gitmodules` 中锁定的 BOOM 子模块 commit。**

---

## 2. 三条技术路线分析

### 2.1 路线 A：当前栈不动，定向 merge/backport 目标 BOOM

**操作**：在当前 vivado-risc-v (Chisel 3.6.1 + Scala 2.13.10 + rocket-chip `dbcb06afe`) 上，
将 `riscv-boom` 子模块从 `18c48bb` 更新到 `d2a64f7`（250 commits 的 diff），
修补编译错误使其适配当前依赖栈。

**可行性判断：几乎不可行。**

理由：

1. **Chisel API 代际鸿沟**：目标 BOOM commit `d2a64f7` 是在 Chisel 6 生态中开发的。
   虽然单个 commit message 是 "Fix v4 fdiv taking correct rm"，但其代码基已经适配了 Chisel 6
   的 API（`org.chipsalliance.chisel3.*`）。将 250 个 commit 的 BOOM 代码回退到 Chisel 3.6.1
   的 API（`chisel3.*` / `edu.berkeley.cs`）意味着逐个文件重写 import 和 API 调用。

2. **RocketChip API 不兼容**：目标 BOOM 依赖的目标 rocket-chip (`72690b07c`) 与当前
   (`dbcb06afe`) 之间有很多 API 差异（例如 TileLink 节点类型、Diplomacy node 接口、
   Parameters 体系的变更）。这在 §09 中 54/56 文件的差异中已有体现 —— 而这还只是一个
   比目标更早的 BOOM fork。250 个 commit 的 diff 只会更差。

3. **§09 的经验教训**：boom_stop 纯替换产生了 100 个编译错误、5+ 类 API 不兼容，
   而 boom_stop 只有 54 文件差异。目标 BOOM 有 250 个 commit 的代码差异，
   预计错误数量在 300-500 个级别。

4. **BOOM 不是孤立的**：BOOM 依赖于 RocketChip 提供的 Tile、CoreParams、
   HasL1ICacheParameters 等 trait/class，这些接口在 rocket-chip 的两个版本间
   有实质性差异。

| 维度 | 评估 |
|------|------|
| 影响范围 | `generators/riscv-boom/src/main/scala/**`（全部重写级别） |
| 预期首个阻塞 | Chisel API 不兼容（编译阶段，预计 >300 错误） |
| 对当前基线破坏性 | **低**（不改其他子模块） |
| 工作量 | **极高**（等效于将 Chisel 6 的 BOOM 手动移植到 Chisel 3） |
| 验证路径 | `make verilog` 编译通过（预计需 10-20 轮迭代） |
| 风险等级 | **极高** |

### 2.2 路线 B：回滚当前依赖栈到目标 BOOM 时代

**操作**：将当前 vivado-risc-v 的 rocket-chip、testchipip、Chisel/Scala 全部更新到
Chipyard 1.13.0 的对应版本。

**可行性判断：技术可行，但破坏性极大。**

理由：

1. **Chisel 3→6 是框架级迁移**：
   - `chisel3.*` → `org.chipsalliance.chisel3.*`（包名全变）
   - Chisel 6 引入了新的实验性 API，部分 Chisel 3 API 已 deprecated/removed
   - sbt 构建配置需要从 Chisel 3 插件改为 Chisel 6 插件

2. **rocket-chip 版本大幅跳跃**：
   - rocketchip 子模块从 `dbcb06afe` 跳到 `72690b07c`
   - CDE 从 rocket-chip 内嵌的 `cde/` 变为独立 `tools/cde`
   - Diplomacy 框架有重要变更（从 `freechips.rocketchip.diplomacy` → `org.chipsalliance.diplomacy`）

3. **vivado-risc-v 自定义代码冲击**：
   - `src/main/scala/rocket.scala` 中的 CONFIG 定义依赖 RocketChip/BOOM 的 API，
     需要全面适配
   - `board/dualv7/riscv-2025.1.tcl` 的 Block Design 可能因 RTL 接口变化而需要重连
   - BootROM 地址映射、DTS 需要重新验证

4. **构建系统改变**：
   - vivado-risc-v 的 `Makefile` + `build.sbt` 是自己维护的
   - Chipyard 1.13.0 使用 `common.mk` + FireSim 集成
   - 需要手动对齐 sbt 依赖版本

| 维度 | 评估 |
|------|------|
| 影响范围 | rocket-chip, testchipip, CDE, Chisel, Scala, build.sbt, Makefile, src/main/scala/, board/dualv7/* |
| 预期首个阻塞 | rocket.scala 编译不通过（CONFIG API 变更） |
| 对当前基线破坏性 | **极高**（所有已验证配置可能全部失效） |
| 工作量 | **高**（全栈迁移，2-4 周） |
| 验证路径 | `make verilog CONFIG=rocket64b2` → `make bitstream` → 上板测试 |
| 风险等级 | **高** |

### 2.3 路线 C：混合方案

**三种具体子路线：**

#### C1：以 Chipyard 1.13.0 为基线，前移 DualV7 板级支持

操作：
1. Clone Chipyard 1.13.0 作为新基线仓库
2. 将 vivado-risc-v 的 `board/dualv7/`（TCL, XDC, DTS）、`bootrom/`、
   `src/main/scala/rocket.scala`（CONFIG）移植到 Chipyard 1.13.0 中
3. 在 Chipyard 框架下运行 `make verilog`，生成与目标 BOOM 兼容的 RTL
4. 用 Vivado 创建工程并综合

| 维度 | 评估 |
|------|------|
| 影响范围 | 板级文件（TCL/XDC/DTS）、BootROM、CONFIG、Makefile 适配 |
| 预期首个阻塞 | BOOM 的 RTL 顶级接口可能与当前 `riscv_wrapper.v` 不兼容 |
| 对当前基线破坏性 | **零**（完全独立的新仓库） |
| 工作量 | **中**（主要是板级移植） |
| 验证路径 | Chipyard `make verilog` → Vivado Block Design 适配 → `make bitstream` |
| 风险等级 | **中** |

**优势**：
- Chipyard 1.13.0 已经锁定了所有正确的子模块版本（BOOM、rocket-chip、testchipip、hardfloat 等）
- 不需要手动对齐任何依赖栈
- 当前 vivado-risc-v 的工作基线完全不受影响
- Chipyard 有完善的 CI 和文档

**挑战**：
- Chipyard 生成的 RTL 顶层接口（TestHarness）与 vivado-risc-v 的 Block Design 可能不同
- 需要处理 Chipyard 到 Vivado Block Design 的 AXI/TileLink 桥接
- BootROM 构建流程可能与 Chipyard 的工具链不兼容

#### C2：选择性更新子模块 + 保持 vivado-risc-v 框架

操作：
1. 在 vivado-risc-v 主仓库中，创建一个新分支
2. 更新 rocket-chip 子模块到 `72690b07c`
3. 更新 testchipip 子模块到 `c94c1e3fa9`
4. 更新 riscv-boom 子模块到 `d2a64f7`
5. 修改 build.sbt 适配 Chisel 6 + Scala 2.13.12
6. 适配 src/main/scala/rocket.scala 到新 API
7. 验证 make verilog

| 维度 | 评估 |
|------|------|
| 影响范围 | 所有子模块 + build.sbt + rocket.scala + Makefile |
| 预期首个阻塞 | build.sbt 跨 Chisel 版本迁移 |
| 对当前基线破坏性 | **中**（在独立分支操作） |
| 工作量 | **高**（等效于路线 B 但更碎片化） |
| 验证路径 | `make verilog` |
| 风险等级 | **中-高** |

#### C3：RTL 级混合（生成 RTL 后在 Vivado 层整合）

操作：
1. 在 Chipyard 1.13.0 中生成带有目标 BOOM 的 RTL（Verilog）
2. 将生成的 Verilog 文件导入 vivado-risc-v 的 Vivado 工程
3. 在 Vivado Block Design 中连接新 RTL 的 AXI 端口
4. 适配板级约束

| 维度 | 评估 |
|------|------|
| 影响范围 | Vivado Block Design (TCL) + 顶层 wrapper |
| 预期首个阻塞 | RTL 接口信号不匹配 |
| 对当前基线破坏性 | **低** |
| 工作量 | **低-中** |
| 验证路径 | Vivado synthesis |
| 风险等级 | **中** |

---

## 3. 决策矩阵

| 方案 | 影响范围 | 预期首个阻塞 | 对基线破坏性 | 工作量 | 可逆性 | 推荐度 |
|------|---------|-------------|------------|--------|--------|--------|
| A (backport) | BOOM scala 54+ 文件 | Chisel API 不兼容（>300 错误） | 低 | 极高 | 可逆 | ★☆☆☆☆ |
| B (全栈回滚) | 全仓库（子模块+build+scala+TCL） | rocket.scala API 变更 | 极高 | 高 | 需新分支 | ★★☆☆☆ |
| C1 (Chipyard基线) | 板级文件移植 | RTL 顶层接口差异 | 零（独立仓库） | 中 | 完全可逆 | ★★★★☆ |
| C2 (选择性更新) | 子模块+build+sbt+scala | Chisel 版本迁移 | 中（独立分支） | 高 | 需新分支 | ★★★☆☆ |
| C3 (RTL级整合) | TCL + wrapper | 信号不匹配 | 低 | 低-中 | 可逆 | ★★★☆☆ |

---

## 4. 推荐方案

### 4.1 主推荐：路线 C1（Chipyard 1.13.0 为基线，前移 DualV7 板级支持）

**核心理由**：

1. **目标 BOOM commit `d2a64f7` 就是 Chipyard 1.13.0 的锁定版本**。
   这意味着 Chipyard 1.13.0 已经完美解决了所有依赖版本对齐问题（BOOM + rocket-chip +
   testchipip + hardfloat + diplomacy + CDE + Chisel + Scala）。

2. **完全隔离风险**：在独立仓库中操作，当前工作基线零风险。

3. **验证链清晰**：
   ```
   Phase 1: Chipyard 1.13.0 clone + 子模块初始化
   Phase 2: 移植 CONFIG (rocket.scala → Chipyard config)
   Phase 3: 移植板级文件 (board/dualv7/*)
   Phase 4: Chipyard `make verilog` 通过
   Phase 5: Vivado Block Design 适配
   Phase 6: `make bitstream` + 上板验证
   ```

4. **可持续性**：后续 BOOM 更新可以直接跟随 Chipyard 的 release tags。

### 4.2 为什么路线 A/B 不可取

- **路线 A**：技术上几乎等同于将 Chisel 6 代码手工降级到 Chisel 3，工程意义极低。
  §09 已经证明即使是小规模 BOOM fork（54 文件）的 API 对齐都不可行，250 commit 的
  diff 只会更糟。

- **路线 B**：虽然技术上最终可行，但会摧毁所有已验证的工作基线
  （rocket64b2/z1/z2m），恢复成本极高，且没有中间回退点。

### 4.3 第一阶段最小任务

**目标**：证明 Chipyard 1.13.0 能生成含目标 BOOM 的 DualV7 RTL。

具体步骤：
1. 在远端建立一个隔离 sandbox（如 `~/chipyard-1.13.0-dualv7/`）
2. Clone Chipyard 1.13.0 + init submodules
3. 创建 DualV7 的 Chipyard config（参考 `src/main/scala/rocket.scala`）
4. 生成 Verilog RTL（`make verilog` 等价命令）
5. 检查生成的顶层信号与当前 `riscv_wrapper.v` 的接口兼容性
6. 产出差异报告

**不要做**：
- 不要立即进入 Vivado 综合（1.5 小时级任务留到后续）
- 不要修改当前 vivado-risc-v 主工作区
- 不要在 Chipyard 中尝试运行仿真（与 FPGA 目标无关）

### 4.4 后续任务路线图

```
042x (当前): 版本策略调研 ✅ → 推荐 C1
    │
    ▼
043x: Chipyard 1.13.0 sandbox 搭建 + make verilog 基线验证
    │
    ▼
044x: DualV7 CONFIG 移植 + 板级 TCL/XDC/DTS 适配
    │
    ▼
045x: Vivado Block Design 重建 + 综合试点
    │
    ▼
046x: bitstream 生成 + 上板 smoke test (UART/LED/DDR)
```

---

## 5. 风险提示

1. **Chisel 6 生成的 Verilog 接口可能不同于 Chisel 3**：Chipyard 1.13.0 的
   TestHarness 接口可能与 vivado-risc-v 的 Block Design 不完全兼容，
   需要额外的 wrapper 或 adapter。

2. **Chipyard 的构建流程复杂度**：Chipyard 使用 `common.mk` + conda 环境管理，
   可能与远端现有的 Vivado 2025.1 环境存在工具链冲突。

3. **目标 BOOM 的 250 个 commit** 中包含 Chipyard 1.13.0 的 B extension 支持、
   向量单元集成等新特性，这些可能需要额外的配置才能正常工作。

4. **当前工作基线（rocket64b2/z1/z2m）建议保留**：不要为了对齐 BOOM 版本
   而破坏已验证的配置。

---

## 6. 附录：版本差异详情

### 6.1 Chisel 3.6.1 → 6.5.0 关键变化

| 变化项 | Chisel 3.6.1 | Chisel 6.5.0 |
|--------|-------------|-------------|
| 组织 | `edu.berkeley.cs` | `org.chipsalliance` |
| 主包 | `chisel3.*` | `chisel3.*` (向后兼容层) + 新 API |
| 实验性 API | `chisel3.experimental.*` | 部分移除/重构 |
| FIRRTL | chisel3 内建 | 独立 firrtl2 项目 |
| 编译器插件 | `chisel3-plugin` | `chisel-plugin` (新命名) |

### 6.2 CDE (Config/Diplomacy) 变化

| 变化项 | 当前 vivado-risc-v | Chipyard 1.13.0 |
|--------|--------------------|------------------|
| 包名 | `org.chipsalliance.cde.config` | `org.chipsalliance.cde` |
| 位置 | 内嵌于 `rocket-chip/cde/` | 独立 `tools/cde` 子模块 |
| Diplomacy | `freechips.rocketchip.diplomacy` | `org.chipsalliance.diplomacy` |

---

*报告结束。*
