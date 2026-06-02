---
name: git-branch-merge
description: >
  合并差异较大的 Git 分支的结构化方法论。当源分支与目标分支差异过大，直接 merge 不可控时，
  采用"逐 spec 迁移"的方式：将源分支的提交按功能意图逐个归纳为 spec，用户审核后在目标分支重新实现。
  触发场景：(1) 两个分支分叉时间较长（超过1个月），(2) 直接 merge 冲突太多，
  (3) 用户说"合并分支"、"两个分支差异很大"、"分支有很多冲突"、"迁移功能"。
license: Apache-2.0
allowed-tools: Bash Agent
metadata:
  author: weldone-team
  version: "1.0.0"
---

# Git 大分支迁移方法论

## 第一步：诊断现状

```bash
# 找到分叉点
git merge-base <target> <source>

# 源分支独有的提交数
git log --oneline <source> ^<target> | wc -l

# 分叉时间
git log --format="%ai" <merge-base-hash> -1

# 文件差异统计
git diff --stat <target> <source> | tail -3
```

根据结果判断整体策略，参见 [references/complexity-guide.md](references/complexity-guide.md)。

## 第二步：建立安全网 + 初始化进度文件

```bash
git tag backup/<source>-before-merge <source>
git tag backup/<target>-before-merge <target>
```

在 `.claude/tmp/merge-progress.md` 创建进度文件：

```markdown
# 分支迁移进度

来源：<source> → 目标：<target>
开始：<date>

## 进度概览
✅ 0 完成 / 🔄 0 进行中 / ⏭ 0 跳过 / ⬜ 待归纳

## 待处理提交
（将 git log 输出粘贴在此，逐步消耗）

## Spec 列表
（每完成一个在此追加）
```

## 第三步：归纳下一个 spec（循环起点）

从进度文件的"待处理提交"中取下一批，按功能意图归纳出**一个** spec，提交用户审核。

归纳方法见 [references/commit-grouping.md](references/commit-grouping.md)。

**输出格式：**

```
📋 Spec N：<功能意图标题>

包含提交：<hash1> <message>
          <hash2> <message>
涉及文件：src/xxx, src/yyy
意图描述：<一两句话说清楚这组提交要实现什么、解决什么问题>
建议方式：[ ] opsx:new  [ ] 直接迁移
```

等待用户：**批准** / **修改描述** / **跳过**（记入进度文件跳过区域）

## 第四步：执行迁移

**每个 spec 必须启动一个新的 sub-agent 来完成**，不在主线上下文中直接操作。这样可以防止主线上下文被实现细节撑爆，保证整个迁移任务的进度管理始终清晰。

Sub-agent 的 prompt 应包含：
- spec 的意图描述
- 涉及的提交 hash（供 sub-agent 读 diff）
- 进度文件路径（`.claude/tmp/merge-progress.md`）
- 当前目标分支名
- 实现方式（直接迁移 / opsx:new）

Sub-agent 完成后返回：实现结果 + 构建是否通过。

实现方式参考：
- **直接迁移**（简单明确）→ 参见 [references/direct-apply.md](references/direct-apply.md)
- **opsx:new**（复杂/需要重新设计）→ 参见 [references/spec-format.md](references/spec-format.md)

## 第五步：验证 + 更新进度 → 回到第三步

```bash
dotnet build
```

构建通过后，更新 `.claude/tmp/merge-progress.md`：
- 将该 spec 状态改为 ✅，填入实现方式
- 更新概览计数

回到第三步，处理下一批提交。所有提交处理完毕后，迁移结束。

## 关键原则

- **一次只处理一个 spec**：归纳一个，审核一个，迁移一个
- **每个 spec 用独立 sub-agent 实现**：主线上下文只负责进度管理和 spec 归纳，实现细节交给 sub-agent
- **进度文件是唯一的任务指引**：随时打开 `.claude/tmp/merge-progress.md` 查看当前状态
- **跳过不等于丢失**：跳过的提交记录在进度文件，便于事后 review
