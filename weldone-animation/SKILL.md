---
name: weldone-animation
description: 用 Weldone.Cli 的 gen-ls 命令在 headless 环境复现"PF + 粗定位 → 焊接路径规划 → 生成 Fanuc LS"全链路（即路径仿真 PathSimulation 模块的 CLI 等价物），验证规划结果。触发场景：(1) 用户想脱离 GUI 验证某 PF + 粗定位位姿下的规划是否成功、外部轴行程是否合理；(2) 用户说"用 CLI 验证规划""gen-ls""跑一下规划看看结果""不用 GUI 验证路径仿真""路径仿真""animation"；(3) 现场规划失败需在本地复现定位。覆盖单臂/双臂、粗定位矩阵三种输入格式、可选 GP3 外部轴解码校验。
---

# gen-ls：PF + 粗定位 → 规划 → LS 验证

## 命令定位

`gen-ls`（`src/Weldone.Cli/Commands/GenLsCommand.cs`）是路径仿真模块（`Pages/PathSimulation/`）的 CLI 等价物：输入 PF 文件 + 粗定位位姿，跑完整生产级规划流水线并产出 Fanuc LS 脚本。**不 Mock 设备、不走 FSM 执行**，纯规划链路。

规划流水线（每个 craft 逐条执行）：
1. 外部轴规划 — `PlanManager.ScanWeldExternalPlan(data, craftId, isDual)`
2. 焊接路径规划 — `WeldRobotAppService.WeldPathPlan` / `WeldPathPlanDualArm`
3. 过渡规划 — `PlanManager.WeldTransitionPlan` / `WeldTransitionDualArmPlanForCraft`
4. 逐道次生成 LS — `WeldRobotAppService.GenerateLSFile` / `DualArmGenerateLSFile`

任一步失败会打 `失败`/`跳过` 日志，不中断后续 craft。

## 调用方式

justfile 没有为 `gen-ls` 配别名，直接用 dotnet 跑 CLI 项目（工作目录 `src/Weldone`）：

```pwsh
dotnet run --project src/Weldone.Cli/Weldone.Cli.csproj -- gen-ls --pf "<PF路径>" --coarse "<粗定位>" [选项]
```

> 注意：`ExecuteInteractiveAsync`（交互式菜单入口）被显式禁用，注释为"需要 ArmTransStateDict 支持，CLI 流程暂未适配"。**只能通过命令行参数调用，不要走 `just interactive` 菜单**。

## 参数

| 参数 | 缩写 | 必填 | 说明 |
|---|---|---|---|
| `--pf` | `-p` | 是 | PF 文件路径（`.pf` JSON，即 `ProcessTransfer` 序列化） |
| `--coarse` | `-c` | 否 | 粗定位矩阵，缺省=单位矩阵。三种格式见下 |
| `--user-frame` | | 否 | 用户坐标系矩阵（同 `--coarse` 格式），缺省=单位矩阵 |
| `--dual` | | 否 | 双机模式（默认单臂） |
| `--post-mode` | | 否 | 双机后处理模式 `Async`/`Sync`/`Hybrid`，默认 `Async` |
| `--verify` | `-v` | 否 | 生成完成后扫描 `--dir` 下 LS 文件，解码 GP3 外部轴点位 |
| `--dir` | `-d` | 否 | `--verify` 的扫描/输出目录，默认 `Documents\weldone` |

### `--coarse` 三种格式（`ParseMatrix` 解析，按顺序尝试）

1. **JSON 文件路径**：16 元素 float 数组，行主序 `M11..M44`
   ```json
   [1,0,0,0, 0,1,0,0, 0,0,1,0, 100,200,300,1]
   ```
2. **CoarsePositionningContextDto JSON 文件**：生产环境 `ProductionData` 目录下的 `ModelBase_*.json`。内部从 `GeneralCoarseResults`(JSON 字符串) → `workpiece_results[0].model_base_result.transform_4x4` 提取 `m11..m44`。**最贴近现场粗定位产物的格式**。
3. **inline 16 个逗号分隔浮点数**：行主序
   ```
   --coarse "1,0,0,0,0,1,0,0,0,0,1,0,100,200,300,1"
   ```

> 矩阵含义：粗定位是完整 4×4 位姿矩阵（含姿态），不是单纯 XYZ 位置。规划内部会乘 `UserFrame` 的逆(`coarseMatrix * userFrameInvert`)得到工件在用户坐标系下的位姿。

## 典型用法

### 1. 单臂 + 现场粗定位文件验证规划（最常见）

```pwsh
dotnet run --project src/Weldone.Cli/Weldone.Cli.csproj -- gen-ls `
  --pf "D:\data\task.pf" `
  --coarse "D:\data\ModelBase_xxx.json"
```

