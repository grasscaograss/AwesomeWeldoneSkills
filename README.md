# AwesomeWeldoneSkills

焊接团队共享的 Claude Code Skills 仓库，收集项目相关的 AI 辅助能力，方便团队成员复用。

## 仓库用途

本仓库包含 Weldone 项目（及同类焊接项目）常用的 Claude Code Skills，涵盖：

- **构建与运行**：`build-publish-run` — 项目构建、发布、运行工作流
- **粗定位补偿**：`coarse-compensation-fit` — 粗定位点云误差分析与参数拟合
- **提交规范**：`commit` — 按项目规范使用中文消息提交变更
- **飞书文档**：`create-weld-doc` — 在飞书"焊接"云文档文件夹中创建新文档
- **飞书通知**：`feishu-webhook` — 通过飞书 webhook 发送文本消息
- **分支合并**：`git-branch-merge` — 大分支差异合并的结构化方法论
- **状态机参考**：`modelbase-fsm` — ModelBase 状态机完整架构参考
- **状态机同步**：`modelbase-fsm-update` — 同步最新状态机源码到 skill
- **OPSX 索引**：`opsx-reindex` — OpenSpec 变更索引重建
- **OPSX 搜索**：`opsx-search` — OpenSpec 文档搜索与导航
- **Robim.Data 探索**：`robim-data-explorer` — 本地 Robim.Data 源码定义查询
- **坐标转换**：`robot-to-world` / `world-to-robot` — 双机焊接机器人/世界坐标系转换
- **Skill 创建**：`skill-creator` — 创建新 skill 的指南
- **3D 开发**：`three-blazor-dev` — Three.js + Blazor 3D 场景开发指导
- **URDF 定位**：`weldone-current-urdf` — 根据项目配置自动定位当前 URDF 文件
- **MapMatrix 知识**：`weldone-mapmatrix-domain-knowledge` — MapMatrix 扫描校准领域知识库

## 手动配置方法

### 方式一：直接复制（推荐）

将本仓库 clone 到任意位置，把需要的 skill 复制到你的项目 `.claude/skills/` 目录下：

```powershell
# 1. 克隆仓库（已有则跳过）
git clone http://gitlab.roboticplus.com:2022/robimweld/awesomeweldoneskills.git

# 2. 复制需要的 skills 到项目目录
cd awesomeweldoneskills
copy-item -r -path "commit","build-publish-run" -destination "D:\weldone\.claude\skills\"

# 3. 重启 Claude Code 或等待自动加载
```

### 方式二：目录联接（Windows Junction）

如果希望一处更新、所有项目自动生效，使用 junction：

```powershell
# 在需要使用的项目目录下执行
cmd /c mklink /J "D:\weldone\.claude\skills\commit" "D:\awesomeweldoneskills\commit"
cmd /c mklink /J "D:\weldone\.claude\skills\modelbase-fsm" "D:\awesomeweldoneskills\modelbase-fsm"
# 按需为其他 skill 创建 junction
```

**注意**：Junction 要求两个目录都在同一台机器上，且 awesome 仓库更新后 Claude Code 会自动识别（无需手动复制）。

### 方式三：Git 子模块

在项目中使用 git submodule 引入：

```bash
cd D:\weldone
git submodule add http://gitlab.roboticplus.com:2022/robimweld/awesomeweldoneskills.git .claude/skills-shared
```

然后为需要的 skill 创建 junction 指向子模块目录。

## 更新 Skills

```bash
cd D:\awesomeweldoneskills
git pull origin master
```

如果使用 junction 方式，更新后 Claude Code 会自动加载最新内容。

## 添加新 Skill

1. 在本仓库新建 skill 目录（目录名即 skill 名）
2. 目录内添加 `SKILL.md`，遵循 skill 编写规范
3. 提交并推送：`git commit -m "feat(skill): 添加 xxx skill"`
4. 团队其他成员 pull 后即可使用

## 发给 AI 的 Prompt

> 以下是焊接团队共享的 Claude Code Skills 列表，来源于 `awesomeweldoneskills` 仓库。当我在项目（Weldone）中工作时，这些 skills 已经配置在 `.claude/skills/` 目录下。
>
> 你可以使用以下 skills：
> - `/commit` — 按项目规范用中文提交代码变更
> - `/build-publish-run` — 构建、发布、运行项目
> - `/create-weld-doc` — 创建飞书焊接文档
> - `/feishu-webhook` — 发送飞书通知
> - `/git-branch-merge` — 大分支差异合并
> - `/modelbase-fsm` 或 `/modelbase-fsm-update` — 状态机相关
> - `/opsx-reindex` / `/opsx-search` — OpenSpec 文档管理
> - `/robot-to-world` / `/world-to-robot` — 坐标系转换
> - `/coarse-compensation-fit` — 粗定位补偿
> - `/weldone-current-urdf` — 查找当前项目 URDF
> - `/weldone-mapmatrix-domain-knowledge` — MapMatrix 领域知识
> - `/robim-data-explorer` — 查询 Robim.Data 源码
> - `/three-blazor-dev` — Three.js + Blazor 3D 开发
>
> 当我调用这些 skills 时，请按照各自 SKILL.md 中的定义执行。如果有新需求需要创建 skill，请先参考 `/skill-creator` 的指南。
