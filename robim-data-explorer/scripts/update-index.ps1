#Requires -Version 5.1
<#
.SYNOPSIS
    Regenerates the type index for robim-data-explorer skill.
.DESCRIPTION
    Scans d:/robim_data/src for public C# types and protobuf messages/enums,
    then writes an updated references/type-index.md.
#>

$BaseDir = "D:/robim_data/src"
$SkillDir = "$env:USERPROFILE/.claude/skills/robim-data-explorer"
$OutputFile = "$SkillDir/references/type-index.md"

function Write-IndexSection {
    param(
        [string]$Title,
        [array]$Rows
    )
    Add-Content -Path $OutputFile -Value ""
    Add-Content -Path $OutputFile -Value "## $Title"
    Add-Content -Path $OutputFile -Value ""
    Add-Content -Path $OutputFile -Value "| Type | Kind | Namespace | File |"
    Add-Content -Path $OutputFile -Value "|------|------|-----------|------|"
    foreach ($row in $Rows) {
        $line = "| {0} | {1} | {2} | {3} |" -f $row.Type, $row.Kind, $row.Namespace, $row.File
        Add-Content -Path $OutputFile -Value $line
    }
}

# Header
Set-Content -Path $OutputFile -Value @"
# Robim.Data Type Index

Auto-generated index mapping type names to source files in d:/robim_data.
When a user references a Robim.Data type, look up the type here to find its definition file.
"@

# --- C# types in Robim.Data ---
$rows = @()
$csFiles = Get-ChildItem -Path "$BaseDir/Robim.Data" -Filter "*.cs" -Recurse |
    Where-Object { $_.FullName -notmatch "\\obj\\" }
foreach ($file in $csFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $rel = $file.FullName.Replace("D:/robim_data/", "")
    $ns = [regex]::Match($content, "namespace\s+([\w.]+)").Groups[1].Value
    if (-not $ns) { $ns = "Robim.Data" }
    $matches = [regex]::Matches($content, "public\s+(class|struct|interface|enum|record)\s+(\w+)")
    foreach ($m in $matches) {
        $rows += [PSCustomObject]@{
            Type      = $m.Groups[2].Value
            Kind      = $m.Groups[1].Value
            Namespace = $ns
            File      = $rel
        }
    }
}
Write-IndexSection -Title "Robim.Data (Hand-written C#)" -Rows ($rows | Sort-Object Type)

# --- Protobuf types ---
$rows = @()
$protoFiles = Get-ChildItem -Path "$BaseDir/Robim.Data/Protobuf" -Filter "*.proto" -Recurse
foreach ($file in $protoFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $rel = $file.FullName.Replace("D:/robim_data/", "")
    $pkg = [regex]::Match($content, "package\s+([\w.]+)").Groups[1].Value
    if (-not $pkg) { $pkg = "(no package)" }
    $matches = [regex]::Matches($content, "^(message|enum)\s+(\w+)", [System.Text.RegularExpressions.RegexOptions]::Multiline)
    foreach ($m in $matches) {
        $rows += [PSCustomObject]@{
            Type      = $m.Groups[2].Value
            Kind      = $m.Groups[1].Value
            Namespace = $pkg
            File      = $rel
        }
    }
}
Write-IndexSection -Title "Protobuf Definitions" -Rows ($rows | Sort-Object Type)

# --- Robim.Service.Core ---
$rows = @()
$csFiles = Get-ChildItem -Path "$BaseDir/Robim.Service.Core" -Filter "*.cs" -Recurse |
    Where-Object { $_.FullName -notmatch "\\obj\\" }
foreach ($file in $csFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $rel = $file.FullName.Replace("D:/robim_data/", "")
    $ns = [regex]::Match($content, "namespace\s+([\w.]+)").Groups[1].Value
    if (-not $ns) { $ns = "Robim.Service.Core" }
    $matches = [regex]::Matches($content, "public\s+(class|struct|interface|enum|record)\s+(\w+)")
    foreach ($m in $matches) {
        $rows += [PSCustomObject]@{
            Type      = $m.Groups[2].Value
            Kind      = $m.Groups[1].Value
            Namespace = $ns
            File      = $rel
        }
    }
}
Write-IndexSection -Title "Robim.Service.Core" -Rows ($rows | Sort-Object Type)

Write-Host "Index regenerated: $OutputFile"