### 2. 单臂 + inline 矩阵 + GP3 外部轴校验

```pwsh
dotnet run --project src/Weldone.Cli/Weldone.Cli.csproj -- gen-ls `
  -p "D:\data\task.pf" `
  -c "1,0,0,0,0,1,0,0,0,0,1,0,100,200,300,1" `
  --verify `
  -d "D:\out"
```

### 3. 双臂模式

```pwsh
dotnet run --project src/Weldone.Cli/Weldone.Cli.csproj -- gen-ls `
  --pf "D:\data\task.pf" `
  --coarse "D:\data\ModelBase_xxx.json" `
  --dual --post-mode Async
```

## 解读输出

日志结构（每个工件、每个 craft、每个道次逐级缩进）：

```
=== 导入 PF 文件: ... ===        工件数: N
=== 粗定位矩阵 ===
  [m11..m44 | ...]               解析后的 coarseMatrix，确认输入正确
--- 工件: Name (Id), 工艺数: M ---
  工艺: <craftId>
    外部轴规划: 成功/失败         ← 失败先查 RobotSetting.ExternalAxisTransformCenter
    焊接路径规划: 成功/失败        ← 失败查焊缝几何/模板匹配
    过渡规划: 成功/失败            ← 失败查 ArmTransStateDict（见下）
    道次数: K
    道次 1: LS 生成成功
```

### 判定规划是否成功

- **焊接路径规划: 成功** 且 **道次数 ≥ 1** → 核心规划通过
- 任一步 `失败` → 该 craft 规划未通过；日志会标注 `跳过 LS 生成`
- `--verify` 的 GP3 表：`GP3=[e1,e2] → 规划=[p1,p2] Δ=[d1,d2]`，Δ 偏差大说明外部轴校正矩阵（`EffectiveAxisToRobotMatrix`）有问题

## 已知约束与排障

### 过渡规划失败 / ArmTransStateDict 缺口
`GenLsCommand.ExecuteInteractiveAsync` 被禁用的原因就是过渡规划依赖 `ArmTransStateDict`。命令行模式下若过渡规划失败、LS 未生成，**核心焊接规划仍已成功**（`data.WeldCaches[craftId]` 已写入）——验证规划本身是否成立不受影响，只是拿不到 LS 文件。

### PlanEnvironment 未初始化
`Plan4Animation`/`ScanWeldExternalPlan` 依赖 `planEnvironment.ArmContexts`。CLI 容器启动时会从 `ProjectConfiguration`/`RobotSetting` 加载，若 `ArmContexts` 为空会抛索引越界。排障路径：
1. 确认 `RobotSetting` 已配置（`%APPDATA%` 下当前激活项目的 `RobotSetting.json`）
2. 用 `weldone-project-logs` skill 读配置确认

### 粗定位矩阵格式不识别
`ParseMatrix` 返回 null 时退回单位矩阵（日志会打印单位矩阵），导致规划位姿全错。若日志里 `粗定位矩阵` 打印成单位矩阵但你给了 `--coarse`，说明格式没匹配上——检查 JSON 是否为 16 元素数组、或 `ModelBase_*.json` 的 `GeneralCoarseResults` 字段结构。

### PF 加载失败
返回 null 通常是 PF 文件不是 `ProcessTransfer` 的标准序列化（缺 `SubProcessTransfers`）。确认 PF 由生产环境导出，而非手工拼接。

## 相关命令

- `verify-vcm`（`VerifyVcmBindingCommand`）：只校验混合焊缝端头推扫 VCM 绑定，不走完整路径规划，不接粗定位。专注端头模式校验时用它。
- `test-model-scan-weld`（`TestModelScanWeldCommand`）：PF + 粗定位 → 跑完整 ModelBaseScanWeld **FSM 执行**（Mock 设备）。验证执行流程时用它，验证规划结果用 `gen-ls`。
- `verify-ext-axis`（`VerifyExtAxisCommand`）：单独校验外部轴 CalibForward/CalibBackward，不跑规划。`gen-ls --verify` 内部复用其 GP3 解析逻辑。

## 验证流程建议

收到"验证规划结果"请求时：
1. 确认 PF 路径和粗定位来源（现场 `ModelBase_*.json` / 手给矩阵 / 单位矩阵）
2. 先跑**单臂 + 不带 `--verify`** 确认规划链路通（看"焊接路径规划: 成功"）
3. 需要看外部轴行程时加 `--verify` 解码 GP3
4. 失败时按上面"排障"对照日志定位，必要时用 `weldone-cli-craft-debug` skill 加诊断日志
