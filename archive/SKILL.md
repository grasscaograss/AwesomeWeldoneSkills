---
name: archive
description: 多入口查询项目知识库。支持关键词搜索、领域浏览、术语查询、Records 时间线检索，全部遵循渐进式披露。Use when user asks about past decisions, domain knowledge, terminology, project context, or any topic documented in the archive.
---

# Archive — 项目知识库查询

## 知识库结构

所有路径相对于项目根目录：

| 路径 | 内容 | 查询方式 |
|------|------|----------|
| `archive/INDEX.md` | 全局索引，含关键词标签 | 关键词匹配、领域浏览入口 |
| `archive/CONTEXT.md` | 领域术语表、关系图、歧义标注 | 术语查询 |
| `archive/records/` | 按日期的会话记录 | 时间范围检索 |
| `archive/knowledge/` | 领域知识，按子文件夹分类 | 领域浏览 |
| `docs/adr/` | 架构决策记录 | 关键词匹配 |
| `archive/reviews/` | 月度/年度回顾 | 关键词匹配 |

领域子文件夹一览（`archive/knowledge/` 下）：

`dual-arm/` `weld-template/` `weld-seam/` `coarse-positioning/` `scanning/` `capacity/` `weld-tracking/` `coordinate/` `workflow/` `frontend/` `device-robot/` `tools/`

## 查询入口

根据用户的提问方式，选择合适的入口：

### 1. 关键词搜索

用户问一个具体问题，如"过渡段是怎么规划的"。

1. 读 `archive/INDEX.md`，用反引号内的关键词标签匹配用户提问
2. 短列匹配到的文档，读其 TL;DR（标题下方的一句话摘要）
3. 仅对 TL;DR 确认相关的文档读全文
4. 引用路径 + 相关章节回答

### 2. 领域浏览

用户想了解某个领域的全局，如"扫描相关有什么"、"焊缝规划有哪些知识"。

1. 从 `archive/INDEX.md` 找到对应领域小节（如 `### scanning/`）
2. 列出该领域下所有文件的名称和一句话摘要
3. 问用户是否需要展开某个文件

领域关键词到文件夹的常见映射：

| 用户可能说的 | 文件夹 |
|-------------|--------|
| 双臂、协同、Leader/Follower | `dual-arm/` |
| 焊接模板、匹配规则、模板编辑 | `weld-template/` |
| 焊缝、规划、后处理、几何类型 | `weld-seam/` |
| 粗定位、视觉校正、龙门补偿 | `coarse-positioning/` |
| 扫描、精定位、拍照点、VCM | `scanning/` |
| 产能、统计、清枪计数 | `capacity/` |
| 焊接跟踪、传感器 | `weld-tracking/` |
| 坐标、矩阵、标定、phantom-type | `coordinate/` |
| 状态机、工作流、持久化、PoseRole | `workflow/` |
| 前端、Blazor、React、UI 组件 | `frontend/` |
| 设备、机器人、Fanuc、FTP | `device-robot/` |
| CLI、工具、几何参数 | `tools/` |

### 3. 术语查询

用户问一个具体术语，如"PoseRole 是什么"、"WorldCoord 和 RobotCoord 有什么区别"。

1. 读 `archive/CONTEXT.md`
2. 找到匹配的 `###` 术语条目，返回定义
3. 检查 `_Avoid_` 标注，如有则提醒用户避免使用弃用术语
4. 如有关系链（`## Relationships` 小节），补充关联术语

### 4. Records 时间线检索

用户问时间段相关，如"最近一周做了什么"、"5 月 23 号改了什么"。

1. 读 `archive/INDEX.md` 的 `## Records` 小节
2. 按日期筛选匹配范围的条目
3. 列出日期 + 文件名 + 关键词标签 + 一句话摘要
4. 问用户是否需要展开某条记录的全文

Records 文件名格式：`YYYY-MM-DD-kebab-case-slug.md`

### 5. 混合查询

用户的问题可能跨多个入口，按需组合。例如"扫描精定位最近改了什么" = 领域浏览(`scanning/`) + 时间线检索(`records/`)。

## 渐进式披露原则

不论用哪个入口，都遵循"先轻后重"：

1. **INDEX 扫描** — 只读 `archive/INDEX.md` 中的关键词和摘要
2. **TL;DR 确认** — 读候选文档的标题 + 摘要行，排除误匹配
3. **全文展开** — 仅对确认相关的文档读全文

不要一次性读取所有匹配文件。先给用户概览，等用户确认再深入。

## 交互模式

- 回答时附带文件路径引用
- 如果用户的问题模糊，主动提议浏览相关领域
- 术语查询中如发现 `_Avoid_` 标注，提醒用户使用正确术语
- 用户说"帮我看看 X 相关有什么"时，走领域浏览入口
- 用户说"Y 是什么"时，走术语查询入口
- 用户说"最近 Z 时间做了什么"时，走 Records 时间线检索
