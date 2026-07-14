#Requires -Version 5.1
<#
.SYNOPSIS
  切换 RobimWeld 源码调试模式（UseRobimWeldSource）。

.DESCRIPTION
  -Mode Check  只读校验：源码路径存在性 + 源码版本 vs NuGet 引用版本比对，不写文件不构建
  -Mode On     校验 + 写 Directory.Build.local.props + clean/restore/build
  -Mode Off    删 Directory.Build.local.props + clean/restore/build

  脚本 UTF-8 BOM 保存（规避 PowerShell 5.1 GBK 中文乱码），状态标记用 ASCII。

  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File switch-robimweld-source.ps1 -Mode Check
    powershell -NoProfile -ExecutionPolicy Bypass -File switch-robimweld-source.ps1 -Mode On
    powershell -NoProfile -ExecutionPolicy Bypass -File switch-robimweld-source.ps1 -Mode Off
#>

param(
    [ValidateSet("Check","On","Off")]
    [string]$Mode = "Check",
    [string]$WeldoneRoot = "D:\weldone",
    [string]$AlgorithmRoot = "D:\RobimWeld.Algorithm",
    [string]$DevicesRoot = "D:\RobimWeld.Devices",
    [string]$DotnetExe = "dotnet",
    [string]$Slnf = "WeldoneForCode.slnf"
)

$ErrorActionPreference = "Stop"

$localPropsPath = Join-Path $WeldoneRoot "Directory.Build.local.props"
$packagesPropsPath = Join-Path $WeldoneRoot "Directory.Packages.props"

# ============================================================
# 辅助：读主仓 Directory.Packages.props 取 RobimWeld.* 引用版本
# ============================================================
function Get-ReferencedVersions {
    if (-not (Test-Path $packagesPropsPath)) {
        Write-Error "找不到 $packagesPropsPath"
        exit 1
    }
    [xml]$props = Get-Content -LiteralPath $packagesPropsPath -Encoding UTF8
    $map = @{}
    foreach ($node in $props.Project.ItemGroup.PackageVersion) {
        if ($node.Include -like "RobimWeld.*") {
            $map[$node.Include] = $node.Version
        }
    }
    return $map
}

# ============================================================
# 辅助：读源仓库版本号
# 优先级：RobimWeldPackageVersion（实际值，Devices kuka 线）> Version（字面值，非 $(...) 变量引用）
# 护圈龙门 1.x Algorithm 仓库 props 无 Version 时，fallback 遍历 src csproj
# ============================================================
function Get-RepoVersion {
    param([string]$RepoRoot)

    $dbp = Join-Path $RepoRoot "Directory.Build.props"
    $ver = $null

    if (Test-Path $dbp) {
        [xml]$p = Get-Content -LiteralPath $dbp -Encoding UTF8
        # XPath 取属性元素（SelectNodes 比 .PropertyGroup.Version 更稳健）
        $rwNode = $p.SelectSingleNode("/Project/PropertyGroup/RobimWeldPackageVersion")
        if ($rwNode) {
            $candidate = $rwNode.InnerText.Trim()
            if ($candidate -and $candidate -notlike '`$(*') { $ver = $candidate }
        }
        if (-not $ver) {
            $vNode = $p.SelectSingleNode("/Project/PropertyGroup/Version")
            if ($vNode) {
                $candidate = $vNode.InnerText.Trim()
                # 跳过变量引用如 $(RobimWeldPackageVersion)，取不到实际值
                if ($candidate -and $candidate -notlike '`$(*') { $ver = $candidate }
            }
        }
    }

    # fallback：props 无字面 Version 时遍历 src csproj 取 Version 并集
    if (-not $ver) {
        $csprojs = Get-ChildItem -Path (Join-Path $RepoRoot "src") -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue
        $versions = @()
        foreach ($cs in $csprojs) {
            [xml]$cx = Get-Content -LiteralPath $cs.FullName -Encoding UTF8
            $vNode = $cx.SelectSingleNode("/Project/PropertyGroup/Version")
            if ($vNode) {
                $candidate = $vNode.InnerText.Trim()
                if ($candidate -and $candidate -notlike '`$(*') { $versions += $candidate }
            }
        }
        $versions = $versions | Select-Object -Unique
        if ($versions.Count -eq 1) {
            $ver = $versions[0]
        } elseif ($versions.Count -gt 1) {
            Write-Host "[WARN] $RepoRoot 仓库内版本号不一致：$($versions -join ', ')（需人工对齐）" -ForegroundColor Yellow
            $ver = $versions[0]
        }
    }
    return $ver
}

