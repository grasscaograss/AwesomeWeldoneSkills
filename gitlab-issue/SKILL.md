---
name: gitlab-issue
description: 与开发人员协作创建 GitLab Issue。触发场景：(1) 用户说"建个 issue"、"提个 bug"、"记录一个问题"、"有个新需求"；(2) 用户描述了一个问题或需求并要求记录到 GitLab
---

# GitLab Issue 协作创建

引导开发人员明确 Issue 内容，自动推断标签，通过 API 创建。

## GitLab 配置

| 配置项 | 值 |
|--------|-----|
| URL | `http://gitlab.roboticplus.com:2022` |
| Project ID | `305` |
| API Base | `http://gitlab.roboticplus.com:2022/api/v4/projects/305` |
| Token | 环境变量 `$env:GITLAB_TOKEN` 或用户提供 |

## Token 检查（步骤 0）

每次开始工作前，使用 **PowerShell 工具**（不要用 Bash 工具）检查 `$env:GITLAB_TOKEN` 是否已设置：

```powershell
if ($env:GITLAB_TOKEN) { 'Token exists' } else { 'Token not set' }
```

> ⚠️ **必须使用 PowerShell 工具**，不要使用 Bash 工具。Bash 工具底层是 `/usr/bin/bash`，不认识 `$env:VAR` 语法；用 `powershell -Command` 包装也不行，双引号内 `$env:` 会被 bash 先展开导致变量名损坏。

- **已设置**（输出 `Token exists`）→ 直接进入步骤 1
- **未设置** → 引导用户创建并配置：

1. 告诉用户：当前未配置 GitLab Token，需要创建一个才能操作 Issue
2. 引导用户打开 `http://gitlab.roboticplus.com:2022/-/profile/personal_access_tokens`，创建一个 Personal Access Token，勾选 `api` 权限
3. 让用户在终端执行以下命令设置环境变量（永久生效）：
   ```powershell
   # 在 PowerShell profile 中持久化
   Add-Content -Path $PROFILE -Value "`n`$env:GITLAB_TOKEN = '<用户粘贴的token>'"
   $env:GITLAB_TOKEN = '<用户粘贴的token>'
   ```
4. 或者让用户在 Claude Code 中直接输入 `! $env:GITLAB_TOKEN = '<token>'` 来临时设置
5. 设置完成后继续步骤 1

**注意**：不要自己生成或猜测 Token 值，必须由用户提供。

## 工作流程

### 步骤 1：理解意图

从用户的描述中提取：
- **类型**：根据语义自动判断
- **初步内容**：问题/需求的核心描述

类型判断规则：
| 用户表达 | 类型 |
|---------|------|
| 崩溃、报错、异常、不对、不生效、失败了、bug | 类型::缺陷 |
| 新功能、需要、能不能、想要、需求、支持 | 类型::功能 |
| 优化、改进、太慢、不好用、重构、改善 | 类型::优化 |
| 重构、整理、清理、迁移 | 类型::重构 |

### 步骤 2：引导补充内容

根据类型，引导用户补充关键信息（用自然对话方式，不要一次性抛出所有问题）。

#### 类型::缺陷

引导获取（按顺序，已有信息跳过）：
1. **问题现象**：具体表现是什么？
2. **复现步骤**：怎么触发这个问题？
3. **期望行为**：应该是什么样子？
4. **影响范围**：哪些场景受影响？现场/研发？
5. **环境信息**：分支、工件版本（可选）

生成正文格式：
```markdown
## 问题现象

{描述}

## 复现步骤

1. {步骤1}
2. {步骤2}

## 期望行为

{描述}

## 实际行为

{描述}

## 影响范围

{描述}
```

#### 类型::功能

引导获取：
1. **需求背景**：为什么要做？谁提出？
2. **功能描述**：具体要实现什么？怎么使用？
3. **验收标准**：做到什么程度算完成？

生成正文格式：
```markdown
## 需求背景

{描述}

## 功能描述

{描述}

## 验收标准

- [ ] {标准1}
- [ ] {标准2}
```

