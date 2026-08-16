# T009: fusesoc 生成 Vivado 工程并跑通官方器件综合

## 执行环境
**执行环境**：远端（综合服务器 `gxt@192.168.200.202`）＋ 本地

## 接口规范
- 输入：T008 工作流与执行拓扑；coralnpu `fpga/` 目录（core 文件、rtl/、ip/、tcl hooks）；官方目标器件 `xcvu13p-fhga2104-2-e`
- 输出：Vivado 工程生成流程跑通；官方器件综合（synth_only 或完整实现）跑通；生成网表/工程文件；**结果作为资源基线，供 T010/T011 对比（不用于上板）**
- 约束：优先复用官方 fusesoc 流程（`fusesoc_build` 或等价 fusesoc 命令，见 `fpga/BUILD`）；**执行命令以 T008 确定的执行拓扑为准**；不重写整套 tcl；如 fusesoc 在服务器不可用，允许用官方 tcl hooks 手工组工程，但须在结果中说明偏离；**长综合设 timeout ≥ 8h；失败处理遵循 `.tao/README.md` 命令失败纪律：先诊断根因、有依据重试最多 2 次、无效即停止上报**

## 验收标准
1. 按 T008 执行拓扑在服务器上成功生成 Vivado 工程（官方路径为 bazel `//fpga:build_chip_nexus_synth_only[_<mem>[_<boot>]]` 或等价 fusesoc 命令，target 命名见 `fpga/BUILD` 的 `_NEXUS_NAME_MAP`），并记录实际命令与执行机器
2. 官方器件综合无 ERROR，产出网表/工程文件路径明确
3. 记录综合耗时（实测）与关键日志（如资源预估），沉淀到 `.tao/knowledge/synth-notes.md`，**标注该结果为官方器件基线**
4. 若走偏离路径（手工组工程），附理由与所需文件的差异说明
5. 若综合失败，记录根因分析过程与重试依据（每次重试说明改动点），最终结论写入任务完成区与 synth-notes.md

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
