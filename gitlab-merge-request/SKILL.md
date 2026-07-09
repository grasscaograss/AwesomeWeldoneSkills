---
name: gitlab-merge-request
description: 专门创建 Weldone GitLab Merge Request。触发场景：(1) 用户说"提 MR"、"创建 merge request"、"合并请求"、"发起合并"；(2) 用户要求把当前分支合并到 develop、master、远程同名分支或指定远程分支；(3) 用户未指定目标分支时默认合到当前分支对应的远程同名分支；(4) 用户已经提交代码并要求推送源分支、查重、创建 MR。
license: Apache-2.0
allowed-tools: Bash
metadata:
  author: weldone-team
  version: "1.0.0"
---

# GitLab Merge Request 创建

在 Weldone GitLab 项目中创建 Merge Request。借鉴 `gitlab-issue` 的协作方式：先确认 token 和目标分支，再检查提交范围和重复 MR，最后通过 API 创建。

## GitLab 配置

| 配置项 | 值 |
|--------|-----|
| URL | `http://gitlab.roboticplus.com:2022` |
| Project ID | `305` |
| API Base | `http://gitlab.roboticplus.com:2022/api/v4/projects/305` |
| Token | 环境变量 `$env:GITLAB_TOKEN` 或用户提供 |

## Token 检查

每次开始前，使用 pwsh 7 检查 token（默认 UTF-8），不要直接用 Bash 语法：

```pwsh
if ($env:GITLAB_TOKEN) { 'Token exists' } else { 'Token not set' }
```

若 token 存在，必须再做一次真实 API 验证：

```pwsh
$Headers = @{ "PRIVATE-TOKEN" = $env:GITLAB_TOKEN }
Invoke-RestMethod -Uri "http://gitlab.roboticplus.com:2022/api/v4/user" -Headers $Headers
```

如果返回 `401 Unauthorized`、`403 Forbidden` 或网络错误，停止创建 MR，告诉用户需要提供具有 `api` 权限的 GitLab Personal Access Token。不要把环境变量存在当作可用认证。

## 工作流程

### 步骤 1：确认当前 Git 状态

在仓库根目录执行：

```pwsh
git status --short
git branch --show-current
git remote -v
```

- 若有未提交改动，先停止并说明需要提交或明确暂存范围。
- 若当前目录不是 Git 仓库，停止并要求切换到仓库根目录。
- 默认使用 `origin` 作为远程；若没有 `origin`，读取 `git remote -v` 后让用户确认。

### 步骤 2：确定目标分支

按用户表达选择目标：

| 用户表达 | 目标分支 |
|----------|----------|
| 未指定目标分支，只说"提 MR"、"创建 MR"、"发起合并" | 当前分支对应的远程同名分支 |
| "合到 develop"、"提到 develop" | `develop` |
| "合到 master" | `master` |
| "合并到远程同分支"、"合到远程分支上" 且未指定其他分支 | 当前分支对应的远程同名分支 |
| 明确说出分支名 | 用户指定的分支 |

不要把未指定目标分支理解为 `develop`。只有用户明确说"合到 develop"或指定 `develop` 时，目标分支才是 `develop`。

必须先确认目标分支在远程存在：

```pwsh
git ls-remote --heads origin <target-branch>
```

如果用户没有指定目标分支，或者用户说"远程同分支"，并且当前本地分支为 `feature/foo`，目标就是 `origin/feature/foo`。若远程同名分支不存在，停止并说明需要用户指定目标分支或先创建远程同名分支。

### 步骤 3：确定 MR 源分支

GitLab 同项目 MR 的 source 和 target 不能完全相同。按以下规则处理：

1. 如果当前分支名和目标分支不同，默认用当前分支作为 source。
2. 如果当前分支名和目标分支相同，创建一个新的源分支，命名为 `codex/<短描述>`，让它指向当前 HEAD。
3. 如果用户要求"只合当前修复"或"只合某个 commit"，从 `origin/<target>` 新建源分支后 cherry-pick 指定提交。
4. 如果用户明确说"两个都要合并"、"所有 ahead 都要"，不要拆提交；让源分支指向当前 HEAD。

创建同分支目标的源分支示例：

```pwsh
git switch -c codex/<short-slug>
git push -u origin codex/<short-slug>
```

从目标分支 cherry-pick 单个提交示例：

```pwsh
git switch -c codex/<short-slug> origin/<target-branch>
git cherry-pick <commit-sha>
git push -u origin codex/<short-slug>
```

### 步骤 4：检查提交范围

创建 MR 前必须展示或确认提交范围：

```pwsh
git log --oneline origin/<target-branch>..HEAD
git diff --stat origin/<target-branch>..HEAD
```

如果提交范围包含用户未提到的大改动，先提醒并确认。用户已经明确说"都要合并"时，继续执行。

### 步骤 5：生成 MR 标题和正文

标题必须使用 conventional commit 格式，并在 50 个字符以内。标题要简洁但语义完整：概括所有提交共同解决的问题，或概括这组提交的核心变更；必要的主谓宾要保留，不要为了压缩长度删掉改动主体、动作或受影响对象。不要把具体改动细节塞进标题。

