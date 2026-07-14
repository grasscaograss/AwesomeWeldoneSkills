---
name: robimweld-release-check
description: 校验 RobimWeld.Algorithm / RobimWeld.Devices 两条版本线（护圈龙门 v1.x、Kuka v2.x-alpha）的 NuGet 包发布一致性，并在确认后打 tag 触发 CI 发包。触发场景：(1) 用户合并代码到 kuka/master 后发现"没发包""版本对不上""拉不到包"；(2) 用户要求"发版""打个 tag""检查一下 RobimWeld 包版本"；(3) 主仓 restore 报 NU1101/找不到版本。仅处理 RobimWeld.Algorithm 和 RobimWeld.Devices 两个仓库，不动 Robim.Data/one_punch 等生态包。
license: Apache-2.0
allowed-tools: Bash
compatibility: 需本地克隆 RobimWeld.Algorithm（D:\RobimWeld.Algorithm）与 RobimWeld.Devices（D:\RobimWeld.Devices）；需 dotnet（Windows 端 /mnt/c/Program Files/dotnet/dotnet.exe）查询 RP feed。
metadata:
  author: weldone-team
  version: "1.0.0"
---

# RobimWeld 发布一致性校验

校验 `RobimWeld.Algorithm` 与 `RobimWeld.Devices` 两个私有仓库的 NuGet 包发布状态，定位"代码已合并、版本号已改、但没发包"这类问题，并在确认后打 tag 触发 CI 发包。

规则权威来源：`README.md` §"包版本与发布顺序"（196-202 行）。本 skill enforce 而非重写这些规则。

## 两条版本线

| 版本线 | 主仓分支 | 源仓库分支 | tag 前缀 |
|---|---|---|---|
| 护圈龙门 v1.x | `feature/merge护圈龙门-nuget` | `master` | `v1.0.x`（Algorithm）/ `v1.1.x`（Devices） |
| Kuka 悬臂 v2.x-alpha | `feature/kuka-nuget-2.0` | `kuka` | `v2.0.x-alpha` |

判定版本线：读主仓当前分支名，匹配上表。无法匹配时停止并询问用户当前属于哪条线。

## 仓库 → 产出包映射

| 源仓库 | 本地路径 | 产出包 |
|---|---|---|
| `RobimWeld.Algorithm` | `D:\RobimWeld.Algorithm`（WSL `/mnt/d/RobimWeld.Algorithm`） | `RobimWeld.Algorithm.Weld`、`RobimWeld.Data.Weld` |
| `RobimWeld.Devices` | `D:\RobimWeld.Devices`（WSL `/mnt/d/RobimWeld.Devices`） | `RobimWeld.Devices`、`RobimWeld.Devices.Robot`、`RobimWeld.Devices.Vision`、`RobimWeld.Scanning.Contracts` |

git 地址：`git@gitlab.roboticplus.com:robimweld/RobimWeld.Algorithm.git`、`git@gitlab.roboticplus.com:robimweld/RobimWeld.Devices.git`。

## 版本号读取规则

两条线的版本号存放位置不同，必须都覆盖：

### Kuka v2.x-alpha 线
两个仓库均在 `Directory.Build.props` 用单一字段：
- Algorithm：`<Version>2.0.x-alpha</Version>`
- Devices：`<RobimWeldPackageVersion>2.0.x-alpha</RobimWeldPackageVersion>` + `<Version>$(RobimWeldPackageVersion)</Version>`

读取 `Directory.Build.props` 一个文件即可。

### 护圈龙门 v1.x 线
- **Algorithm**：`Directory.Build.props` 无 `<Version>` 字段（1.x 早期）；版本号写在**各 csproj** 的 `<Version>`。必须遍历 `src/**/*.csproj` 取所有 `<Version>` 值并集校验同号。
- **Devices**：`Directory.Build.props` 单一 `<Version>1.1.x</Version>`，一个文件即可。

## 一致性硬规则

### 仓库内同号（强制）
同一仓库产出的所有包，版本号必须一致。

**违反示例**：护圈龙门线 `v1.0.6` tag 时，Algorithm 仓库 `RobimWeld.Algorithm.Weld.csproj` = `1.0.5`、`RobimWeld.Data.Weld.csproj` = `1.0.6` → 仓库内不同号 → 阻断发版，提示先修版本号。

### 跨仓库可不同（允许）
护圈龙门线 Algorithm = `1.0.x` / Devices = `1.1.x` 合法，不校验跨仓库。

### 主仓引用 vs 源仓库 tag
主仓 `Directory.Packages.props` 引用的版本，必须在对应源仓库已打 tag，且 tag 指向的 commit 包含该版本号。否则判定"代码合并了但没发包"。

### CI 触发机制
两个仓库 `.gitlab-ci.yml` 均为：
```yaml
publish:
  rules:
    - if: $CI_COMMIT_TAG   # 只有 tag 推送才发包
```
分支推送只 build，不 publish。**漏打 tag = 没发包**，这是最常见的问题根因。

## 校验工作流

收到请求后按顺序执行：

### 1. 判定版本线
```bash
git -C /mnt/d/weldone branch --show-current
```
匹配分支名到版本线表。无法匹配时停止询问。

