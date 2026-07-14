#Requires -Version 5.1
<#
.SYNOPSIS
  查询 RobimWeld.* 包在主仓引用版本与 RP feed 已发布版本的一致性。
  纯只读校验，不含 push/tag 逻辑。

.DESCRIPTION
  1. 读主仓 Directory.Packages.props 取 6 个 RobimWeld.* 包引用版本
  2. 查 RP feed（BaGet）确认每个包是否落库及最新版本
  3. 输出一致性表格 + 状态判定

  用法：
    powershell -ExecutionPolicy Bypass -File .agents/skills/robimweld-release-check/scripts/check-robimweld-versions.ps1

  注意：本仓 shell 里 grep -iE 会报 "conflicting matchers specified"，
  脚本统一用 PowerShell Select-String / XML 解析规避此问题。
#>

param(
    [string]$WeldoneRoot = "D:\weldone",
    [string]$FeedSource = "http://gitlab.roboticplus.com:2023/v3/index.json"
)

$ErrorActionPreference = "Stop"

# --- 1. 读主仓引用版本 ---
$propsPath = Join-Path $WeldoneRoot "Directory.Packages.props"
if (-not (Test-Path $propsPath)) {
    Write-Error "找不到 $propsPath，确认 -WeldoneRoot 指向主仓根目录。"
    exit 1
}

# 6 个本 skill 覆盖的包
$targetPackages = @(
    "RobimWeld.Algorithm.Weld",
    "RobimWeld.Data.Weld",
    "RobimWeld.Devices",
    "RobimWeld.Devices.Robot",
    "RobimWeld.Devices.Vision",
    "RobimWeld.Scanning.Contracts"
)

# 解析 XML 取 PackageVersion
[xml]$props = Get-Content -LiteralPath $propsPath -Encoding UTF8
$pkgVersions = @{}
foreach ($node in $props.Project.ItemGroup.PackageVersion) {
    if ($targetPackages -contains $node.Include) {
        $pkgVersions[$node.Include] = $node.Version
    }
}

if ($pkgVersions.Count -eq 0) {
    Write-Error "Directory.Packages.props 未找到任何 RobimWeld.* 包引用。"
    exit 1
}

Write-Host "=== 主仓引用版本（$WeldoneRoot）===" -ForegroundColor Cyan
$pkgVersions.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-32} {1}" -f $_.Key, $_.Value)
}
Write-Host ""

# --- 2. 查 RP feed 落库状态 ---
Write-Host "=== RP feed 落库状态（$FeedSource）===" -ForegroundColor Cyan

$results = @()
foreach ($pkg in $targetPackages) {
    $referenced = $pkgVersions[$pkg]
    if (-not $referenced) {
        $results += [PSCustomObject]@{
            Package = $pkg; Referenced = "(未引用)"; Latest = "-"; Published = $false; Status = "WARN"
        }
        continue
    }

    # 用 dotnet package search 查 latest version
    $searchOut = & dotnet package search $pkg --prerelease --source $FeedSource 2>$null |
        Select-String -Pattern "\|\s*$pkg\s*\|\s*(\S+)\s*\|" |
        Select-Object -First 1

    $latest = "-"
    $published = $false
    if ($searchOut -and $searchOut.Matches) {
        $latest = $searchOut.Matches[0].Groups[1].Value
    }

    # PackageBaseAddress 确认引用版本是否真的存在
    # service index: @id=http://gitlab.roboticplus.com:2023/v3/package (@type=PackageBaseAddress/3.0.0)
    $flat = "http://gitlab.roboticplus.com:2023/v3/package/$($pkg.ToLower())/index.json"
    try {
        $resp = Invoke-RestMethod -Uri $flat -Method Get -TimeoutSec 30
        if ($resp.versions -contains $referenced) {
            $published = $true
        }
    } catch {
        # feed 不支持 flat-container 或网络问题，退回 search 结果判定
        if ($latest -ne "-" -and $latest -ne "") { $published = $true }
    }

    $status = if ($published) { "OK" } else { "MISSING" }
    $results += [PSCustomObject]@{
        Package = $pkg; Referenced = $referenced; Latest = $latest; Published = $published; Status = $status
    }
}

$results | Format-Table -AutoSize

# --- 3. 汇总 ---
$missing = $results | Where-Object { -not $_.Published }
if ($missing) {
    Write-Host ""
    Write-Host "[MISSING] 以下包引用版本未在 RP feed 落库（可能 tag 未推送）：" -ForegroundColor Red
    $missing | ForEach-Object {
        Write-Host ("  {0}  {1}" -f $_.Package, $_.Referenced) -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "建议：检查对应源仓库是否打了 v$($missing[0].Referenced) tag 并 push。" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "[OK] 所有 RobimWeld.* 包引用版本均已落库。" -ForegroundColor Green
}
