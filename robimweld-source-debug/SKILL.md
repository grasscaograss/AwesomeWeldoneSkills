---
name: robimweld-source-debug
description: 切换 RobimWeld 源码调试模式（UseRobimWeldSource），把 6 个 RobimWeld.* 包从 PackageReference 换成 ProjectReference 指向同级克隆源码。触发场景：(1) 用户要"改算法/设备源码""切源码调试""联调核心库""单步进 RobimWeld 包内部"；(2) 用户遇到"改了源码但没生效""源码和 NuGet 程序集混用"报错；(3) 构建报 RobimWeld 源码根目录不存在的 Error。仅管 UseRobimWeldSource 切换与构建，不发版不查 feed（那是 robimweld-release-check 的职责）。
license: Apache-2.0
allowed-tools: Bash
compatibility: 需 RobimWeld.Algorithm（D:\RobimWeld.Algorithm）与 RobimWeld.Devices（D:\RobimWeld.Devices）克隆在 D 盘同级；需 dotnet（Windows 端 /mnt/c/Program Files/dotnet/dotnet.exe）。
metadata:
  author: weldone-team
  version: "1.0.0"
---

# RobimWeld 源码调试模式切换

操作型 skill，帮用户切换 `UseRobimWeldSource` 源码调试模式：写入/删除 `Directory.Build.local.props`、验证源码路径、跑 clean/restore/build。与 `robimweld-release-check` 联动——切之前先确认源码版本到位。

规则权威来源：`README.md` §"RobimWeld 调试模式"。本 skill enforce 而非重写这些规则。

## 三层调试能力

RobimWeld 调试分三层，本 skill 管 L3（L1/L2 见 README）：

| 层级 | 场景 | 机制 | 本 skill |
|---|---|---|---|
| **L1 Source Link 只读单步** | 定位问题不改源码 | NuGet + snupkg + Source Link | 不管 |
| **L2 源码项目浏览** | Rider 里展开源码项目 | `WeldoneWithSource.slnx`（主仓根，已提交） | 不管，但推荐配合 |
| **L3 源码模式联调** | 改源码即改即生效 | `UseRobimWeldSource=true` + AdditionalProperties 级联 | **核心职责** |

> **关键**：L2 只让项目"看得见"，L3 才"切得动"依赖。推荐用 `WeldoneWithSource.slnx` 打开 Rider 的同时设 `local.props` 开 L3，两者互补。

## 模式机制

`Directory.Build.props`（主仓根，受版本管理）定义：
- `UseRobimWeldSource`（默认 `false`）
- `RobimWeldAlgorithmSourceRoot`（默认 `..\RobimWeld.Algorithm`，即 `D:\RobimWeld.Algorithm`）
- `RobimWeldDevicesSourceRoot`（默认 `..\RobimWeld.Devices`，即 `D:\RobimWeld.Devices`）

各 csproj 用 `Condition="'$(UseRobimWeldSource)' == 'true'"` 切换：
- `true` → `ProjectReference` 指向同级源码仓库的 csproj（可单步、改源码即生效）
- `false` → `PackageReference` 走 NuGet 包（默认）

持久切换：在主仓根写 `Directory.Build.local.props`（已 gitignore）设 `UseRobimWeldSource=true`，被 `Directory.Build.props` 第 18 行的 `<Import ... Condition="Exists(...)">` 加载。

单次切换（不落文件）：`dotnet build WeldoneForCode.slnf -p:UseRobimWeldSource=true`。

### 跨仓级联（为什么不能只靠 slnx）

源码切换是跨仓级联链，不传 `AdditionalProperties` 会导致源码与 NuGet 混用：

```
weldone 主仓 (拨 UseRobimWeldSource=true)
   ↓ ProjectReference + AdditionalProperties="$(RobimWeldSourceProjectProperties)"
RobimWeld.Devices 源码 (Devices.csproj/Vision.csproj 内部也有 Condition 分支)
   ↓ 自己切到源码分支
RobimWeld.Algorithm 源码 (终端，无需切换)
```

`RobimWeldSourceProjectProperties` = `UseRobimWeldSource=true;RobimWeldAlgorithmSourceRoot=...;RobimWeldDevicesSourceRoot=...`，通过 `AdditionalProperties` 注入 Devices 子构建。不传 → Devices 子项目走 NuGet 分支引 Algorithm 包 → 源码版 Devices + NuGet 版 Algorithm 混用 → 类型冲突 + 调试断链。

**所以 `WeldoneWithSource.slnx` 只是"看得见"，`UseRobimWeldSource` 才是"切得动"——两者必须配合。**

