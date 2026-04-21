---
name: modelbase-fsm-update
description: >
  重新读取 ModelBase 状态机源文件，将最新内容同步到 modelbase-fsm skill。
  当用户说"更新状态机 skill"、"同步 FSM skill"、"状态机有改动"时使用。
---

# 更新 ModelBase FSM Skill

当源文件发生变动时，按以下步骤更新 `~/.claude/skills/modelbase-fsm/SKILL.md`。

## 需要读取的源文件

必须全部读取，不可遗漏：

```
1. src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSM.FSMScript
2. src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSMEngine_EnumDefine.cs
3. src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSMEngine.cs
4. src/Weldone.Application/StateEngines/ModelBase/ModelBaseFSMAppService.cs
5. src/Weldone.Application.Contracts/Workflows/ScanWeldWorkflowData.cs
6. src/Weldone.Application.Contracts/Workflows/FullWorkflowData.cs
7. src/Weldone.Application/States/ModelBase/ 下所有 .cs 文件（含 Plan/ 子目录）
```

## 执行步骤

### Step 1: 读取所有源文件

读取上述 7 个位置的文件。对于 `States/ModelBase/` 目录，用 Glob 获取所有 `**/*.cs` 文件后逐一读取。

### Step 2: 比对差异

与当前 `~/.claude/skills/modelbase-fsm/SKILL.md` 的内容逐节比对，定位变动：

- **FSMScript 变动** → 更新顶层/内层状态图、节点枚举、转移事件、清枪子流程
- **EnumDefine 变动** → 更新枚举代码块
- **Engine 变动** → 更新图变换表、Executor 表
- **AppService 变动** → 更新关键服务表（如有新增公开方法）
- **WorkflowData 变动** → 更新数据结构节
- **节点实现变动** → 更新节点速查表（行数、职责描述）
- **新增/删除节点文件** → 增删速查表条目，同步更新状态图

### Step 3: 生成更新内容

按 SKILL.md 的现有结构（节标题不变），仅修改有变动的部分。保持格式一致：
- 状态图用 ASCII 文本
- 枚举用 csharp 代码块
- 表格用 Markdown
- 保留"注意事项"节并按需增补

### Step 4: 写入

用 Edit 工具更新 `~/.claude/skills/modelbase-fsm/SKILL.md` 中有变动的段落。
如果变动范围很大（超过 50% 的节），则用 Write 整体重写。

### Step 5: 报告

向用户报告：
1. 检测到的变动点（哪些节更新了）
2. 新增/删除/重命名的节点（如有）
3. 枚举值变化（如有）
4. 数据结构字段变化（如有）

## 注意事项

- 不要凭记忆填充内容，必须从源文件实际读取
- FSMScript 中的 `def X(Type)` 括号内是节点 Type（DI 用），括号外是节点名（FSM 用）
- `yield return Yield.Event(int)` 中 int 值对应 FSMScript 里的 `数字->EventName`
- Deprecated 字段要标注 `[Obsolete]`，保留在文档中供兼容参考
