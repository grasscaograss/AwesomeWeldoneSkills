---
name: archive-import
description: "Import external documents into the project archive. Two modes: → records (format conversion with TL;DR) for specs and reports, or → knowledge (multi-agent parallel organization with dedup/merge) for technical references and wiki dumps. Use when user wants to import external docs, zread output, spec documents, or reference materials into the archive."
---

# Archive Import — 文档导入

## Quick start

```
/archive-import docs/specs/ → records       ← spec 文档 → records
/archive-import .zread/wiki/ → knowledge    ← wiki 输出 → 知识库
```

第一个参数：源文档路径（文件或目录）。第二个参数：目标模式（`records` 或 `knowledge`）。

## 两种模式

| 目标 | 处理方式 | 适用场景 |
|------|---------|---------|
| → records | 格式转换：添加 TL;DR，套用模板，保留内容 | Spec 文档、会议记录、外部报告、一次性文档 |
| → knowledge | 深度整理：重叠分析、领域分组、并行 agent 读写、合并/拆分 | 技术参考资料、wiki 导出、可复用领域知识 |

---

## Records 模式

### 处理每份文档

1. 读取源文档
2. 提取：标题、日期（来自文件名或内容）、要点
3. 生成 TL;DR 行和关键词标签
4. 套用标准 record 模板（参见 `/archive-session` 的模板）
5. 写入 `archive/records/YYYY-MM-DD-<slug>.md`

### 更新 INDEX.md

在 `archive/INDEX.md` 的 `## Records` 下添加每条导入记录，附关键词标签。每行不超过 150 字符。

---

## Knowledge 模式

Knowledge 模式采用三步工作流：**分析设计 → 并行写入 → 验证更新**。
核心区别在于使用 TaskCreate 为每个领域启动独立 Agent 并行执行，而非串行处理。

### 上下文→领域结构参考

```
archive/contexts/
├── weld-core/knowledge/        ← 共享内核 WeldSeam/WSG
│   ├── weld-seam/   weld-template/   wsg-merge/
│   ├── transition-line/         dual-arm/
├── robotics/knowledge/         ← 共享内核 Calculator/坐标
│   ├── coordinate/   coarse-positioning/
├── orchestration/knowledge/    ← 共享内核 Executor/状态
│   ├── workflow/   scanning/
├── peripheral/knowledge/       ← 弱共享
│   ├── frontend/   device-robot/   capacity/
│   ├── weld-tracking/   tools/
```

（详见 `archive/CONTEXT-MAP.md`）

### 第一步：分析源文档，设计领域结构

1. **读取所有源文档** — 用 Glob 找到所有文件，逐个 Read
2. **提取关键概念、事实、规则、模式** — 从每份文档中抽取出独立的知识单元
3. **与现有知识对比重叠** — Read `archive/contexts/*/knowledge/` 下所有现有文件，标记：
   - **new**：全新知识，无重叠
   - **merge**：与现有文件有重叠，需要合并
   - **skip**：已被现有文件完全覆盖
4. **按上下文→领域分组** — 先定上下文，再定子领域，将知识单元归入 `archive/contexts/<ctx>/knowledge/<domain>/`，确定每个文件的：
   - 源文件归属（哪些源文档的内容合并到此文件）
   - 与现有知识文件的合并关系
5. **向用户展示结构方案** — 输出分组表，等待用户确认：

```
| 上下文/领域 | 新文件 | 合并到已有文件 | 跳过 |
|-----------|--------|--------------|------|
| weld-core/dual-arm/ | arc-safety.md | pipeline.md (追加§3) | — |
| orchestration/scanning/ | laser-calib.md | — | vision.md 已覆盖 |
```

用户确认后进入第二步。

### 第二步：创建目录，并行启动 Agent

1. **创建目标文件夹**（如尚未存在）

2. **为每个上下文启动一个独立 Agent**（通过 TaskCreate），每个 agent 接收以下信息：

   - **上下文/领域名称**和文件夹路径（如 `archive/contexts/weld-core/knowledge/dual-arm/`）
   - **要读取的源文件列表**（绝对路径）
   - **已有知识文件的迁移需求**（如需合并，列出目标文件和合并策略）
   - **知识文件格式规范**（见下方）
   - **合并/拆分指导原则**

   Agent 的职责：
   - 读取该领域下所有源文档
   - 按主题合并/拆分为 1-N 个知识文件
   - 每个文件严格使用标准知识文件格式
   - 用 Write 工具写入目标文件夹

3. **所有 agent 并行执行** — 不等待前一个完成再启动下一个

#### Agent 提示词模板

为每个 agent 提供的完整指令结构：

```
你是知识库整理 agent。请完成以下任务：

## 领域
- 名称：<上下文/领域>
- 目标路径：<绝对路径，如 C:\...\archive\contexts\weld-core\knowledge\dual-arm\>

## 源文件
请读取以下文件并提取知识：
- <文件1绝对路径>
- <文件2绝对路径>

## 迁移需求
- <文件名> 需合并到已有 <existing-file.md> 的 <章节>
- <文件名> 是全新知识，创建新文件

## 知识文件格式
严格使用以下格式（含 frontmatter）：

---
name: kebab-case-slug
description: 一句话摘要
metadata:
  type: knowledge
---

# 标题

`关键词1` `关键词2` — 一句话总结

## 背景 / 问题
<为什么需要这个知识，解决什么问题>

## 核心设计
<架构、数据结构、关键算法、核心接口>

## 关键规则
<约束、不变量、边界条件、注意事项>

## 交叉引用
- 相关知识文件路径
- 相关 record 路径
- 相关源码路径

## 合并/拆分原则
- 一份源文档可拆分为多个知识文件（按主题）
- 多份源文档可合并为一个知识文件（按主题聚合）
- 优先按主题内聚，而非按来源文件
- 每个文件聚焦一个主题，避免超过 300 行
- 合并已有文件时保留原有结构，在末尾追加新章节或在对应章节补充内容
```

### 第三步：验证和更新索引

1. **确认所有文件已生成** — Glob 检查目标文件夹，对比第一步的计划
2. **更新 `archive/INDEX.md` 的 `## Knowledge` 段** — 按领域分组列出所有知识文件，格式：
   ```
   ### <领域>/ — <中文名>（N 文件）
   - [slug](knowledge/<领域>/slug.md) — 一句话摘要
   ```
3. **清理迁移的旧文件** — 如果源文档是从项目内其他位置导入的，询问用户是否删除原文件
4. **检查新术语** — 扫描新生成的知识文件，提取可能需要加入上下文术语表的术语：
   - 列出候选术语和定义
   - 请用户确认
   - 按所属上下文 `archive/contexts/<ctx>/CONTEXT.md` 现有格式写入（术语名、定义、`_Avoid_` 提示）

### 知识文件格式（规范）

```markdown
---
name: kebab-case-slug
description: 一句话摘要
metadata:
  type: knowledge
---

# 标题

`关键词1` `关键词2` — 一句话总结

## 背景 / 问题

## 核心设计

## 关键规则

## 交叉引用
```

**格式要点**：
- frontmatter 必须包含 `name`、`description`、`metadata.type: knowledge`
- 标题后紧跟关键词标签行（反引号包裹）和一句话总结
- 四个标准章节：背景/问题、核心设计、关键规则、交叉引用
- 交叉引用列出相关的知识文件、record 和源码路径
- 文件名使用 kebab-case，与 frontmatter `name` 一致
