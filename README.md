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

## 如何更新 Skills

### 场景一：AwesomeWeldoneSkills 仓库本身有更新（新增 skill 或修改）

```bash
cd D:\awesomeweldoneskills
git pull origin master
```

- **Junction 方式**：无需额外操作，Claude Code 自动识别最新内容
- **复制方式**：需要手动重新复制更新的 skill 目录到项目 `.claude/skills/`

### 场景二：你需要把新 skill 加到已配置的项目中

假设 awesome 仓库新增了 `new-skill`，你想在 weldone 项目中使用：

```powershell
# Junction 方式
cmd /c mklink /J "D:\weldone\.claude\skills\new-skill" "D:\awesomeweldoneskills\new-skill"

# 或复制方式
copy-item -r "D:\awesomeweldoneskills\new-skill" "D:\weldone\.claude\skills\"
```

### 场景三：检查当前项目已配置哪些 skills

```powershell
ls D:\weldone\.claude\skills\ | sort
```

## 添加新 Skill

1. 在本仓库新建 skill 目录（目录名即 skill 名）
2. 目录内添加 `SKILL.md`，遵循 skill 编写规范
3. 提交并推送：`git commit -m "feat(skill): 添加 xxx skill"`
4. 团队其他成员 pull 后即可使用

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
