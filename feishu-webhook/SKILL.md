---
name: feishu-webhook
description: 通过飞书 webhook 发送文本消息。触发场景：(1) 用户要求发送消息到飞书，(2) 二次向用户确认发送内容，然后才能通过 webhook 推送通知，(3) 发送自动化提醒或告警到飞书群聊
---

# 飞书 Webhook 消息发送

**重要：必须使用 PowerShell 脚本发送，禁止使用 curl 或 Python。**
- curl 在 Windows 上无法正确处理中文编码，会导致乱码。
- Python 在本环境不可用（`python`/`python3` 指向 Microsoft Store 占位符，实际未安装）。

## 发送方法

**步骤一：** 将消息内容写入临时文件（使用 Write 工具）：

路径：`.claude/tmp/msg.txt`，内容为要发送的文本。

**步骤二：** 执行 PowerShell 脚本（使用 Bash 工具）：

```bash
powershell -ExecutionPolicy Bypass -File ".claude/skills/feishu-webhook/scripts/feishu-webhook.ps1" -Webhook "912c3ff9626dc8fd25a16fd9d102f629" -MsgFile ".claude/tmp/msg.txt"
```

**步骤三：** 删除临时文件：

```bash
rm .claude/tmp/msg.txt
```

## 编码说明

PowerShell 5.1 默认按系统 ANSI 编码读取 `.ps1` 脚本，若直接在脚本里写中文字符会导致乱码（UTF-8 字节被逐个误解为 Latin-1，如 `双` → `åŒ`）。

解决方案：将中文内容保存为独立 UTF-8 文件，PS 脚本通过 `[System.IO.File]::ReadAllText(path, UTF8)` 显式读取，再逐字符转为 `\uXXXX` Unicode 转义后发送纯 ASCII JSON。