# ============================================================
# Mode: Check —— 只读校验
# ============================================================
function Invoke-Check {
    Write-Host "=== RobimWeld 源码调试模式校验 ===" -ForegroundColor Cyan
    Write-Host ""

    # 1. 路径存在性
    Write-Host "[1] 源码路径校验" -ForegroundColor Cyan
    $algoOk = Test-Path $AlgorithmRoot
    $devOk  = Test-Path $DevicesRoot
    Write-Host ("  Algorithm  {0}  {1}" -f $(if($algoOk){"OK"}else{"MISSING"}), $AlgorithmRoot)
    Write-Host ("  Devices    {0}  {1}" -f $(if($devOk){"OK"}else{"MISSING"}), $DevicesRoot)
    if (-not $algoOk -or -not $devOk) {
        Write-Host ""
        Write-Host "[FAIL] 源码仓库未克隆到预期位置。请先 clone：" -ForegroundColor Red
        Write-Host "  git clone git@gitlab.roboticplus.com:robimweld/RobimWeld.Algorithm.git $AlgorithmRoot"
        Write-Host "  git clone git@gitlab.roboticplus.com:robimweld/RobimWeld.Devices.git $DevicesRoot"
        return
    }
    Write-Host ""

    # 2. 当前模式判定
    Write-Host "[2] 当前模式" -ForegroundColor Cyan
    $currentMode = "NuGet"
    if (Test-Path $localPropsPath) {
        $lp = Get-Content -LiteralPath $localPropsPath -Raw -Encoding UTF8
        if ($lp -match "UseRobimWeldSource\s*[=:]\s*true") {
            $currentMode = "Source"
        }
    }
    Write-Host "  $currentMode"
    Write-Host ""

    # 3. 版本比对
    Write-Host "[3] 版本比对（源码 vs NuGet 引用）" -ForegroundColor Cyan
    $refMap = Get-ReferencedVersions
    $algoVer = Get-RepoVersion -RepoRoot $AlgorithmRoot
    $devVer  = Get-RepoVersion -RepoRoot $DevicesRoot

    # 仓库→产出包映射
    $repoPackages = @{
        $AlgorithmRoot = @("RobimWeld.Algorithm.Weld","RobimWeld.Data.Weld")
        $DevicesRoot   = @("RobimWeld.Devices","RobimWeld.Devices.Robot","RobimWeld.Devices.Vision","RobimWeld.Scanning.Contracts")
    }
    $repoVer = @{ $AlgorithmRoot = $algoVer; $DevicesRoot = $devVer }

    $rows = @()
    foreach ($repo in @($AlgorithmRoot, $DevicesRoot)) {
        $repoV = $repoVer[$repo]
        foreach ($pkg in $repoPackages[$repo]) {
            $refV = $refMap[$pkg]
            $status = "OK"
            if (-not $repoV) {
                $status = "WARN(noversion)"
            } elseif ($refV -and ($repoV -ne $refV)) {
                # 版本不一致：警告但不阻断（用户可能故意要改源码升版本）
                $status = "WARN(mismatch)"
            }
            $rows += [PSCustomObject]@{
                Package = $pkg; NuGetRef = $refV; SourceVer = $repoV; Status = $status
            }
        }
    }
    $rows | Format-Table -AutoSize

    $warn = $rows | Where-Object { $_.Status -like "WARN*" }
    if ($warn) {
        Write-Host "[WARN] 存在版本不一致：源码版本与 NuGet 引用不同。" -ForegroundColor Yellow
        Write-Host "  可能用户故意要改源码升版本，不阻断。但切源码前建议确认源码版本 >= NuGet 引用版本。" -ForegroundColor Yellow
        Write-Host "  可先跑 robimweld-release-check 确认发布状态。" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] 源码版本与 NuGet 引用一致，可安全切源码模式。" -ForegroundColor Green
    }
    Write-Host ""

    # 4. 切换建议
    if ($currentMode -eq "NuGet") {
        Write-Host "[建议] 当前 NuGet 模式。切源码调试：-Mode On" -ForegroundColor Cyan
    } else {
        Write-Host "[建议] 当前源码模式。切回 NuGet：-Mode Off" -ForegroundColor Cyan
    }
}

