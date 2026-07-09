#Requires -Version 7.0

param(
    [Parameter(Mandatory=$true)][string]$Webhook,
    [Parameter(Mandatory=$true)][string]$MsgFile
)

$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# 用显式 UTF-8 读取消息文件，确保中文稳定
$msg = [System.IO.File]::ReadAllText($MsgFile, [System.Text.Encoding]::UTF8)

# 逐字符构建纯 ASCII 的 JSON（非 ASCII 字符转为 \uXXXX 转义）
$sb = [System.Text.StringBuilder]::new()
$null = $sb.Append('{"type":"text","content":{"text":"')
foreach ($c in $msg.ToCharArray()) {
    $code = [int]$c
    if ($code -gt 127) {
        $null = $sb.Append('\u{0:x4}' -f $code)
    } elseif ($c -eq '"') {
        $null = $sb.Append('\"')
    } elseif ($c -eq '\') {
        $null = $sb.Append('\\')
    } elseif ($c -eq "`r") {
        # skip CR
    } elseif ($c -eq "`n") {
        $null = $sb.Append('\n')
    } else {
        $null = $sb.Append($c)
    }
}
$null = $sb.Append('"}}')
$json = $sb.ToString()

# 解析 Webhook：支持完整 URL 或纯 ID
if (-not $Webhook.StartsWith("http")) {
    $Webhook = "https://www.feishu.cn/flow/api/trigger-webhook/$Webhook"
}

$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
$client = [System.Net.WebClient]::new()
$client.Headers.Add("Content-Type", "application/json; charset=utf-8")
$respBytes = $client.UploadData($Webhook, "POST", $bytes)
$result = [System.Text.Encoding]::UTF8.GetString($respBytes)
Write-Output $result
