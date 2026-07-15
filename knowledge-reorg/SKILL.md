---
name: knowledge-reorg
description: 知识库领域级重组工具。支持健康检查（inspect）、上下文/领域级合并/拆分/移动/合并碎片（merge/split/move/consolidate）、以及从扁平结构自动迁移到多上下文 A1 结构（migrate-to-contexts）。所有操作后自动同步 INDEX.md 与交叉引用。当用户说"重组知识库"、"整理 knowledge"、"合并领域"、"拆分领域"、"迁移到多上下文"时触发。
---

# Knowledge Reorg

知识库按**多上下文**组织：`archive/contexts/<ctx>/knowledge/<domain>/`，词汇表每上下文一份 `archive/contexts/<ctx>/CONTEXT.md`，索引在 `archive/CONTEXT-MAP.md`。本技能提供结构操作、健康检查，以及从扁平结构到多上下文的自动迁移。

## 知识库结构

```
archive/
├── CONTEXT-MAP.md                 ← 上下文索引 + 共享内核 + 关系
├── contexts/
│   └── <context-slug>/            ← 如 weld-core
│       ├── CONTEXT.md             ← 该上下文术语表
│       └── knowledge/
│           └── <domain-slug>/     ← 子领域知识文件
├── records/                       ← 会话记录（跨上下文）
├── reviews/                       ← 周期回顾
└── INDEX.md                       ← 全局索引
```

规范的 4 个上下文与子领域（详见 `archive/CONTEXT-MAP.md`）：

| 上下文 | 共享内核 | 子领域 |
|---|---|---|
| `weld-core` | `WeldSeam`/`WSG` | weld-seam、wsg-merge、transition-line、weld-template、dual-arm |
| `robotics` | `Calculator`/坐标 | coordinate、coarse-positioning |
| `orchestration` | `Executor`/状态 | workflow、scanning |
| `peripheral` | （弱） | frontend、device-robot、capacity、weld-tracking、tools |

## 知识文件格式

每个 `.md` 文件必须包含 YAML frontmatter：

```markdown
---
name: kebab-case-slug
description: 一句话摘要
metadata:
  type: knowledge
---

# 标题

## 交叉引用
- 相关概念见 [[other-file-name]]
```

## 命令语法

```
/knowledge-reorg                                              ← 无参数：执行 inspect
/knowledge-reorg inspect                                      ← 健康检查
/knowledge-reorg migrate-to-contexts [--dry-run] [--map ...]  ← 扁平→多上下文自动迁移
/knowledge-reorg merge <ctx-a> into <ctx-b>                   ← 合并两个上下文
/knowledge-reorg split <ctx> → <new-a>, <new-b>               ← 拆分上下文（agent 驱动）
/knowledge-reorg move <file> to <ctx>/<domain>                ← 跨上下文移动文件
/knowledge-reorg consolidate <ctx>/<domain>                   ← 合并碎片（agent 驱动）
```

上下文名（如 `weld-core`）对应 `archive/contexts/` 下的目录；子领域名（如 `weld-seam`）对应其 `knowledge/` 下的目录。文件名不含扩展名。

---

## migrate-to-contexts — 扁平→多上下文自动迁移

把旧的扁平结构 `archive/knowledge/<domain>/` 一次性迁移到 A1 多上下文结构 `archive/contexts/<ctx>/knowledge/<domain>/`。

**推荐用脚本执行机械搬运**（幂等、可回退）：

```bash
python knowledge-reorg/scripts/migrate_to_contexts.py \
  --map weld-core:weld-seam,wsg-merge,transition-line,weld-template,dual-arm \
  --map robotics:coordinate,coarse-positioning \
  --map orchestration:workflow,scanning \
  --map peripheral:frontend,device-robot,capacity,weld-tracking,tools \
  --legacy-context --dry-run    # 先 dry-run 看计划
```

去掉 `--dry-run` 执行。脚本做的事：

1. **检测**：`archive/contexts/` 已有内容时报错中止（避免误操作）
2. **移动**：`archive/knowledge/<domain>/` → `archive/contexts/<ctx>/knowledge/<domain>/`（git 仓库内用 `git mv`，便于回退）
3. **占位**：每个上下文生成空 `CONTEXT.md` 占位
4. **骨架**：生成 `archive/CONTEXT-MAP.md`（上下文列表；共享内核/关系留空待填）
5. **改名**：`--legacy-context` 时把扁平 `archive/CONTEXT.md` 改名为 `CONTEXT.md.legacy`（**不自动拆分**术语，留给 `/domain-modeling`）
6. **重写路径**：所有 `.md` 里的 `archive/knowledge/<domain>/` 与 `knowledge/<domain>/` 引用 → 新路径

**脚本不做的判断性工作**（迁移后由人/agent 完成）：
- 把 `CONTEXT.md.legacy` 的术语拆进各上下文 `CONTEXT.md`（用 `/domain-modeling`）
- 填充 `CONTEXT-MAP.md` 的共享内核与上下文关系
- `[[name]]` 形式的 wikilink（按 frontmatter `name` 匹配，目标文件移动后 `name` 不变则无需改）

> 若 `--map` 未覆盖所有现有领域，脚本会列出"未归类"领域并跳过它们，需补全 `--map` 后重跑。

