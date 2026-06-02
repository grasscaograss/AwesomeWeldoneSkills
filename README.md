# AwesomeWeldoneSkills

Weldone 焊接机器人团队的 [Agent Skills](https://agentskills.io) marketplace。

每个 skill 是一个目录，包含 `SKILL.md` 和可选的 `scripts/`、`references/`、`assets/`。
符合 [Agent Skills 规范](https://agentskills.io)，可直接用于 Claude Code 或其他支持 Agent Skills 的产品。

## 安装

### 方式 1：Junction 联接（推荐，Windows）

一处更新全局生效：

```powershell
# 将 skill 目录联接到当前项目的 .claude/skills/
mklink /J .claude\skills\<skill-name> <repo-path>\<skill-name>
```

### 方式 2：直接复制

```powershell
xcopy /E /I <repo-path>\<skill-name> .claude\skills\<skill-name>
```

### 方式 3：批量安装

复制以下内容发给 Claude Code，让它帮你完成配置：

> 我需要把焊接团队的 Agent Skills 配置到当前项目。
>
> **来源仓库**：`awesomeweldoneskills`（已 clone 到本地，请确认路径）
> **目标目录**：当前项目的 `.claude/skills/`
> **方式**：优先用 Junction 联接，备选直接复制。
>
> 请从 `catalog.json` 读取所有 skill 列表，按需配置。

---

## Skills Catalog

### Welding Domain - 焊接领域知识

| Skill | Description |
|-------|-------------|
| [coarse-compensation-fit](coarse-compensation-fit/) | 粗定位点云误差分析与补偿参数拟合 |
| [weld-seam-normal-vectors](weld-seam-normal-vectors/) | 焊缝法向量：坐标系构建、调用链、平焊缝校正 |
| [weldone-mapmatrix-domain-knowledge](weldone-mapmatrix-domain-knowledge/) | MapMatrix 扫描校准策略矩阵与 Break 端点处理 |
| [weldone-transition-line-domain-knowledge](weldone-transition-line-domain-knowledge/) | TransitionLine 过渡段统一模型 |
| [weldone-wsg-merge-domain-knowledge](weldone-wsg-merge-domain-knowledge/) | WeldSeamGroup 合并机制 |

### Robotics - 机器人坐标变换

| Skill | Description |
|-------|-------------|
| [robot-to-world](robot-to-world/) | 机器人坐标到世界坐标的逆变换 |
| [world-to-robot](world-to-robot/) | 世界坐标到机器人坐标的正向变换 |
| [weldone-current-urdf](weldone-current-urdf/) | 自动定位当前项目 URDF 文件 |

### Development Workflow - 开发工作流

| Skill | Description |
|-------|-------------|
| [commit](commit/) | 按项目规范用中文提交代码变更 |
| [build-publish-run](build-publish-run/) | 项目构建、发布、运行工作流 |
| [parallel-feature](parallel-feature/) | 并行 Agent 开发：契约 → 并行施工 → 集成验收 |
| [add-diag-logs](add-diag-logs/) | 自动注入诊断日志辅助 bug 定位 |
| [weld-plan-debug](weld-plan-debug/) | 焊接规划失败调试工作流 |

### Git & GitLab

| Skill | Description |
|-------|-------------|
| [git-branch-merge](git-branch-merge/) | 大分支差异合并方法论（逐 spec 迁移） |
| [gitlab-issue](gitlab-issue/) | 协作式 GitLab Issue 创建 |
| [gitlab-ops](gitlab-ops/) | GitLab 项目操作：Issue / Label / MR / Milestone |

### OpenSpec

| Skill | Description |
|-------|-------------|
| [opsx-reindex](opsx-reindex/) | 重新生成 openspec/INDEX.md |
| [opsx-search](opsx-search/) | 搜索和浏览 OpenSpec 文档 |

### Collaboration - 团队协作

| Skill | Description |
|-------|-------------|
| [create-weld-doc](create-weld-doc/) | 创建飞书焊接云文档并通知 |
| [feishu-webhook](feishu-webhook/) | 飞书 webhook 消息发送 |

### Frontend & 3D

| Skill | Description |
|-------|-------------|
| [three-blazor-dev](three-blazor-dev/) | Three.js + Blazor 3D 场景开发 |

### Architecture - 架构

| Skill | Description |
|-------|-------------|
| [modelbase-fsm](modelbase-fsm/) | ModelBase 状态机完整架构参考 |
| [modelbase-fsm-update](modelbase-fsm-update/) | 从源文件同步状态机 skill |

### Data

| Skill | Description |
|-------|-------------|
| [robim-data-explorer](robim-data-explorer/) | 探索 Robim.Data 源码类型定义 |

### Meta - 工具

| Skill | Description |
|-------|-------------|
| [skill-creator](skill-creator/) | 创建新 skill 的指南和工具集 |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache 2.0. See [LICENSE](LICENSE).
