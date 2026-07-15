---
name: periodic-review
description: Generate monthly or yearly project review summaries with context-aware knowledge evolution tracking. Collects from archive/records/, git log, archive/contexts/*/knowledge/ (grouped by context then domain), and docs/adr/ for the given period. Use when user says "monthly review", "yearly summary", "quarterly review", calls /periodic-review, or mentions "总结", "回顾", "月报", "年报".
---

# Periodic Review

## Quick start

```
/periodic-review              → default: previous calendar month
/periodic-review 2026-05      → specific month
/periodic-review 2026         → full year (Jan–Dec)
```

## Workflow

### 1. Determine time range

- No argument: previous calendar month
- `YYYY-MM`: that specific month
- `YYYY`: January–December of that year

### 2. Collect materials (parallel)

Run these collections simultaneously:

| Source | Method | Purpose |
|--------|--------|---------|
| Records | List files under `archive/records/` with date within range | 设计决策和实现记录 |
| Git log | `git log --after=<start> --before=<end> --oneline --stat` | 变更统计 |
| Knowledge | List files under `archive/contexts/*/knowledge/` modified in range, grouped by context then sub-domain | 领域知识演进 |
| ADRs | Files under `archive/adr/` or `docs/adr/` created or modified in range | 架构决策 |

### 3. Domain-grouped knowledge collection

Knowledge 按上下文→子领域嵌套组织（`archive/contexts/<ctx>/knowledge/<domain>/`）。统计每个上下文及其子领域的变化：

```
archive/contexts/
├── weld-core/knowledge/       weld-seam  wsg-merge  transition-line  weld-template  dual-arm
├── robotics/knowledge/        coordinate  coarse-positioning
├── orchestration/knowledge/   workflow  scanning
└── peripheral/knowledge/      frontend  device-robot  capacity  weld-tracking  tools
```

对每个上下文及其子领域，收集以下信息：

1. **当前文件数** — 列出目录下所有 `.md` 文件
2. **期内的变化** — 通过 `git log --diff-filter=ACDMR -- <path>` 获取新增(A)、修改(M)、删除(D)、重命名(R)的文件
3. **变化摘要** — 读取每个变更文件的 TL;DR 行（标题后的 blockquote）

### 4. Domain health assessment

对每个领域计算健康指标：

| 指标 | 阈值 | 状态 |
|------|------|------|
| 文件数 ≤ 5 | 基线 | — |
| 文件数 > 10 | 可能膨胀 | ⚠️ Bloat |
| 文件数 > 15 | 强烈建议拆分 | 🔴 Oversized |
| 期内新增 > 3 | 快速增长 | 📈 Growth |
| 期内无变化 | 稳定 | Stable |
| 单文件目录 | 疏离 | ⚠️ Isolated |

### 5. Deep analysis for active domains

对期内变化 ≥ 3 个文件的领域，spawn 一个子 agent 进行深度分析：

**Prompt 模板：**

```
分析 `archive/contexts/<ctx>/knowledge/<domain>/` 目录下近期（<period>）的变化趋势。

读取该目录下所有文件的 TL;DR，结合 archive/records/ 中与该领域相关的记录。

回答：
1. 这个领域在做什么方向上的演进？
2. 是否有反复修改同一概念的情况？（暗示设计不稳定）
3. 是否有知识碎片化的迹象？（多个文件描述同一子主题）
4. 对该领域的下一步建议。
```

如果任意领域文件数 > 15，或变化 ≥ 5 个文件，在 Open items 中添加建议：

```
⚠️ <ctx>/<domain>/ 文件数达到 N，增长过快。建议执行 /knowledge-reorg 检查是否需要拆分。
```

### 6. Generate review document

Create `archive/reviews/YYYY-MM.md` (monthly) or `archive/reviews/YYYY.md` (yearly).

Structure:

```markdown
# Review: <period>

> **TL;DR**: <one-paragraph summary of the period>

## Key decisions

<Major decisions made this period, with links to records/ADRs.
每个决策一行，附关键 tag。>

## Completed work

<Summary from records + git log. Group by theme/topic.
保留 commit 统计摘要（文件数、增删行数）。>

## Knowledge evolution by context

### <domain>/（+N 文件）
- 新增 <filename>.md — <TL;DR 摘要>
- 修改 <filename>.md — <变更要点>
- 删除 <filename>.md — <原因>

（仅列出有变化的领域，按变化量降序排列。无变化的领域省略。）

## Domain health

| Domain | Files | Changes | Status |
|--------|-------|---------|--------|
| dual-arm | 5 | +2 | 📈 Growth |
| workflow | 7 | 0 | Stable |
| weld-seam | 5 | +5 | ⚠️ Bloat |
| ... | ... | ... | ... |

（列出全部领域，按活跃度降序排列。活跃度 = 变化文件数，同排名按文件数降序。）

## Open items

<Work started but not completed. Decisions deferred. Risks to watch.
包含来自步骤 5 的深度分析结论和 /knowledge-reorg 建议。>
```

### 7. Update archive/INDEX.md

Add the review entry under `## Reviews`:

```markdown
- [YYYY-MM](archive/reviews/YYYY-MM.md) — <one-line summary>
```

For yearly: `- [YYYY](archive/reviews/YYYY.md) — <one-line summary>`

## Execution checklist

完成 review 后确认以下步骤均已完成：

- [ ] 时间范围已确定
- [ ] Records / Git log / Knowledge / ADRs 四类材料已收集
- [ ] 领域变化统计已完成
- [ ] Domain health 表已生成
- [ ] 变化 ≥ 3 的领域已触发深度分析
- [ ] 文件数 > 15 的领域已标记 /knowledge-reorg 建议
- [ ] Review 文档已写入 `archive/reviews/`
- [ ] `archive/INDEX.md` 的 `## Reviews` 已更新