# ============================================================
# Mode: On —— 切到源码模式
# ============================================================
function Invoke-On {
    Write-Host "=== 切到 RobimWeld 源码模式 ===" -ForegroundColor Cyan

    # 路径校验
    if (-not (Test-Path $AlgorithmRoot) -or -not (Test-Path $DevicesRoot)) {
        Write-Host "[FAIL] 源码仓库未克隆到位，先跑 -Mode Check 看详情。" -ForegroundColor Red
        return
    }

    # 写 local.props
    $content = @"
<Project>
  <PropertyGroup>
    <UseRobimWeldSource>true</UseRobimWeldSource>
  </PropertyGroup>
</Project>
"@
    Set-Content -LiteralPath $localPropsPath -Value $content -Encoding UTF8
    Write-Host "[OK] 已写 $localPropsPath" -ForegroundColor Green

    # clean + restore + build
    Write-Host "[build] clean..." -ForegroundColor Cyan
    & $DotnetExe clean $Slnf 2>&1 | Out-Null
    Write-Host "[build] restore --force-evaluate..." -ForegroundColor Cyan
    & $DotnetExe restore $Slnf --force-evaluate 2>&1 | Select-Object -Last 5
    Write-Host "[build] build..." -ForegroundColor Cyan
    & $DotnetExe build $Slnf 2>&1 | Select-Object -Last 10

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[OK] 已切到源码模式，构建通过。6 个 RobimWeld.* 包现为 ProjectReference。" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[FAIL] 构建失败（exit $LASTEXITCODE）。检查源码路径或版本对齐。" -ForegroundColor Red
    }
}

# ============================================================
# Mode: Off —— 切回 NuGet 模式
# ============================================================
function Invoke-Off {
    Write-Host "=== 切回 NuGet 模式 ===" -ForegroundColor Cyan

    if (Test-Path $localPropsPath) {
        Remove-Item -LiteralPath $localPropsPath -Force
        Write-Host "[OK] 已删 $localPropsPath" -ForegroundColor Green
    } else {
        Write-Host "[INFO] local.props 本就不存在，已是 NuGet 模式。" -ForegroundColor Yellow
    }

    # clean + restore + build
    Write-Host "[build] clean..." -ForegroundColor Cyan
    & $DotnetExe clean $Slnf 2>&1 | Out-Null
    Write-Host "[build] restore --force-evaluate..." -ForegroundColor Cyan
    & $DotnetExe restore $Slnf --force-evaluate 2>&1 | Select-Object -Last 5
    Write-Host "[build] build..." -ForegroundColor Cyan
    & $DotnetExe build $Slnf 2>&1 | Select-Object -Last 10

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[OK] 已切回 NuGet 模式，构建通过。" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[FAIL] 构建失败（exit $LASTEXITCODE）。" -ForegroundColor Red
    }
}

# ============================================================
# 主入口
# ============================================================
switch ($Mode) {
    "Check" { Invoke-Check }
    "On"    { Invoke-On }
    "Off"   { Invoke-Off }
}