---

## inspect — 健康检查

扫描所有上下文与子领域，逐项报告：

| 检查项 | 条件 | 级别 | 建议 |
|--------|------|------|------|
| 上下文膨胀 | 一个上下文下子领域 > 7 或文件 > 10 | ⚠️ 警告 | 建议拆分上下文 |
| 孤立上下文 | 子领域 = 0 或文件 = 1 | ⚠️ 警告 | 建议合并到相邻上下文 |
| 交叉引用断链 | `[[name]]` 指向不存在的文件 | 🔴 错误 | 报告断链位置与目标名 |
| 缺少 frontmatter | 文件不以 `---` 开头或缺 `name`/`description`/`metadata.type` | 🔴 错误 | 报告缺失字段 |
| 重复 name | 两个文件 frontmatter `name` 相同 | 🔴 错误 | 报告冲突文件 |
| 扁平残留 | `archive/knowledge/` 仍存在 | ⚠️ 警告 | 建议跑 `migrate-to-contexts` |

输出按上下文分组：

```
上下文           子领域  文件  警告  错误  详情
weld-core            5    12    0    1   断链: [[nonexistent]] (wsg-merge/planning.md L42)
robotics             2     4    0    0
orchestration        2     6    0    0
peripheral           5     3    1    0   建议: weld-tracking 文件少，考虑合并
```

执行步骤：列 `archive/contexts/` 下所有目录 → 遍历每个 `knowledge/<domain>/*.md` → 解析 frontmatter → 提取 `[[...]]` 验证目标存在 → 汇总报告。

---

## merge — 合并两个上下文

将 `<ctx-a>` 的全部内容移入 `<ctx-b>`，更新交叉引用和索引。

```
/knowledge-reorg merge peripheral into weld-core
```

1. **验证**：确认两个上下文目录存在
2. **移动**：`contexts/<ctx-a>/knowledge/<domain>/` → `contexts/<ctx-b>/knowledge/<domain>/`（用 `git mv`）
3. **合并 CONTEXT.md**：`<ctx-a>/CONTEXT.md` 的术语并入 `<ctx-b>/CONTEXT.md`（agent 判断去重）
4. **更新交叉引用**：`contexts/<ctx-a>/` → `contexts/<ctx-b>/`（INDEX.md 与所有 `[[...]]`、路径引用）
5. **清理**：删除空的 `<ctx-a>/` 目录，从 `CONTEXT-MAP.md` 移除该上下文条目
6. **同步索引**

冲突：目标上下文已有同名 domain 文件夹时停止，让用户决定（跳过/重命名/合并内容）。

---

## split — 拆分上下文（agent 驱动）

将一个上下文拆为多个。agent 根据文件语义相关性判定每个子领域/文件的归属。

```
/knowledge-reorg split weld-core → weld-seam-core, dual-arm-coord
```

1. 读取源上下文下所有 `.md`
2. Agent 按语义（`description`、标题、核心内容）为每个子领域分配目标上下文
3. 展示归属表，等用户确认
4. 移动子领域目录，拆分 `CONTEXT.md`（每个新上下文各取相关术语）
5. 更新 `CONTEXT-MAP.md`、交叉引用、INDEX

---

## move — 跨上下文移动文件

```
/knowledge-reorg move cache to orchestration/scanning
```

按 frontmatter `name` 定位文件 → 验证目标上下文/领域存在 → 检查冲突 → `git mv` → 更新 INDEX 路径。

---

## consolidate — 合并碎片（agent 驱动）

上下文内某子领域文件过于碎片时，由 agent 判断合并。

```
/knowledge-reorg consolidate peripheral/tools
```

读取目标子领域所有文件 → agent 识别主题重叠组 → 提出合并方案并生成草稿 → 用户确认 → 替换目标文件、删除被合并源文件 → 更新 `[[name]]` 引用与 INDEX。

---

## 索引同步规则

所有结构操作完成后：

### 1. 更新 `archive/INDEX.md`
重扫 `archive/contexts/` 下所有上下文与子领域，重写 Knowledge 段（Records/Reviews 段不动）：

```markdown
### <ctx>/ — <中文名>（N 子领域）
#### <domain>/
- [name](contexts/<ctx>/knowledge/<domain>/name.md) — description
```

### 2. 更新 `archive/CONTEXT-MAP.md`
上下文增删/改名后，同步 Contexts 列表；共享内核与关系段由 `/domain-modeling` 维护，本技能不自动推断。

### 3. 更新文件内交叉引用
- `[[name]]` wikilink：目标文件移动后 `name` 不变则无需改；被合并则指向合并后文件的 `name`
- 路径引用（`contexts/<old>/...`）：更新为新路径

### 4. 不破坏的内容
- `archive/records/`、`archive/reviews/` — 不触碰
- 文件内部正文 — 只在 consolidate 时由 agent 修改

---

## 通用约束

- **先确认后执行**：所有写操作展示计划后等用户确认，除非 `--force`
- **原子性**：中间步骤失败时报告已完成步骤与失败点，由用户决定回滚或继续
- **备份意识**：`archive/` 在 git 版控下，`git mv` + `git checkout` 可回退
- **不创建新知识**：本技能只做结构重组，不生成新知识内容（consolidate 合并除外）
