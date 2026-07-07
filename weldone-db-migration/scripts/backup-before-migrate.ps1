param(
    [string]$RepoRoot = "D:\weldone",
    [string]$ConfigPath = "src/Weldone/appsettings.json"
)

$ErrorActionPreference = "Stop"

$repo = Resolve-Path -LiteralPath $RepoRoot
Set-Location -LiteralPath $repo

$roamingRoot = if ($env:APPDATA) {
    $env:APPDATA
} elseif ($env:USERPROFILE) {
    Join-Path $env:USERPROFILE "AppData\Roaming"
} elseif ($env:HOME) {
    $env:HOME
} else {
    throw "APPDATA, USERPROFILE, and HOME are all empty; cannot resolve backup directory."
}

$backupDir = Join-Path $roamingRoot "Roboticplus\Weldone\backup-db"
$targetName = "ai-backup-before-migrate-{0}.backup" -f (Get-Date -Format "yyyy-MMdd-HHmm-ssff")
$targetPath = Join-Path $backupDir $targetName

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$before = @{}
Get-ChildItem -LiteralPath $backupDir -File -ErrorAction SilentlyContinue | ForEach-Object { $before[$_.FullName] = $true }

just backup-db $ConfigPath $backupDir
if ($LASTEXITCODE -ne 0) {
    throw "just backup-db failed with exit code $LASTEXITCODE"
}

$created = Get-ChildItem -LiteralPath $backupDir -File |
    Where-Object { -not $before.ContainsKey($_.FullName) } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $created) {
    $created = Get-ChildItem -LiteralPath $backupDir -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

if (-not $created) {
    throw "No backup file was created in $backupDir"
}

if ($created.FullName -ne $targetPath) {
    Move-Item -LiteralPath $created.FullName -Destination $targetPath -Force
}

Write-Output $targetPath

