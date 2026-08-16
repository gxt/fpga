# ADR-003: 上游 RTL 修改政策（fork 流程）

- 状态：已接受
- 日期：2026-08-16
- 相关任务：全部（约束所有阶段）

## 背景

coralnpu 以 git submodule 引入，`origin` 指向 fork `gxt/coralnpu`，`upstream` 指向官方 `google-coral/coralnpu`。`.tao/README.md` 已定义子模块管理流程：改动 commit 到 fork 并 push origin，主仓库更新 gitlink，记录到 `.tao/knowledge/changelog.md`。

复现过程（尤其器件适配、上板集成）可能遇到：

- 上游 bug 或与本地工具链不兼容处；
- 需要新增/调整 RTL 或构建 target 的情况。

## 决策

1. **默认零改动上游**：复现所需的自定义脚本、包装、文档一律放主仓库（`rtl/`、`sim/`、`synth/`、`docs/`），不修改 coralnpu/ 内文件。
2. **确需修改上游时（小修）**：
   - 在 coralnpu/ 内 commit，`git push origin <branch>` 推送到 fork；
   - 主仓库 `git add coralnpu` 更新 gitlink 并提交；
   - 在 `.tao/knowledge/changelog.md` 记录实质改动（原因、内容、影响面）。
3. **禁止产生"本地漂移"**：改了不 push、不记录的状态一律不允许；每次修改后必须走完上述流程。
4. 尽量保持 submodule HEAD 与官方 main 接近，减少长期分叉。

## 影响

- 修改可追溯、可回退，主仓库与子模块状态一致。
- 增加少量流程开销（push fork + changelog 记录）。
- 器件适配尽量用"覆盖层"方案（XDC、tcl 后处理）减少对上游的侵入。

## 已拒绝方案

- **直接改子模块不 push**：`git submodule update` 会丢失本地改动。
- **把 coralnpu 从 submodule 改为独立仓库**：破坏现有仓库结构，改动面过大。
- **只读上游、完全不改**：用户已确认允许必要小修走 fork。
