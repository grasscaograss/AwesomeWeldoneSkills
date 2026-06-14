# AwesomeWeldoneSkills

Weldone 焊接机器人团队的 [Agent Skills](https://agentskills.io) Marketplace。

## 什么是 Marketplace

Marketplace 是一个集中管理 Agent Skills 的仓库。注册后，你可以在 Claude Code 或 Codex 中**浏览、搜索、一键安装**所有 skills，无需手动复制文件。

本仓库包含 29 个 skills，覆盖焊接领域知识、机器人坐标变换、开发工作流、GitLab 操作、飞书协作等。

---

## 注册 Marketplace

### CC-switch（推荐）

[CC-switch](https://github.com/farion1231/cc-switch) 是一个 GUI 工具，支持 Claude Code、Codex、Gemini CLI、OpenCode 的统一技能管理。

1. 打开 CC-switch，点击顶部 **Skills** 按钮
2. 点击 **仓库管理** → **添加仓库**
3. 填写：

| 字段         | 值                     |
| ------------ | ---------------------- |
| Owner        | `grasscaograss`        |
| Name         | `AwesomeWeldoneSkills` |
| Branch       | `main`                 |
| Subdirectory | （留空）               |

4. 点击添加后回到 Skills 页面，点击 **刷新** 即可浏览和安装所有技能

> CC-switch 还支持自动更新检测、批量更新、卸载备份恢复等功能，详见 [CC-switch 文档](https://github.com/farion1231/cc-switch/blob/main/docs/user-manual/zh/3-extensions/3.3-skills.md)。

### Claude Code - 直接添加源

如果不想使用 CC-switch，也可以在 Claude Code 中直接添加：

```
/plugin marketplace add https://github.com/grasscaograss/AwesomeWeldoneSkills.git
```

注册成功后，可以浏览所有可用 skills：

```
/plugin marketplace list          # 查看已注册的 marketplace
/plugin search <keyword>          # 搜索 skill
/plugin install <skill-name>      # 安装单个 skill
```

### GitLab 内网源

无法访问 GitHub 时，可在 Claude Code 中添加 GitLab 内网源（SSH 方式，推荐）：

```
/plugin marketplace add git@gitlab.roboticplus.com:robimweld/awesomeweldoneskills.git
```

> 如果 SSH 不可用，也可以尝试 HTTPS：
> ```
> /plugin marketplace add http://gitlab.roboticplus.com:2022/robimweld/awesomeweldoneskills.git
> ```

### Codex

执行相同的命令，Codex 会读取 `.codex-plugin/marketplace.json`：

```
/plugin marketplace add https://github.com/grasscaograss/AwesomeWeldoneSkills.git
```

### 团队自动发现（推荐）

如果希望团队成员打开项目时自动提示安装，将以下内容加入项目的 `.claude/settings.json`：

```json
{
  "extraKnownMarketplaces": {
    "awesomeweldoneskills": {
      "source": {
        "source": "git",
        "url": "https://github.com/grasscaograss/AwesomeWeldoneSkills.git"
      }
    }
  }
}
```

> 如果只能访问内网，将 source 改为：
> ```json
> "source": {
>   "source": "git",
>   "url": "git@gitlab.roboticplus.com:robimweld/awesomeweldoneskills.git"
> }
> ```

---

## 安装 Skills

注册 Marketplace 后，按需安装单个 skill：

```
/plugin install add-diag-logs
/plugin install modelbase-fsm
```

---

## 更新 Skills

Marketplace 注册后会自动缓存仓库内容。更新到最新版本：

```
/plugin marketplace refresh
```

然后重新安装需要更新的 skill：

```
/plugin install <skill-name>
```

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
| [gitlab-merge-request](gitlab-merge-request/) | 专门创建 GitLab Merge Request：推送源分支、查重并创建 MR |
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
| [x-twitter-scraper](x-twitter-scraper/) | 为 Agent 提供 X/Twitter 数据搜索、监控、Webhook、MCP 与 REST API 工作流 |

### Meta - 工具

| Skill | Description |
|-------|-------------|
| [skill-creator](skill-creator/) | 创建新 skill 的指南和工具集 |

### Code Review - 代码审查

| Skill | Description |
|-------|-------------|
| [DDD-review](DDD-review/) | Martin Fowler 代码审查视角：代码异味识别、重构手法建议、可读性评估 |
| [code-simplify](code-simplify/) | 以减法为先的代码审查：识别过度设计、冗余代码、命名晦涩、注释失衡 |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache 2.0. See [LICENSE](LICENSE).