#### 类型::优化 / 类型::重构

引导获取：
1. **现状**：当前有什么问题？
2. **目标**：改进后达到什么效果？
3. **影响范围**：涉及哪些模块？需要注意什么？

### 步骤 3：推断模块

从用户描述中匹配关键词，自动推断模块标签：

| 关键词 | 模块 |
|--------|------|
| 焊缝、打断、合并、WSG、WeldSeamGroup | 模块::焊缝规划 |
| 模板、工艺、参数、焊道 | 模块::焊接模板 |
| 粗定位、点云、匹配、coarse | 模块::粗定位 |
| 精定位、视觉、拍照、fine、iLaser | 模块::精定位 |
| 扫描、校准、MapMatrix、calibration | 模块::扫描校准 |
| 机器人、外部轴、驱动、E1、E2 | 模块::机器人控制 |
| 双臂、包角、协同、wrapping | 模块::双臂协同 |
| 状态机、FSM、流程、工作流 | 模块::状态机 |
| 前端、Blazor、React、页面、UI、组件 | 模块::前端 |
| 插件、ZMJ、AGV、Rhino | 模块::插件 |
| CI、构建、迁移、发布、electron | 模块::基础设施 |
| 产能、统计、焊丝、消耗 | 模块::产能统计 |

如果无法推断，用 AskUserQuestion 让用户从列表选择。

### 步骤 4：确认并创建

向用户展示完整的 Issue 摘要：

```
📋 Issue 预览
━━━━━━━━━━━━━━━━━━
标题：{标题}
类型：{类型}
优先级：{优先级}
模块：{模块}
━━━━━━━━━━━━━━━━━━
{正文预览}
```

用户确认后，通过 API 创建：

```powershell
$Headers = @{ "PRIVATE-TOKEN" = $Token; "Content-Type" = "application/json" }
$Body = @{
    title = "{标题}"
    description = "{正文}"
    labels = "类型::xxx,优先级::xxx,模块::xxx,阶段::待办"
} | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$ApiBase/issues" -Method Post -Headers $Headers -ContentType "application/json" -Body $Body
```

创建成功后返回 Issue 链接：`http://gitlab.roboticplus.com:2022/robimweld/weldone/-/issues/{iid}`

### 步骤 5：上传附件（可选）

用户可能要求上传截图、视频等附件到 Issue。

上传流程：先调 `POST $ApiBase/uploads` 上传文件拿 markdown 引用，再调 `POST $ApiBase/issues/{iid}/notes` 发布为评论。

**关键约束**：
- **中文文件名必须先 cp 为 ASCII 名再上传**，否则 GitLab API 返回 `Bad Request`
- 上传接口返回 JSON，取 `markdown` 字段放入评论 `body` 即可在 Issue 中展示

## 规则

1. **标签必打齐**：每个 Issue 必须有 类型 + 优先级 + 模块 + 阶段，四类标签缺一不可
2. **创建前必须获取已有标签**：每次创建 Issue 前，必须先调用 `GET /projects/:id/labels?per_page=100` 获取项目已有标签列表，只从中选择。**绝不允许使用列表中不存在的标签**——GitLab API 会自动创建新标签，这是错误行为。如果已有标签中没有合适的，必须先向用户确认
3. **优先级默认**：如果用户未指定，缺陷默认 `优先级::P1 高`，功能/优化/重构默认 `优先级::P2 中`，但必须告知用户
4. **对话优先**：用自然对话引导，不要一次性列出所有问题让用户填表
5. **信息充分才创建**：核心信息（现象/需求+模块）不完整时主动追问，不要创建空泛的 Issue
6. **中文标题**：标题用中文，简洁概括核心内容，不超过 50 字
7. **不重复创建**：创建前搜索是否已有类似 Issue，避免重复
8. **不写代码级分析**：Issue 正文只记录问题现象、复现步骤、期望/实际行为等用户可感知的信息。不要在正文中写入原因分析、代码定位、修复方案等内容——这些属于开发过程，不应由 Issue 创建时自动生成
