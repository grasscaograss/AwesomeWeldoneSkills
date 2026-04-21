# AwesomeWeldoneSkills

焊接团队共享的 Claude Code Skills 仓库。

---

## 发给 AI 的配置 Prompt

复制以下内容发给 AI，让它帮你完成 skills 配置：

> 我需要把焊接团队共享的 Claude Code Skills 配置到当前项目中。
>
> **来源仓库**：`awesomeweldoneskills`（已 clone 到本地路径，请根据我的环境确认具体位置）
> **目标目录**：当前项目的 `.claude/skills/`（如果不存在请先创建）
>
> 目前这些 skills **还没有**配置到目标目录中，请帮我完成配置，可以选择以下任一方式：
> 1. **直接复制**：将需要的 skill 目录从 awesome 仓库复制到 `.claude/skills/`
> 2. **Junction 联接**：创建 Windows 目录联接（推荐，一处更新全局生效）
>
> 需要配置的 skills 列表（根据项目需求勾选，全部复制也可）：
> - [ ] `commit` — 按项目规范用中文提交代码变更
> - [ ] `build-publish-run` — 项目构建、发布、运行工作流
> - [ ] `coarse-compensation-fit` — 粗定位点云误差分析与参数拟合
> - [ ] `create-weld-doc` — 创建飞书焊接文档
> - [ ] `feishu-webhook` — 发送飞书通知
> - [ ] `git-branch-merge` — 大分支差异合并方法论
> - [ ] `modelbase-fsm` — ModelBase 状态机架构参考
> - [ ] `modelbase-fsm-update` — 状态机内容同步
> - [ ] `opsx-reindex` — OpenSpec 索引重建
> - [ ] `opsx-search` — OpenSpec 文档搜索
> - [ ] `robim-data-explorer` — Robim.Data 源码探索
> - [ ] `robot-to-world` — 机器人坐标→世界坐标转换
> - [ ] `world-to-robot` — 世界坐标→机器人坐标转换
> - [ ] `weldone-current-urdf` — 自动定位当前项目 URDF
> - [ ] `weldone-mapmatrix-domain-knowledge` — MapMatrix 扫描校准领域知识
> - [ ] `three-blazor-dev` — Three.js + Blazor 3D 开发
> - [ ] `skill-creator` — 创建新 skill 的指南
>
> 配置完成后，请验证每个 skill 的 SKILL.md 是否能在当前项目中被 Claude Code 正确识别。如果 awesome 仓库路径不确定，请先用 `ls` 或 `dir` 命令帮我确认。
