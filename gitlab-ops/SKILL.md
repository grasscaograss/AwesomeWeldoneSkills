---
name: gitlab-ops
description: 操作 GitLab 项目（Issue / Label / MR / Milestone 管理）。触发场景：(1) 用户要求创建/查询/修改 GitLab Issue、标签、里程碑、MR；(2) 用户说"gitlab"、"issue"、"标签"、"看板"；(3) 批量管理项目标签或 Issue 状态
license: Apache-2.0
allowed-tools: Bash
metadata:
  author: weldone-team
  version: "1.0.0"
---

# GitLab 项目操作

Weldone 项目的 GitLab 实例信息：

| 配置项 | 值 |
|--------|-----|
| URL | `http://gitlab.roboticplus.com:2022` |
| Project ID | `305` |
| API Base | `http://gitlab.roboticplus.com:2022/api/v4/projects/305` |

**Token 获取**：从用户获取，或读取环境变量 `$env:GITLAB_TOKEN`。

## API 调用方式

使用 pwsh 7（默认 UTF-8；curl 在 Windows 中文编码有问题）：

```pwsh
$Headers = @{ "PRIVATE-TOKEN" = $env:GITLAB_TOKEN; "Content-Type" = "application/json" }
$Base = "http://gitlab.roboticplus.com:2022/api/v4/projects/305"
```

或使用 Python（本环境有 `python` 可用）。

## 标签体系

项目使用 `维度::内容` 格式的 scoped labels，共 5 个维度 30 个标签：

| 维度 | 色系 | 值 |
|------|------|-----|
| 类型（蓝） | `#2E86C1` | 缺陷、功能、优化、重构、杂务 |
| 优先级（红） | `#C0392B` | 紧急、高、中、低 |
| 阶段（绿） | `#27AE60` | 待办、开发中、审查中、待测试、测试通过、已完成 |
| 模块（紫） | `#8E44AD` | 焊缝规划、焊接模板、粗定位、精定位、扫描校准、机器人控制、双臂协同、状态机、前端、插件、基础设施、产能统计 |
| 状态（黄） | `#F1C40F` | 阻塞、需要讨论、搁置、不做 |
**规则**：每个 Issue 必须有 类型 + 优先级 + 模块。阶段标签互斥（同一时间只有一个）。

## CI 自动化（阶段流转）

MR 创建 → `阶段::待测试`，测试通过后手动设 `阶段::测试通过`，MR 合并到 develop → `阶段::已完成`。详见 `.gitlab-ci.yml` 中的 `label-on-mr` 和 `label-on-merge` job。脚本位于 `scripts/gitlab-label-on-merge.ps1`。

## 常用操作

### 创建 Issue

使用 `gitlab-issue` skill（对话式引导创建，自动推断标签）。用户说"建个 issue"时优先触发该 skill。

网页端兜底：`.gitlab/issue_templates/` 下有 Bug缺陷报告、功能请求、优化建议三个模板。

### 查询 Issue

```python
# 按标签查询
GET /issues?labels=类型::缺陷,模块::粗定位&state=opened

# 按关键词搜索
GET /issues?search=关键词

# 获取单个 Issue
GET /issues/{iid}

# 获取 Issue 评论
GET /issues/{iid}/notes
```

### 创建 Issue

```python
POST /issues
{
    "title": "标题",
    "description": "描述（支持 Markdown）",
    "labels": "类型::功能,优先级::中,模块::焊缝规划,阶段::待办",
    "assignee_ids": [用户ID]
}
```

创建后务必打齐 3 个必选标签（类型 + 优先级 + 模块）。

### 更新 Issue

```python
PUT /issues/{iid}
{
    "labels": "类型::缺陷,优先级::高,模块::粗定位,阶段::开发中",
    "state_event": "close"  # 关闭 Issue
}
```

### 标签管理

```python
# 列出所有标签
GET /labels

# 创建标签
POST /labels
{ "name": "维度::内容", "color": "#HEX", "description": "说明" }

# 删除标签
DELETE /labels/{name}  # name 需要 URL encode

# 替换 Issue 标签时，先加新再删旧（或用 PUT issues/{iid} 的 labels 字段直接替换）
```

### Merge Request

```python
# 列出 MR
GET /merge_requests?state=opened

# 获取 MR 详情
GET /merge_requests/{iid}

# 获取 MR diff
GET /merge_requests/{iid}/changes

# MR 评论
POST /merge_requests/{iid}/notes
{ "body": "评论内容" }
```

### 里程碑

```python
# 列出
GET /milestones

# 创建
POST /milestones
{ "title": "Sprint X", "start_date": "2026-05-01", "due_date": "2026-05-15" }

# 关联 Issue
PUT /issues/{iid}
{ "milestone_id": 里程碑ID }
```

## 操作原则

1. **创建 Issue 必须打齐标签**：类型 + 优先级 + 模块，缺一不可
2. **修改标签先确认影响范围**：先查关联 Issue 数量，再决定是否替换
3. **删除标签前必须先迁移**：把旧标签从所有 Issue 替换为新标签，确认无关联后再删
4. **MR 创建时关联 Issue**：description 中写 `Closes #iid` 或 `Related to #iid`
5. **分页注意**：列表 API 默认每页 20 条，用 `per_page=100` + `page=N` 遍历
6. **中文编码**：标签名含中文时，URL 请求必须 encode（Python `urllib.parse.quote`）
