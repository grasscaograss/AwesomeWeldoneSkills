# AwesomeWeldoneSkills

Weldone 焊接机器人团队的 [Agent Skills](https://agentskills.io) Marketplace。

## 什么是 Marketplace

Marketplace 是一个集中管理 Agent Skills 的仓库。注册后，你可以在 Claude Code 或 Codex 中**浏览、搜索、一键安装**所有 skills，无需手动复制文件。

本仓库包含 64 个 skills，覆盖焊接领域知识、机器人坐标变换、开发工作流、GitLab 操作、飞书协作、知识库管理、工程方法论、开发方法论等。

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

### Claude Code — 直接添加源

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
| [weld-seam-normal-vectors](weld-seam-normal-vectors/) | 焊缝法向量领域知识：坐标系构建、调用链、平焊缝校正 |
| [weldone-mapmatrix-domain-knowledge](weldone-mapmatrix-domain-knowledge/) | MapMatrix 扫描校准模块领域知识 |
| [weldone-transition-line-domain-knowledge](weldone-transition-line-domain-knowledge/) | TransitionLine 过渡段统一模型领域知识 |
| [weldone-wsg-merge-domain-knowledge](weldone-wsg-merge-domain-knowledge/) | WeldSeamGroup 合并机制领域知识 |

### Robotics - 机器人坐标变换

| Skill | Description |
|-------|-------------|
| [robot-to-world](robot-to-world/) | 机器人坐标到世界坐标的逆变换 |
| [world-to-robot](world-to-robot/) | 世界坐标到机器人坐标的正向变换 |
| [weldone-current-urdf](weldone-current-urdf/) | 自动定位当前 Weldone 项目对应的 URDF 文件 |

### Development Workflow - 开发工作流

| Skill | Description |
|-------|-------------|
| [commit](commit/) | 按照项目规范使用中文消息提交变更 |
| [build-publish-run](build-publish-run/) | 项目构建、发布和运行工作流 |
| [parallel-feature](parallel-feature/) | 并行 Agent 开发工作流：契约 → 并行施工 → 集成验收 |
| [add-diag-logs](add-diag-logs/) | 自动在代码中注入诊断日志，辅助定位 bug |
| [weld-plan-debug](weld-plan-debug/) | 焊接规划失败调试工作流 |
| [weldone-hybrid-seam-replay-debug](weldone-hybrid-seam-replay-debug/) | Weldone 混合焊缝 replay 包调试：单机/双机重构、LaserPoint RANSAC、Arc 拟合阈值与弱诊断 |
| [weldone-db-migration](weldone-db-migration/) | Weldone 数据库迁移守护：EF Core migration 检查、update-db 优先、migrate 前备份 |
| [robimweld-release-check](robimweld-release-check/) | RobimWeld 版本、tag 与 NuGet feed 发布一致性校验 |
| [robimweld-source-debug](robimweld-source-debug/) | RobimWeld 源码调试模式切换与构建验证 |

### Git & GitLab

| Skill | Description |
|-------|-------------|
| [git-branch-merge](git-branch-merge/) | 合并差异较大的 Git 分支的结构化方法论 |
| [gitlab-issue](gitlab-issue/) | 与开发人员协作创建 GitLab Issue |
| [gitlab-merge-request](gitlab-merge-request/) | 专门创建 Weldone GitLab Merge Request：确认目标分支、推送源分支、查重并创建 MR |
| [gitlab-ops](gitlab-ops/) | GitLab 项目操作：Issue / Label / MR / Milestone 管理 |

### OpenSpec

| Skill | Description |
|-------|-------------|
| [opsx-reindex](opsx-reindex/) | 重新生成 openspec/INDEX.md 索引文件 |
| [opsx-search](opsx-search/) | 搜索和浏览 OpenSpec 文档 |

### Collaboration - 团队协作

| Skill | Description |
|-------|-------------|
| [create-weld-doc](create-weld-doc/) | 在飞书焊接文件夹中创建云文档并发送通知 |
| [feishu-webhook](feishu-webhook/) | 通过飞书 webhook 发送文本消息 |

### Frontend & 3D

| Skill | Description |
|-------|-------------|
| [three-blazor-dev](three-blazor-dev/) | Three.js + Blazor 3D 场景开发指南 |

### Architecture - 架构

| Skill | Description |
|-------|-------------|
| [modelbase-fsm](modelbase-fsm/) | ModelBase 状态机的完整架构参考 |
| [modelbase-fsm-update](modelbase-fsm-update/) | 从源文件同步更新 modelbase-fsm skill |

### Data

| Skill | Description |
|-------|-------------|
| [robim-data-explorer](robim-data-explorer/) | 探索 Robim.Data 源码类型定义 |

### Meta - 工具

| Skill | Description |
|-------|-------------|
| [skill-creator](skill-creator/) | 创建新 skill 的指南和工具集 |

### Code Review - 代码审查

| Skill | Description |
|-------|-------------|
| [DDD-review](DDD-review/) | Martin Fowler 代码审查视角：代码异味识别、重构手法建议、可读性评估 |
| [code-simplify](code-simplify/) | 以减法为先的代码审查：识别过度设计、冗余代码、命名晦涩、注释失衡 |

### Knowledge Management - 知识库管理

| Skill | Description |
|-------|-------------|
| [archive](archive/) | 多入口查询项目知识库：关键词搜索、领域浏览、术语查询、Records 时间线检索 |
| [archive-import](archive-import/) | 导入外部文档到项目知识库，支持 records 模式（格式转换）和 knowledge 模式（深度整理） |
| [archive-session](archive-session/) | 会话归档：收集变更、生成 record、检测可复用知识并按领域路由写入知识库 |
| [knowledge-reorg](knowledge-reorg/) | 知识库领域级重组：健康检查、合并/拆分/移动领域、合并碎片文件 |
| [periodic-review](periodic-review/) | 生成月度/年度项目回顾，按领域追踪知识演进和健康度 |

### Matt Pocock - 工程方法论

| Skill | Description |
|-------|-------------|
| [ask-matt](ask-matt/) | 路由器：询问当前场景适合哪种 skill 或流程 |
| [code-review](code-review/) | 两轴审查自固定点以来的改动：Standards（编码规范 + Fowler 代码异味基线）与 Spec（是否忠实实现 issue/PRD），并行子 agent 执行 |
| [codebase-design](codebase-design/) | 深模块设计共享词汇表，辅助接口设计、深化机会与可测试性决策 |
| [diagnosing-bugs](diagnosing-bugs/) | 纪律化诊断循环：复现→最小化→假设→埋点→修复→回归 |
| [domain-modeling](domain-modeling/) | 构建和打磨项目领域模型，统一领域术语并记录架构决策 |
| [grill-me](grill-me/) | 针对计划或设计的 relentless 追问，逐个分支理解决策树 |
| [grilling](grilling/) | 对计划/决策/想法的 relentless 追问，匹配 grill 触发词，达成共识前不执行 |
| [grill-with-docs](grill-with-docs/) | 针对计划的 relentless 追问，过程中内联生成 ADR 和术语表 |
| [handoff](handoff/) | 将当前会话压缩为交接文档，供下一个 agent 接续工作 |
| [implement](implement/) | 基于 spec 或一组 ticket 实现一项工作（内部驱动 /tdd，收尾跑 /code-review） |
| [improve-codebase-architecture](improve-codebase-architecture/) | 扫描代码库寻找深化机会，生成可视化 HTML 报告，再逐个 grill 落实 |
| [prototype](prototype/) | 构建一次性原型回答设计问题：验证状态/逻辑模型，或探索 UI 形态 |
| [research](research/) | 后台 agent 调研：对照一手原始资料，产出带引用的 Markdown 文件 |
| [resolving-merge-conflicts](resolving-merge-conflicts/) | 解决进行中的 git merge/rebase 冲突：理解双方意图、逐块合并、跑检查、完成合并 |
| [setup-matt-pocock-skills](setup-matt-pocock-skills/) | 配置工程 skills 的 issue tracker、triage 标签词表和领域文档布局 |
| [teach](teach/) | 在工作区内向用户教授新技能或概念 |
| [tdd](tdd/) | 测试驱动开发：红-绿循环（重构已移至 code-review），垂直切片 tracer bullet 工作流 |
| [to-spec](to-spec/) | 把当前对话综合成一份 spec 并发布到项目 issue tracker——不做访谈，只提炼已讨论的内容 |
| [to-tickets](to-tickets/) | 将计划/spec/对话拆成一组 tracer-bullet ticket，各自声明 blocking edges，发布到 tracker |
| [triage](triage/) | 将 issue 和外部 PR 推过 triage 状态机：分类、验证、必要时 grill，产出 agent 就绪简报 |
| [wayfinder](wayfinder/) | 把超大块工作规划成 issue tracker 上一张共享的决策 ticket 地图，逐个解决直到路径清晰 |
| [writing-great-skills](writing-great-skills/) | skill 写作参考：让 skill 可预测的词汇与原则 |

### Superpowers - 开发方法论

| Skill | Description |
|-------|-------------|
| [superpowers](superpowers/) | 完整的 agent 开发方法论技能集：头脑风暴→计划→TDD→调试→审查→交付，共 14 个模块 |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache 2.0. See [LICENSE](LICENSE).