## 仓库克隆布局

```
D:\
├── weldone
├── RobimWeld.Algorithm
└── RobimWeld.Devices
```

私有仓库地址：
```
git@gitlab.roboticplus.com:robimweld/RobimWeld.Algorithm.git
git@gitlab.roboticplus.com:robimweld/RobimWeld.Devices.git
```

## 产出包 → 源码 csproj 映射

| 包 | 源码 csproj |
|---|---|
| RobimWeld.Algorithm.Weld | `$(RobimWeldAlgorithmSourceRoot)\src\RobimWeld.Algorithm.Weld\RobimWeld.Algorithm.Weld.csproj` |
| RobimWeld.Data.Weld | `$(RobimWeldAlgorithmSourceRoot)\src\RobimWeld.Data.Weld\RobimWeld.Data.Weld.csproj` |
| RobimWeld.Devices | `$(RobimWeldDevicesSourceRoot)\src\RobimWeld.Devices\RobimWeld.Devices.csproj` |
| RobimWeld.Devices.Robot | `$(RobimWeldDevicesSourceRoot)\src\RobimWeld.Devices.Robot\RobimWeld.Devices.Robot.csproj` |
| RobimWeld.Devices.Vision | `$(RobimWeldDevicesSourceRoot)\src\RobimWeld.Devices.Vision\RobimWeld.Devices.Vision.csproj` |
| RobimWeld.Scanning.Contracts | `$(RobimWeldDevicesSourceRoot)\src\RobimWeld.Scanning.Contracts\RobimWeld.Scanning.Contracts.csproj` |

主仓 `Directory.Build.props` 的 `ValidateRobimWeldSourceProjects` target 会在 `UseRobimWeldSource=true` 但上述路径不存在时报 Error 并阻断构建。

## Rider 打开方式（WeldoneWithSource.slnx）

主仓根有 `WeldoneWithSource.slnx`（受版本管理），在 `WeldoneForCode.slnf` 的 18 个主仓项目基础上额外引入 6 个外部源码 csproj（路径 `../RobimWeld.Algorithm/...`、`../RobimWeld.Devices/...`）。

- **有权限者**：用 Rider 打开 `WeldoneWithSource.slnx`，Solution Explorer 里能看到并展开 6 个源码项目（L2 浏览）。
- **低权限者**：拉不到源码仓库，路径标红但不影响 `Weldone.sln` / `WeldoneForCode.slnf` 正常使用——他们用那两个文件。
- **配合 L3**：用 `WeldoneWithSource.slnx` 打开 Rider 的同时设 `local.props` 开 `UseRobimWeldSource=true`，源码项目既可见又被 ProjectReference 引用，改动即生效。

两种模式下 `WeldoneWithSource.slnx` 都能 build（已验证）：
- NuGet 模式：主仓走 PackageReference，源码项目作为独立可编译悬空项目
- 源码模式：主仓走 ProjectReference，整条链全源码

## 切换到源码模式工作流

收到"切源码调试""改算法源码"等请求后执行：

### 1. 前置校验（只读，不写文件）
- 两个源码根目录是否存在：
  ```bash
  ls -d /mnt/d/RobimWeld.Algorithm /mnt/d/RobimWeld.Devices
  ```
- 源码版本 ≥ NuGet 引用版本：读源仓库版本号（见 `robimweld-release-check` 的版本号读取规则）vs 主仓 `Directory.Packages.props` 引用版本。版本不一致时**警告但不阻断**——用户可能故意要改源码升版本。
- 路径不在默认同级目录时，提示在 `Directory.Build.local.props` 里额外设 `RobimWeldAlgorithmSourceRoot`/`RobimWeldDevicesSourceRoot`。

### 2. 写 Directory.Build.local.props
```xml
<Project>
  <PropertyGroup>
    <UseRobimWeldSource>true</UseRobimWeldSource>
  </PropertyGroup>
</Project>
```
该文件已被 `.gitignore` 忽略，不会被提交。

### 3. clean + restore + build 验证
```bash
DOTNET_NOLOGO=1 "/mnt/c/Program Files/dotnet/dotnet.exe" clean WeldoneForCode.slnf
DOTNET_NOLOGO=1 "/mnt/c/Program Files/dotnet/dotnet.exe" restore WeldoneForCode.slnf --force-evaluate
DOTNET_NOLOGO=1 "/mnt/c/Program Files/dotnet/dotnet.exe" build WeldoneForCode.slnf
```
> ⚠️ `--force-evaluate` 关键：强制重新解析，避免 restore 缓存里还是旧的 PackageReference。
> `WeldoneForCode.slnf` 是源码调试的精简解决方案文件（不含 ZMJ 等插件全量，启动快）。完整构建用 `Weldone.sln`。
> Linux 端无 dotnet，必须用 Windows 端 `/mnt/c/Program Files/dotnet/dotnet.exe`，加 `DOTNET_NOLOGO=1` 减噪。