```text
fix: 修复工件删除崩溃
feat: GitLab MR 技能支持创建合并请求
refactor: 选择状态逻辑简化分支判断
```

标题生成规则：

- 使用 `fix:`、`feat:`、`refactor:`、`chore:`、`docs:`、`test:`、`ci:` 等 conventional commit type。
- 总长度控制在 50 个字符以内，包含 type 前缀、冒号和空格；推荐 24-36 个中文字符左右。
- `type:` 后的描述优先保留"改动主体 + 动作 + 对象/结果"，例如"GitLab MR 技能支持创建合并请求"，不要压缩成"支持MR创建"这类缺少上下文的短语。
- 多个提交时，不逐条列提交标题；提炼它们共同解决的问题。
- 如果无法在 50 字内覆盖所有细节，标题只写核心问题，细节放入 description。

正文使用以下格式：

```markdown
## 变更内容

- {变更点 1}
- {变更点 2}
- {变更点 3}

## 包含提交

- `{sha}` {commit subject}

## 验证

- {已执行的验证命令或文件诊断}
```

description 必须写完整具体的变更内容，包括每个关键提交的实际改动、影响范围和验证结果。

若关联 Issue，在正文中加入 `Closes #iid` 或 `Related to #iid`。

### 步骤 6：查重并创建 MR

优先使用脚本 `scripts/new_gitlab_merge_request.ps1`。它会验证 token、验证 source/target 分支存在、查询同 source/target 的 opened MR，并在不存在时创建。

默认创建 MR 时启用 squash，也就是 GitLab 页面里的"压缩提交"保持勾选。只有用户明确要求保留所有提交、不压缩提交时，才给脚本传 `-NoSquash`。

默认创建 MR 后请求开启"流水线成功后自动合并"。GitLab API 需要先创建 MR，再调用 merge endpoint 并传 `merge_when_pipeline_succeeds = $true`。只有用户明确说"不要自动合并"、"只创建 MR"或"不勾选流水线成功自动合并"时，才给脚本传 `-NoMergeWhenPipelineSucceeds`。Draft MR 不要开启自动合并。

```pwsh
& "<skill-dir>\scripts\new_gitlab_merge_request.ps1" `
  -SourceBranch "<source-branch>" `
  -TargetBranch "<target-branch>" `
  -Title "<MR 标题>" `
  -Description "<MR 正文>" `
  -RemoveSourceBranch
```

如果脚本返回已存在 MR，直接把已有 MR 链接返回给用户，不要重复创建。

## 脚本说明

`scripts/new_gitlab_merge_request.ps1` 参数：

| 参数 | 说明 |
|------|------|
| `SourceBranch` | MR 源分支，必填 |
| `TargetBranch` | MR 目标分支，必填 |
| `Title` | MR 标题，必填 |
| `Description` | MR 正文，必填，写全具体变更内容 |
| `RemoveSourceBranch` | 合并后删除源分支 |
| `NoSquash` | 明确不启用 squash；默认不传，创建 MR 时会勾选压缩提交 |
| `NoMergeWhenPipelineSucceeds` | 明确不启用流水线成功后自动合并；默认不传，创建 MR 后会请求开启自动合并 |
| `Draft` | 创建 Draft MR |
| `Force` | 即使存在同 source/target opened MR 也尝试创建 |

## 规则

1. 必须使用 pwsh 7 调 GitLab API，并保持默认 UTF-8，避免 Windows 中文编码问题。
2. 必须真实验证 `$env:GITLAB_TOKEN`，不要只检查变量是否存在。
3. 必须先查远程目标分支是否存在。
4. 必须先查是否已有相同 source/target 的 opened MR。
5. source 和 target 相同时，必须创建 `codex/` 源分支，不要直接把同名本地分支 push 到目标分支。
6. 创建同分支目标 MR 时，默认包含 `origin/<target>..HEAD` 的所有 ahead 提交；若用户只要部分提交，再用 cherry-pick 源分支。
7. 如果工作区有未提交改动，停止并要求先提交；不要把未提交改动隐式带入 MR。
8. MR title 必须是 50 个字符以内的 conventional commit 格式，简要总结所有提交的共同问题或核心变更，并保留必要的主谓宾。
9. MR description 必须写全具体变更内容，不要用标题替代正文；脚本会拒绝空 description。
10. 未指定目标分支时默认目标是当前分支对应的远程同名分支，不要默认 `develop`。
11. 提 MR 默认勾选压缩提交；只有用户明确要求"不压缩"、"保留所有提交"时才关闭 squash。
12. 提 MR 默认勾选流水线成功后自动合并；只有用户明确要求不要自动合并时才关闭。若 GitLab 因权限、审批、Draft 状态或 merge checks 拒绝自动合并请求，保留已创建 MR，并在结果中说明 `merge_when_pipeline_succeeds` 请求失败原因。
13. 创建成功后返回 MR 链接、source、target、包含提交范围、squash 状态、`merge_when_pipeline_succeeds` 状态和当前 CI/merge 状态。
