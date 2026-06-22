---
name: knowledge-reorg
description: 知识库领域级重组工具。支持健康检查（inspect）、领域合并/拆分/移动/合并碎片（merge/split/move/consolidate），agent 驱动文件归属判定与合并策略，所有操作后自动同步 INDEX.md 与交叉引用。当用户说"重组知识库"、"整理 knowledge"、"合并领域"、"拆分领域"时触发。
---

# Knowledge Reorg

知识库位于 `archive/knowledge/`，按领域组织目录。本技能提供领域级结构操作与健康检查。

## 知识库结构

```
archive/knowledge/
├── dual-arm/          ← 双臂系统
├── weld-template/     ← 焊接模板
├── weld-seam/         ← 焊缝规划
├── coarse-positioning/ ← 粗定位
├── scanning/          ← 精定位与扫描
├── capacity/          ← 产能统计
├── weld-tracking/     ← 焊接跟踪
├── coordinate/        ← 坐标与矩阵
├── workflow/          ← 状态机与工作流
├── frontend/          ← 前端界面
├── device-robot/      ← 设备与机器人
└── tools/             ← 工具与其他
```

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
/knowledge-reorg                                    ← 无参数：执行 inspect
/knowledge-reorg inspect                            ← 健康检查
/knowledge-reorg merge <domain-a> into <domain-b>   ← 合并两个领域
/knowledge-reorg split <domain> → <new-a>, <new-b>  ← 拆分领域（agent 驱动）
/knowledge-reorg move <file> to <domain>            ← 跨领域移动文件
/knowledge-reorg consolidate <domain>               ← 合并碎片文件（agent 驱动）
```

领域名对应 `archive/knowledge/` 下的目录名（如 `dual-arm`、`weld-seam`）。文件名不含扩展名（如 `strategy`、`arc-timing`）。

---

## inspect — 健康检查

扫描所有领域文件夹，逐项报告以下指标：

| 检查项 | 条件 | 级别 | 建议 |
|--------|------|------|------|
| 领域膨胀 | 文件数 > 10 | ⚠️ 警告 | 建议拆分为子领域 |
| 孤立领域 | 文件数 = 1 | ⚠️ 警告 | 建议合并到语义最接近的领域 |
| 交叉引用断链 | `[[name]]` 指向不存在的文件 | 🔴 错误 | 报告断链位置与目标名 |
| 缺少 frontmatter | 文件不以 `---` 开头或缺少 `name`/`description`/`metadata.type` | 🔴 错误 | 报告缺失字段 |
| 重复 name | 两个文件的 frontmatter `name` 相同 | 🔴 错误 | 报告冲突文件 |

### 输出格式

以表格形式呈现每个领域的检查结果：

```
领域                文件数  警告  错误  详情
dual-arm               5     0     0
weld-seam              5     0     1   断链: [[nonexistent]] (planning.md L42)
weld-tracking          1     1     0   建议: 合并到相邻领域
workflow               7     0     0
```

对每个问题附上具体位置（文件名 + 行号），便于定位修复。

### 执行步骤

1. 列出 `archive/knowledge/` 下所有子目录
2. 遍历每个目录内的 `.md` 文件
3. 解析 frontmatter，检查格式完整性
4. 提取所有 `[[...]]` 交叉引用，验证目标文件是否存在
5. 汇总为报告，按领域分组展示

---

## merge — 合并两个领域

将 `<domain-a>` 的全部文件移入 `<domain-b>`，更新所有交叉引用和索引。

### 语法

```
/knowledge-reorg merge weld-tracking into coordinate
```

### 执行步骤

1. **验证**：确认 `archive/knowledge/<domain-a>/` 和 `archive/knowledge/<domain-b>/` 均存在
2. **移动文件**：将 `<domain-a>/` 下所有 `.md` 文件移到 `<domain-b>/`
3. **更新交叉引用**：搜索 `archive/` 下所有 `.md` 文件，将引用路径从旧领域更新为新领域
   - 在 INDEX.md 中更新路径：`knowledge/<domain-a>/<file>` → `knowledge/<domain-b>/<file>`
   - 在其他知识文件中更新 `[[name]]` 引用（如果 name 不变则无需更新）
4. **清理**：删除空的 `<domain-a>/` 目录
5. **同步索引**：重写 `archive/INDEX.md` 的 Knowledge 段落，反映新路径

### 冲突处理

如果 `<domain-b>` 中已存在同名 `.md` 文件，停止并报告冲突，让用户决定如何处理（跳过/重命名/合并内容）。

---

## split — 拆分领域（agent 驱动）

将一个领域拆分为两个或多个子领域。agent 根据文件内容的语义相关性判定每个文件的归属。

### 语法

```
/knowledge-reorg split workflow → fsm, production
```

### 执行步骤

1. **验证**：确认源领域存在，目标领域不存在（避免覆盖）
2. **读取文件**：读取源领域下所有 `.md` 文件的完整内容
3. **Agent 判定归属**（spawn agent 执行）：
   - 分析每个文件的 `description`、标题和核心内容
   - 根据用户指定的分类依据（命令参数）或语义相似度，为每个文件分配到目标子领域
   - 输出一份归属表供用户确认：
     ```
     文件名              → 目标领域    理由
     state-machine.md   → fsm        状态机核心定义
     persistence.md     → fsm        崩溃恢复属于状态机范畴
     production.md      → production 生产渲染逻辑
     cache.md           → production 缓存与生产数据绑定
     ```
4. **用户确认**：展示归属表，等待用户确认或调整
5. **执行移动**：按归属表移动文件到对应子目录
6. **更新交叉引用**：同 merge 步骤 3
7. **创建目录**：创建新的子领域目录（如果尚不存在）
8. **删除源目录**：仅当源目录为空时删除
9. **同步索引**：重写 `archive/INDEX.md`

---

## move — 跨领域移动文件

将单个文件从一个领域移到另一个领域。

### 语法

```
/knowledge-reorg move cache to scanning
```

### 执行步骤

1. **定位文件**：在 `archive/knowledge/` 下搜索 `<file>` 对应的 `.md` 文件（按 frontmatter `name` 匹配）
2. **验证目标**：确认目标领域目录存在
3. **检查冲突**：目标目录下是否已存在同名文件
4. **移动文件**
5. **更新交叉引用**：更新 INDEX.md 中的路径
6. **同步索引**

---

## consolidate — 合并碎片（agent 驱动）

当一个领域内文件过于碎片化（内容少、主题重叠）时，由 agent 判断哪些文件应该合并。

### 语法

```
/knowledge-reorg consolidate device-robot
```

### 执行步骤

1. **读取领域**：读取目标领域下所有 `.md` 文件的完整内容
2. **Agent 分析**（spawn agent 执行）：
   - 评估每个文件的长度和内容密度
   - 识别主题重叠的文件组
   - 提出合并方案：
     ```
     建议合并：
     - robot-ops.md + fanuc.md → robot-ops.md
       理由: fanuc 是 robot-ops 的具体实现子集，合并后更连贯
     保留不动：
     - config.md（独立主题，内容充分）
     - calculator.md（独立主题，内容充分）
     ```
   - 为每个合并组生成合并后的完整内容草稿
3. **用户确认**：展示合并方案和草稿，等待用户确认
4. **执行合并**：用合并后的内容替换目标文件，删除被合并的源文件
5. **更新交叉引用**：被删除文件的 `[[name]]` 引用改为指向合并后的文件
6. **同步索引**

---

## 索引同步规则

所有结构操作完成后，必须执行以下同步步骤：

### 1. 更新 `archive/INDEX.md`

- 重新扫描 `archive/knowledge/` 下所有目录和文件
- 重写 Knowledge 段落（保持 Records、ADR 等其他段落不变）
- 格式与现有 INDEX.md 一致：
  ```markdown
  ### <domain>/ — <中文名>（N 文件）
  - [name](knowledge/domain/name.md) — description
  ```
- 按领域拼音字母排序

### 2. 更新文件内交叉引用

- 搜索所有 `archive/knowledge/` 下的 `.md` 文件
- 找到所有 `[[name]]` 格式的引用
- 如果引用的目标文件已被移动/重命名/删除：
  - 移动/重命名：更新 `[[name]]` 为新的 name（如果 name 变了）
  - 删除（被合并）：更新 `[[name]]` 为合并后文件的 name
  - 目标不存在：标记为断链并在输出中警告

### 3. 不破坏的内容

- `archive/records/` 下的记录文件 — 不触碰
- `archive/adr/` 下的架构决策 — 不触碰
- 文件内部的标题、正文内容 — 只在 consolidate 操作时由 agent 修改

---

## 通用约束

- **先确认后执行**：所有写操作（merge/split/move/consolidate）在展示计划后等待用户确认，除非用户使用 `--force` 标记
- **原子性**：如果一个操作的中间步骤失败，报告已完成的步骤和失败点，由用户决定回滚或继续
- **备份意识**：操作前提醒用户 `archive/` 已在 git 版本控制下，如需回退可用 `git checkout`
- **不创建新知识**：本技能只做结构重组，不生成新的知识内容（consolidate 的合并除外，但也是聚合现有内容）
