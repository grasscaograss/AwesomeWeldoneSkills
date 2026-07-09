---
name: feishu-webhook
description: 通过飞书 webhook 发送文本消息。触发场景：(1) 用户要求发送消息到飞书，(2) 二次向用户确认发送内容，然后才能通过 webhook 推送通知，(3) 发送自动化提醒或告警到飞书群聊
license: Apache-2.0
allowed-tools: Write Bash
compatibility: Requires pwsh 7. Chinese encoding defaults to UTF-8.
metadata:
  author: weldone-team
  version: "1.0.0"
---

# 飞书 Webhook 消息发送

**重要：必须使用 pwsh 7 脚本发送，禁止使用 curl 或 Python。**
- curl 在 Windows 上无法正确处理中文编码，会导致乱码。
- Python 在本环境不可用（`python`/`python3` 指向 Microsoft Store 占位符，实际未安装）。

## 发送方法

**步骤一：** 将消息内容写入临时文件（使用 Write 工具）：

路径：`.claude/tmp/msg.txt`，内容为要发送的文本。

**步骤二：** 执行 pwsh 7 脚本（默认 UTF-8）：

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File ".claude/skills/feishu-webhook/scripts/feishu-webhook.ps1" -Webhook "912c3ff9626dc8fd25a16fd9d102f629" -MsgFile ".claude/tmp/msg.txt"
```

**步骤三：** 删除临时文件：

```bash
rm .claude/tmp/msg.txt
```

## 编码说明

pwsh 7 默认使用 UTF-8。脚本启动时会显式设置输入、输出和 cmdlet 编码默认值，并通过 `[System.IO.File]::ReadAllText(path, UTF8)` 读取消息文件。

消息发送时统一使用 `application/json; charset=utf-8`，避免中文在 webhook 请求或控制台输出中乱码。