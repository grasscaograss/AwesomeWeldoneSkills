#Requires -Version 7.0

param(
    [string]$RepoRoot = "D:\weldone"
)

$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function Write-Section([string]$Title) {
    Write-Output ""
    Write-Output "=== $Title ==="
}

$repo = Resolve-Path -LiteralPath $RepoRoot
Set-Location -LiteralPath $repo

Write-Section "Repository"
Write-Output $repo.Path

Write-Section "Just database tasks"
if (Test-Path -LiteralPath "justfile") {
    Select-String -Path "justfile" -Pattern "^(add-m|remove-m|update-db|migrate|backup-db|pod)\b|dotnet ef" | ForEach-Object {
        "{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
    }
} else {
    Write-Output "justfile not found"
}

Write-Section "Recent migrations"
$migrationDir = Join-Path $repo.Path "src\Weldone.EntityFrameworkCore\Migrations"
if (Test-Path -LiteralPath $migrationDir) {
    Get-ChildItem -LiteralPath $migrationDir -Filter "*.cs" |
        Where-Object { $_.Name -notlike "*.Designer.cs" -and $_.Name -ne "WeldoneDbContextModelSnapshot.cs" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 12 |
        ForEach-Object { "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f $_.LastWriteTime, $_.Name }
} else {
    Write-Output "Migration directory not found: $migrationDir"
}

Write-Section "Changed EF-related files"
$gitAvailable = $false
try {
    git rev-parse --is-inside-work-tree *> $null
    $gitAvailable = $LASTEXITCODE -eq 0
} catch {
    $gitAvailable = $false
}

if ($gitAvailable) {
    $patterns = @(
        "src/Weldone.Domain/",
        "src/Weldone.EntityFrameworkCore/",
        "src/Weldone.DbMigrator/"
    )
    $changed = git status --short -- @patterns 2>$null
    if ($changed) {
        $changed | Where-Object { $_ -match "(DbContext|Migrations|EntityFrameworkCore|\.cs$|DataSeed|Seeder|EfCore)" }
    } else {
        Write-Output "No local EF-related changes detected. If code was just pulled, compare with the failing error and recent migrations."
    }
} else {
    Write-Output "Git status unavailable."
}

Write-Section "Recommended next command"
Write-Output "If the error is missing column/table or pending migrations: just update-db"
Write-Output "If schema is current but seed/default data is missing: run backup-before-migrate.ps1, then just migrate"
$roamingRoot = if ($env:APPDATA) {
    $env:APPDATA
} elseif ($env:USERPROFILE) {
    Join-Path $env:USERPROFILE "AppData\Roaming"
} elseif ($env:HOME) {
    $env:HOME
} else {
    "<APPDATA>"
}
$backupDir = Join-Path $roamingRoot "Roboticplus\Weldone\backup-db"
$backupName = "ai-backup-before-migrate-{0}.backup" -f (Get-Date -Format "yyyy-MMdd-HHmm-ssff")
Write-Output ("Migrate backup directory: {0}" -f $backupDir)
Write-Output ("Migrate backup filename pattern: {0}" -f $backupName)
Write-Output "If model changed but no migration exists: just add-m <MigrationName>, review generated migration, then just update-db"
Write-Output "Do not manually ALTER TABLE/CREATE TABLE for normal application schema drift."

