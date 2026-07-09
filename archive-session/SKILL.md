---
name: archive-session
description: 会话归档。收集变更、生成 record、检测可复用知识并按领域路由写入 knowledge/、更新 INDEX.md。Use after a /grill-with-docs session, after completing a feature, or when user says "archive this", "record this session", "archive the changes".
---

# Archive Session — 会话归档

## Quick start

用户完成一轮设计+实现后，Agent 收集变更、生成 record、提取可复用知识、按领域路由写入，更新索引。

## 领域路由表

知识文件写入前，必须根据主题判断归入哪个领域文件夹。下表按匹配优先级排列（优先匹配更具体的领域）：

| 领域文件夹 | 含义 | 典型关键词 |
|---|---|---|
| `dual-arm/` | 双臂系统 | DualArm、双臂协同、Leader/Follower、起收弧时序、双机过渡段 |
| `weld-template/` | 焊接模板 | WeldTemplate、模板匹配、包角方向、操作日志 |
| `weld-seam/` | 焊缝规划 | WeldSeam、规划过滤、ILIdx 分组、后处理、几何类型、PoseTValue |
| `coarse-positioning/` | 粗定位 | CoarseVision、粗定位、龙门补偿矩阵、排单初始化 |
| `scanning/` | 精定位与扫描 | ScanTarget、PrecisePositioning、VCM、推扫、拍照点、FineLoc |
| `capacity/` | 产能统计 | 产能统计、清枪计数、操作日志事件 |
| `weld-tracking/` | 焊接跟踪 | WeldTracking、TrackingMode、焊缝跟踪传感器 |
| `coordinate/` | 坐标与矩阵 | Coordinate、MapMatrix、标定、PhantomType、IRobotCoordinateService |
| `workflow/` | 状态机与工作流 | StateMachine、FSM、PoseRole、TransitionPlan、工件持久化、排单 |
| `frontend/` | 前端界面 | Blazor、React、Three.js、面板、渲染、UI 交互 |
| `device-robot/` | 设备与机器人 | Robot、Fanuc、FTP、TCP、设备配置 |
| `tools/` | 工具与其他 | CLI、几何参数、空气墙、文件浏览器、不属于以上任何领域的通用工具 |

**路由规则**：一个知识条目只归入一个领域。如果跨领域，拆成多个知识文件。无法判断时归入 `tools/`。

## Workflow

### 1. 收集变更

并行执行以下操作：

- `git log --oneline` 自上次 record 日期（或用户指定起点）
- `git diff archive/CONTEXT.md` 查看术语变更
- 检查 `docs/adr/` 是否有新增或修改的 ADR
- 从 git diff 总结关键文件变更

### 2. 确定 slug

询问用户："这个会话用什么 slug 概括？"（kebab-case，例如 `transition-plan-refactor`）。

用户没有想法时，根据收集到的变更自行拟定，让用户确认或修改。

### 3. 生成 Record

创建 `archive/records/YYYY-MM-DD-<slug>.md`。

Record 模板（保持不变）：

```markdown
# <Title>

> **TL;DR**: <one-line summary> `keyword1` `keyword2` — <what changed>

## Background

<为什么做这件事。未来读者需要的上下文。>

## Decisions

<做了什么决定。关键取舍。反直觉的选择。>

## Results

<实际改了什么。文件、模块、行为。>

## Legacy

<遗留项、后续工作、有意推迟的事情。>
```

参考 `archive/records/` 中的已有记录作为风格参考。

### 4. 检测可复用知识 & 领域路由

分析本次会话是否产出了**可复用的技术知识**（模式、规则、配置、架构约束——未来开发会需要的东西）。

**判断标准**：
- 如果只是 bug 修复或一次性调整，不需要知识文件
- 如果涉及架构模式、设计规则、接口约定、算法细节，则提取

对每条可复用知识：

1. **领域路由**：根据上面「领域路由表」判断应归入哪个领域文件夹
2. **slug 定名**：用 kebab-case，简短但能区分同领域内其他文件
3. **判断新建还是更新**：
   - 检查目标领域文件夹下是否已有同名或高度相关的知识文件
   - 已有 → 建议更新（扩展内容）
   - 没有 → 新建

**多知识产出**：一个会话可能涉及多个领域。对每个领域独立判断，产出多个知识文件。例如一次重构同时涉及 `coordinate/` 和 `workflow/`，应产出两个知识文件。

**向用户确认**：列出所有拟创建/更新的知识文件清单（领域 + slug + 一句话说明），让用户确认后再写入。格式示例：

```
拟产出知识文件：
  [新建] archive/knowledge/coordinate/phantom-type-usage.md — Phantom-type 坐标标签的使用规则
  [更新] archive/knowledge/workflow/transition-paradigm.md — 补充 TargetPoseRef 边界情况
```

### 5. 生成知识文件

确认后，为每个知识文件写入内容。**如果涉及多个领域，可以 spawn agent 并行写入。**

知识文件模板：

```markdown
---
name: <kebab-case-slug>
description: <一句话摘要>
metadata:
  type: knowledge
---

# <标题>

`<关键词1>` `<关键词2>` — <一句话总结>

## 背景 / 问题

<为什么需要这个知识。解决什么问题。>

## 核心设计

<架构、模式、算法、接口设计。>

## 关键规则

<约束、不变量、必须遵守的约定。>

## 交叉引用

- [相关 record](../records/YYYY-MM-DD-xxx.md)
- [相关知识](../knowledge/<domain>/<file>.md)
```

要求：
- frontmatter 严格使用上面的格式（`name` + `description` + `metadata.type`）
- 正文以标题行开始，标题行格式：`` `关键词` `关键词` — 一句话总结 ``
- 交叉引用使用相对路径，指回 record 或其他知识文件

### 6. 更新 INDEX.md

将新 record 添加到 `## Records` 部分：

```markdown
- [YYYY-MM-DD-<slug>](archive/records/YYYY-MM-DD-<slug>.md)
  `<keyword1>` `<keyword2>` — <TL;DR summary>
```

将新增/更新的知识条目添加到 `## Knowledge` 对应领域子节。格式与现有条目一致：

```markdown
- [<slug>](knowledge/<domain>/<slug>.md) — <一句话说明>
```

如果领域子节不存在（新增领域），按路由表格式创建新的三级标题。

每行控制在 150 字符以内。

## 路径约定

| 路径 | 用途 |
|---|---|
| `archive/records/` | 会话 record，按日期命名 |
| `archive/knowledge/<domain>/` | 领域知识文件，按路由表分发 |
| `archive/INDEX.md` | 总索引 |
| `archive/CONTEXT.md` | 术语表 |
| `docs/adr/` | 架构决策记录 |
