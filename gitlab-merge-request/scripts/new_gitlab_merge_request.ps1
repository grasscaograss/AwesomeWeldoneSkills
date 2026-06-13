[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceBranch,

    [Parameter(Mandatory = $true)]
    [string]$TargetBranch,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$Description = "",

    [string]$GitLabUrl = "http://gitlab.roboticplus.com:2022",

    [string]$ProjectId = "305",

    [string]$Token = $env:GITLAB_TOKEN,

    [switch]$RemoveSourceBranch,

    [switch]$NoSquash,

    [switch]$Draft,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

function ConvertTo-GitLabJson {
    param([Parameter(ValueFromPipeline = $true)]$InputObject)
    process {
        $InputObject | ConvertTo-Json -Depth 10
    }
}

function Invoke-GitLabRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Get", "Post")]
        [string]$Method,

        [object]$Body = $null
    )

    $headers = @{
        "PRIVATE-TOKEN" = $Token
        "Content-Type"  = "application/json; charset=utf-8"
    }

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Uri $Uri -Headers $headers -Method $Method
        }

        $json = $Body | ConvertTo-Json -Depth 10 -Compress
        return Invoke-RestMethod -Uri $Uri -Headers $headers -Method $Method -Body $json -ContentType "application/json; charset=utf-8"
    }
    catch {
        [pscustomobject]@{
            ok      = $false
            error   = $_.Exception.Message
            status  = Get-HttpStatusText -Exception $_.Exception
            uri     = $Uri
            created = $false
        } | ConvertTo-GitLabJson
        exit 1
    }
}

function Get-HttpStatusText {
    param([Parameter(Mandatory = $true)]$Exception)

    if (-not $Exception.Response) {
        return $null
    }

    $statusCode = [int]$Exception.Response.StatusCode
    $statusText = if ($Exception.Response.PSObject.Properties.Name -contains "ReasonPhrase") {
        $Exception.Response.ReasonPhrase
    }
    elseif ($Exception.Response.PSObject.Properties.Name -contains "StatusDescription") {
        $Exception.Response.StatusDescription
    }
    else {
        $Exception.Response.StatusCode.ToString()
    }

    return "$statusCode $statusText"
}

function Stop-WithJsonError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [object]$Details = $null
    )

    [pscustomobject]@{
        ok      = $false
        error   = $Message
        details = $Details
        created = $false
    } | ConvertTo-GitLabJson
    exit 1
}

function Assert-GitLabBranchExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName,

        [Parameter(Mandatory = $true)]
        [string]$EncodedBranchName
    )

    $headers = @{
        "PRIVATE-TOKEN" = $Token
        "Content-Type"  = "application/json; charset=utf-8"
    }
    $uri = "$apiBase/repository/branches/$EncodedBranchName"

    try {
        Invoke-RestMethod -Uri $uri -Headers $headers -Method Get | Out-Null
    }
    catch {
        Stop-WithJsonError -Message "GitLab branch does not exist or cannot be read" -Details @{
            branch = $BranchName
            status = Get-HttpStatusText -Exception $_.Exception
            uri    = $uri
        }
    }
}

function Get-TitleForValidation {
    param([Parameter(Mandatory = $true)][string]$Value)

    return ($Value -replace "^(Draft|WIP):\s*", "").Trim()
}

$titleForValidation = Get-TitleForValidation -Value $Title
$conventionalTitlePattern = "^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([^)]+\))?: .+"

if ($titleForValidation -notmatch $conventionalTitlePattern) {
    Stop-WithJsonError -Message "MR title must use conventional commit format, for example: fix: 修复工件删除崩溃" -Details @{
        title = $Title
    }
}

if ($titleForValidation.Length -gt 20) {
    Stop-WithJsonError -Message "MR title must be 20 characters or fewer" -Details @{
        title  = $Title
        length = $titleForValidation.Length
        limit  = 20
    }
}

if ([string]::IsNullOrWhiteSpace($Description)) {
    Stop-WithJsonError -Message "MR description is required and must include the concrete changes"
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    [pscustomobject]@{
        ok      = $false
        error   = "GITLAB_TOKEN is not set"
        created = $false
    } | ConvertTo-GitLabJson
    exit 1
}

$apiRoot = "$GitLabUrl/api/v4"
$apiBase = "$apiRoot/projects/$ProjectId"
$shouldSquash = -not [bool]$NoSquash

$user = Invoke-GitLabRequest -Uri "$apiRoot/user" -Method Get
$encodedSource = [System.Uri]::EscapeDataString($SourceBranch)
$encodedTarget = [System.Uri]::EscapeDataString($TargetBranch)

Assert-GitLabBranchExists -BranchName $SourceBranch -EncodedBranchName $encodedSource
Assert-GitLabBranchExists -BranchName $TargetBranch -EncodedBranchName $encodedTarget

$existingUri = "$apiBase/merge_requests?state=opened&source_branch=$encodedSource&target_branch=$encodedTarget&per_page=20"
$existing = Invoke-GitLabRequest -Uri $existingUri -Method Get

if (-not $Force -and $existing.Count -gt 0) {
    $mr = @($existing)[0]
    [pscustomobject]@{
        ok                    = $true
        created               = $false
        reason                = "opened merge request already exists for source/target"
        iid                   = $mr.iid
        title                 = $mr.title
        state                 = $mr.state
        source_branch         = $mr.source_branch
        target_branch         = $mr.target_branch
        web_url               = $mr.web_url
        squash                = $mr.squash
        detailed_merge_status = $mr.detailed_merge_status
        api_user              = $user.username
    } | ConvertTo-GitLabJson
    exit 0
}

if ($Draft -and $Title -notmatch "^(Draft|WIP):") {
    $Title = "Draft: $Title"
}

$body = @{
    source_branch        = $SourceBranch
    target_branch        = $TargetBranch
    title                = $Title
    description          = $Description
    remove_source_branch = [bool]$RemoveSourceBranch
    squash               = $shouldSquash
}

$createdMr = Invoke-GitLabRequest -Uri "$apiBase/merge_requests" -Method Post -Body $body

[pscustomobject]@{
    ok                    = $true
    created               = $true
    iid                   = $createdMr.iid
    title                 = $createdMr.title
    state                 = $createdMr.state
    source_branch         = $createdMr.source_branch
    target_branch         = $createdMr.target_branch
    web_url               = $createdMr.web_url
    has_conflicts         = $createdMr.has_conflicts
    squash                = $createdMr.squash
    detailed_merge_status = $createdMr.detailed_merge_status
    api_user              = $user.username
} | ConvertTo-GitLabJson
