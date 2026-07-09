#Requires -Version 7.0

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

    [switch]$NoMergeWhenPipelineSucceeds,

    [switch]$Draft,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function ConvertTo-GitLabJson {
    param([Parameter(ValueFromPipeline = $true)]$InputObject)
    process {
        $InputObject | ConvertTo-Json -Depth 10
    }
}

function Invoke-GitLabRequestResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Get", "Post", "Put")]
        [string]$Method,

        [object]$Body = $null
    )

    $headers = @{
        "PRIVATE-TOKEN" = $Token
        "Content-Type"  = "application/json; charset=utf-8"
    }

    try {
        if ($null -eq $Body) {
            $response = Invoke-RestMethod -Uri $Uri -Headers $headers -Method $Method
            return [pscustomobject]@{
                ok    = $true
                value = $response
            }
        }

        $json = $Body | ConvertTo-Json -Depth 10 -Compress
        $response = Invoke-RestMethod -Uri $Uri -Headers $headers -Method $Method -Body $json -ContentType "application/json; charset=utf-8"
        return [pscustomobject]@{
            ok    = $true
            value = $response
        }
    }
    catch {
        return [pscustomobject]@{
            ok      = $false
            error   = $_.Exception.Message
            status  = Get-HttpStatusText -Exception $_.Exception
            uri     = $Uri
            created = $false
        }
    }
}

function Invoke-GitLabRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Get", "Post", "Put")]
        [string]$Method,

        [object]$Body = $null
    )

    $result = Invoke-GitLabRequestResult -Uri $Uri -Method $Method -Body $Body
    if ($result.ok) {
        return $result.value
    }

    $result | ConvertTo-GitLabJson
    exit 1
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

function Request-MergeWhenPipelineSucceeds {
    param(
        [Parameter(Mandatory = $true)]
        [object]$MergeRequest,

        [Parameter(Mandatory = $true)]
        [bool]$ShouldSquash,

        [Parameter(Mandatory = $true)]
        [bool]$ShouldRemoveSourceBranch
    )

    $mergeUri = "$apiBase/merge_requests/$($MergeRequest.iid)/merge"
    $mergeBody = @{
        merge_when_pipeline_succeeds = $true
        squash                       = $ShouldSquash
        should_remove_source_branch  = $ShouldRemoveSourceBranch
    }

    if ($MergeRequest.PSObject.Properties.Name -contains "sha" -and -not [string]::IsNullOrWhiteSpace($MergeRequest.sha)) {
        $mergeBody["sha"] = $MergeRequest.sha
    }

    $mergeResult = Invoke-GitLabRequestResult -Uri $mergeUri -Method Put -Body $mergeBody
    if ($mergeResult.ok) {
        return [pscustomobject]@{
            requested     = $true
            method        = "merge_when_pipeline_succeeds"
            merge_request = $mergeResult.value
        }
    }

    return [pscustomobject]@{
        requested = $false
        method    = "merge_when_pipeline_succeeds"
        error     = $mergeResult.error
        status    = $mergeResult.status
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

if ($titleForValidation.Length -gt 50) {
    Stop-WithJsonError -Message "MR title must be 50 characters or fewer" -Details @{
        title  = $Title
        length = $titleForValidation.Length
        limit  = 50
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
$shouldMergeWhenPipelineSucceeds = -not [bool]$NoMergeWhenPipelineSucceeds -and -not [bool]$Draft

$user = Invoke-GitLabRequest -Uri "$apiRoot/user" -Method Get
$encodedSource = [System.Uri]::EscapeDataString($SourceBranch)
$encodedTarget = [System.Uri]::EscapeDataString($TargetBranch)

Assert-GitLabBranchExists -BranchName $SourceBranch -EncodedBranchName $encodedSource
Assert-GitLabBranchExists -BranchName $TargetBranch -EncodedBranchName $encodedTarget

$existingUri = "$apiBase/merge_requests?state=opened&source_branch=$encodedSource&target_branch=$encodedTarget&per_page=20"
$existing = Invoke-GitLabRequest -Uri $existingUri -Method Get

if (-not $Force -and $existing.Count -gt 0) {
    $mr = @($existing)[0]
    $pipelineMergeResult = $null
    $resultMr = $mr

    if ($shouldMergeWhenPipelineSucceeds) {
        $pipelineMergeResult = Request-MergeWhenPipelineSucceeds -MergeRequest $mr -ShouldSquash $shouldSquash -ShouldRemoveSourceBranch ([bool]$RemoveSourceBranch)
        if ($pipelineMergeResult.requested) {
            $resultMr = $pipelineMergeResult.merge_request
        }
    }

    [pscustomobject]@{
        ok                    = $true
        created               = $false
        reason                = "opened merge request already exists for source/target"
        iid                   = $resultMr.iid
        title                 = $resultMr.title
        state                 = $resultMr.state
        source_branch         = $resultMr.source_branch
        target_branch         = $resultMr.target_branch
        web_url               = $resultMr.web_url
        squash                = $resultMr.squash
        merge_when_pipeline_succeeds_requested = if ($null -ne $pipelineMergeResult) { $pipelineMergeResult.requested } else { $false }
        merge_when_pipeline_succeeds_method = if ($null -ne $pipelineMergeResult) { $pipelineMergeResult.method } else { $null }
        merge_when_pipeline_succeeds_error = if ($null -ne $pipelineMergeResult -and -not $pipelineMergeResult.requested) { $pipelineMergeResult.error } else { $null }
        merge_when_pipeline_succeeds_status = if ($null -ne $pipelineMergeResult -and -not $pipelineMergeResult.requested) { $pipelineMergeResult.status } else { $null }
        merge_when_pipeline_succeeds = $resultMr.merge_when_pipeline_succeeds
        detailed_merge_status = $resultMr.detailed_merge_status
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
$pipelineMergeResult = $null
$resultMr = $createdMr

if ($shouldMergeWhenPipelineSucceeds) {
    $pipelineMergeResult = Request-MergeWhenPipelineSucceeds -MergeRequest $createdMr -ShouldSquash $shouldSquash -ShouldRemoveSourceBranch ([bool]$RemoveSourceBranch)
    if ($pipelineMergeResult.requested) {
        $resultMr = $pipelineMergeResult.merge_request
    }
}

[pscustomobject]@{
    ok                    = $true
    created               = $true
    iid                   = $resultMr.iid
    title                 = $resultMr.title
    state                 = $resultMr.state
    source_branch         = $resultMr.source_branch
    target_branch         = $resultMr.target_branch
    web_url               = $resultMr.web_url
    has_conflicts         = $resultMr.has_conflicts
    squash                = $resultMr.squash
    merge_when_pipeline_succeeds_requested = if ($null -ne $pipelineMergeResult) { $pipelineMergeResult.requested } else { $false }
    merge_when_pipeline_succeeds_method = if ($null -ne $pipelineMergeResult) { $pipelineMergeResult.method } else { $null }
    merge_when_pipeline_succeeds_error = if ($null -ne $pipelineMergeResult -and -not $pipelineMergeResult.requested) { $pipelineMergeResult.error } else { $null }
    merge_when_pipeline_succeeds_status = if ($null -ne $pipelineMergeResult -and -not $pipelineMergeResult.requested) { $pipelineMergeResult.status } else { $null }
    merge_when_pipeline_succeeds = $resultMr.merge_when_pipeline_succeeds
    detailed_merge_status = $resultMr.detailed_merge_status
    api_user              = $user.username
} | ConvertTo-GitLabJson