### 2. 读主仓引用版本
从 `/mnt/d/weldone/Directory.Packages.props` 取 6 个 `RobimWeld.*` 包的 `Version`。
```bash
grep "RobimWeld" /mnt/d/weldone/Directory.Packages.props
```
> ⚠️ 环境陷阱：本仓 shell 里 `grep -iE`（`-i` + `-E` 组合）会报 "conflicting matchers specified"。用单选项 `grep "RobimWeld"` 或 `grep -E "pattern"`（不带 `-i`），或改用 `dotnet package search` / `Select-String`。

### 3. 校验源仓库仓库内同号
对每个源仓库，按版本号读取规则取版本号集合，若集合 size > 1 则报错阻断。

### 4. 检查 tag 是否缺失
```bash
# HEAD 是否被某 tag 包含
git -C /mnt/d/RobimWeld.Algorithm tag --contains HEAD
git -C /mnt/d/RobimWeld.Devices tag --contains HEAD
# 对比主仓引用版本号
git -C /mnt/d/RobimWeld.Algorithm tag --list "v*"
```
若 HEAD 不在任何 tag 里，或主仓引用的版本号没有对应 tag，判定 tag 缺失。

### 5. 查 RP feed 确认落库
优先用 dotnet package search（Windows 端 dotnet.exe）：
```bash
DOTNET_NOLOGO=1 "/mnt/c/Program Files/dotnet/dotnet.exe" package search "RobimWeld.Algorithm.Weld" --prerelease --source "http://gitlab.roboticplus.com:2023/v3/index.json"
```
> Linux 端无 dotnet，必须用 Windows 端 `/mnt/c/Program Files/dotnet/dotnet.exe`，加 `DOTNET_NOLOGO=1` 减噪。

fallback 用 PackageBaseAddress（curl，包名小写）：
```bash
curl -s "http://gitlab.roboticplus.com:2023/v3/package/robimweld.algorithm.weld/index.json"
```
service index（`http://gitlab.roboticplus.com:2023/v3/index.json`）里 `PackageBaseAddress/3.0.0` 的 @id 是 `/v3/package`。返回 JSON 的 `versions` 数组即所有已发布版本。

### 6. 输出一致性报告

表格形式：

| 包 | 主仓引用 | 源仓库版本 | tag | feed 落库 | 状态 |
|---|---|---|---|---|---|
| RobimWeld.Algorithm.Weld | 2.0.1-alpha | 2.0.1-alpha | v2.0.1-alpha | ✅ | ✅ |
| ... | | | | | |

状态图例：✅ 一致 / ⚠️ 版本落后 / ❌ 缺 tag 或缺包

## 发版动作

### 默认询问确认
打 tag 推送是对外发布、难撤销操作。每次执行前**必须先列出将要打的 tag、指向 commit、目标仓库，等用户确认 yes 后再执行**。

### 执行命令
判定为"代码已合并、版本号已改、缺 tag"时：
```bash
cd <源仓库路径>
git tag v<版本号> <commit-sha>      # 或直接 git tag v<版本号>（HEAD）
git push origin v<版本号>
```

tag 命名遵循现有惯例，带 `v` 前缀：`v2.0.1-alpha`、`v1.0.6`。tag 推送后各仓库 CI 的 `publish` job 自动触发 pack + push。

### 阻断条件
- 仓库内版本号不一致 → **不自动改版本号**，提示人工修正后重跑。
- 主仓引用版本与源仓库当前版本号不匹配 → 提示先对齐再发。

### 多仓库批量
两个仓库都要发时，按 README §发布顺序：Algorithm 先，Devices 后。可并行打 tag（无依赖），但发布验证顺序遵循该文档。

## 不做什么（scope 边界）

- 不动 `Robim.Data` / `Robim.Data.Proto` / `Robim.Robot` / `one_punch` / `ModelParser` / `NativeInteropRuntime` / `RobotInterfaceNet` / `WeldRecognitionNet` 等生态包（独立版本线，非本 skill 范围）。
- 不碰 `Roboticplus.Framework` / `Roboticplus.Abp.*` 等 Roboticplus 命名空间包。
- 不修改 csproj/props 版本号——只校验和报告，版本号修正交给人工。
- 不直接跑 `dotnet pack` / `dotnet nuget push`——发版只通过打 tag 触发各仓库自己的 CI。
- 不发主仓（weldone）本身的包。
- 不管理 `UseRobimWeldSource` 源码调试模式切换——那是 `robimweld-source-debug` skill 的职责。但两者联动：切源码调试前应先跑本 skill，确认本地克隆的源码版本 ≥ NuGet 引用版本，否则改了源码但 NuGet 还是旧包，调试白调。

## 辅助脚本

`scripts/check-robimweld-versions.ps1` 封装"读主仓 Directory.Packages.props + 查 RP feed + 比对"的纯查询逻辑，输出表格。调用方式：
```bash
"/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w /mnt/d/weldone/.agents/skills/robimweld-release-check/scripts/check-robimweld-versions.ps1)"
```
> 脚本文件以 UTF-8 BOM 保存，避免 Windows PowerShell 5.1 无 BOM 时按 GBK 读取中文导致解析错误。状态标记用 ASCII（OK/MISSING/WARN）而非 emoji，同理。

脚本只读，不含 push/tag 逻辑。skill 主体也能纯 Bash 手动完成，不强制依赖脚本。