### 4. 报告
切换结果：构建是否通过、当前模式（源码 vs NuGet，读 local.props 是否存在判定）。

## 切回 NuGet 模式工作流

收到"切回 NuGet""关掉源码模式"等请求后执行：

1. 删 `Directory.Build.local.props`（若存在）：
   ```bash
   rm -f /mnt/d/weldone/Directory.Build.local.props
   ```
2. clean + restore + build（同上命令）。
3. 报告已回 NuGet 模式。

## 单次切换（不落文件）

不想持久切换、只想临时用源码跑一次：
```bash
DOTNET_NOLOGO=1 "/mnt/c/Program Files/dotnet/dotnet.exe" build WeldoneForCode.slnf -p:UseRobimWeldSource=true
```

## 当前模式判定

读 `Directory.Build.local.props` 是否存在且含 `UseRobimWeldSource=true`：
```bash
cat /mnt/d/weldone/Directory.Build.local.props 2>/dev/null | grep "UseRobimWeldSource"
```
存在且为 `true` → 源码模式；文件不存在或值为 false → NuGet 模式。

## 常见陷阱

- **改了源码没生效**：忘了 `clean` + `restore --force-evaluate`，restore 用了缓存的旧 PackageReference。务必三步都跑。
- **源码与 NuGet 程序集混用**：源码版本 < NuGet 引用版本，或只切了一部分包。切之前先跑 `robimweld-release-check` 确认源码版本到位。
- **路径不存在 Error**：`ValidateRobimWeldSourceProjects` target 在 `UseRobimWeldSource=true` 但路径不存在时报 Error。先确认克隆位置与 `RobimWeld*SourceRoot` 设置。
- **非默认同级目录**：在 `Directory.Build.local.props` 额外设：
  ```xml
  <RobimWeldAlgorithmSourceRoot>D:\path\to\RobimWeld.Algorithm</RobimWeldAlgorithmSourceRoot>
  <RobimWeldDevicesSourceRoot>D:\path\to\RobimWeld.Devices</RobimWeldDevicesSourceRoot>
  ```
- **grep -iE 报 "conflicting matchers specified"**：本仓 shell 环境 `-i` + `-E` 组合有别名陷阱。用单选项 `grep "UseRobimWeldSource"` 或 `Select-String`。

## 与 robimweld-release-check 联动

切源码前应先跑 `robimweld-release-check`：确认源仓库已发版对应主仓引用版本，且本地克隆的分支/tag 版本号 ≥ NuGet 引用版本。否则改了源码但 NuGet 包是旧的，单步进去看的可能是旧逻辑，或出现源码与 NuGet 程序集混用。

联动示例：用户说"我要改算法源码联调"→ 先建议跑 `robimweld-release-check` 确认 `2.0.1-alpha` 已落库且本地 kuka 分支在 `v2.0.1-alpha` tag 上 → 再切源码模式。

## 不做什么（scope 边界）

- 不发版、不查 RP feed、不打 tag（`robimweld-release-check` 的职责）。
- 不修改源码仓库内容（只读源码版本号做校验）。
- 不碰 `Robim.Data` / `one_punch` 等生态包的源码切换（它们没有 `UseRobimWeldSource` 机制）。
- 不改 `Directory.Build.props`（主仓受版本管理的文件），只写 gitignore 忽略的 `Directory.Build.local.props`。
- 不直接 `dotnet pack` / `dotnet nuget push`。

## 辅助脚本

`scripts/switch-robimweld-source.ps1` 封装切换与校验逻辑：
```bash
# 只读校验：路径 + 版本比对，不写文件不构建
"/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass \
  -File "$(wslpath -w /mnt/d/weldone/.agents/skills/robimweld-source-debug/scripts/switch-robimweld-source.ps1)" -Mode Check

# 切到源码模式：校验 + 写 local.props + clean/restore/build
... -Mode On

# 切回 NuGet 模式：删 local.props + clean/restore/build
... -Mode Off
```
> 脚本 UTF-8 BOM 保存（规避 PowerShell 5.1 GBK 中文乱码），状态标记用 ASCII。skill 主体也能纯 Bash 手动完成，不强制依赖脚本。
