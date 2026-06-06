---
name: superpowers
description: 完整的 agent 开发方法论技能集。涵盖从头脑风暴到分支完成的完整工作流：设计→计划→实现→审查→交付。当需要结构化开发流程、TDD、系统调试、代码审查、git worktree 隔离开发时使用。源自 Jesse Vincent 的 superpowers 项目。
license: Apache-2.0
metadata:
  author: superpowers (obra)
  version: "1.0.0"
  source: https://github.com/obra/superpowers
---

# Superpowers — Agent 开发方法论

源自 [superpowers](https://github.com/obra/superpowers) 的完整开发方法论，为编码 agent 提供结构化的工作流。

## 核心流程

```
头脑风暴 → 编写计划 → (子代理驱动 / 内联执行) → 完成分支
                ↕                    ↕
         TDD 循环              代码审查 (请求/接收)
                ↕
        验证后完成 + 系统调试
```

## 模块索引

| 模块 | 用途 | 何时使用 |
|------|------|----------|
| [using-superpowers](references/using-superpowers.md) | 入口规则 | 任何对话开始时 |
| [brainstorming](references/brainstorming.md) | 设计对话 | 实现任何创意工作之前 |
| [writing-plans](references/writing-plans.md) | 编写计划 | 有需求/规格后，写代码前 |
| [executing-plans](references/executing-plans.md) | 执行计划 | 有已写好的实现计划时 |
| [subagent-driven-development](references/subagent-driven-development.md) | 子代理驱动 | 有独立任务的实现计划 |
| [dispatching-parallel-agents](references/dispatching-parallel-agents.md) | 并行分派 | 2+ 个独立任务可并行时 |
| [test-driven-development](references/test-driven-development.md) | TDD | 实现功能或修复 bug 前 |
| [systematic-debugging](references/systematic-debugging.md) | 系统调试 | 遇到 bug、测试失败或异常行为时 |
| [verification-before-completion](references/verification-before-completion.md) | 完成验证 | 声称工作完成/通过前 |
| [requesting-code-review](references/requesting-code-review.md) | 请求审查 | 完成任务、实现功能或合并前 |
| [receiving-code-review](references/receiving-code-review.md) | 接收审查 | 收到代码审查反馈时 |
| [using-git-worktrees](references/using-git-worktrees.md) | 工作区隔离 | 需要隔离的功能开发前 |
| [finishing-a-development-branch](references/finishing-a-development-branch.md) | 完成分支 | 实现完成、测试通过后 |
| [writing-skills](references/writing-skills.md) | 编写技能 | 创建/编辑/验证 skill 时 |

## 优先级规则

1. **用户的明确指令**（CLAUDE.md、直接请求）— 最高优先级
2. **Superpowers 技能** — 覆盖默认系统行为
3. **默认系统提示** — 最低优先级

如果认为某个模块可能适用（哪怕只有 1% 的可能性），就务必阅读该模块。

---
*Source: [superpowers](https://github.com/obra/superpowers) by Jesse Vincent*
