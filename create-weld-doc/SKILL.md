---
name: create-weld-doc
description: 在飞书"焊接"云文档文件夹中创建新的云文档，创建完成后总结文档内容。经过用户同意后，通过飞书 webhook 发送通知（含文档链接）。当用户需要新建焊接相关的飞书文档、记录焊接工作、保存焊接报告时使用。
license: Apache-2.0
allowed-tools: mcp__feishu-mcp__create-doc mcp__feishu-mcp__fetch-doc Write Bash
metadata:
  author: weldone-team
  version: "1.0.0"
---

# 创建焊接云文档并通知

## 固定配置

- **焊接文件夹 folder_token**：`BeRAfJiKPlwH9xd1XnXcgFLfnbd`
- **文件夹 URL**：`https://roboticplus.feishu.cn/drive/folder/BeRAfJiKPlwH9xd1XnXcgFLfnbd`

## 工作流程

### 第一步：创建文档

调用 `mcp__feishu-mcp__create-doc`，**必须**传入 `folder_token: "BeRAfJiKPlwH9xd1XnXcgFLfnbd"`：

```json
{
  "title": "<文档标题>",
  "folder_token": "BeRAfJiKPlwH9xd1XnXcgFLfnbd",
  "markdown": "<文档内容>"
}
```

成功后获取返回值中的 `doc_url` 和 `doc_id`。

### 第二步：总结文档内容

根据刚创建的文档内容，生成一段简洁总结（3-5 句话），包含：
- 文档标题
- 主要内容要点
- 文档链接

### 第三步：通过飞书 webhook 发送通知，发送前需要向用户确认

按照 feishu-webhook skill 的方式发送，消息格式示例：

```
【新文档已创建】
📄 {文档标题}
📁 位置：焊接文件夹
🔗 {doc_url}

摘要：{文档内容总结}
```

**发送步骤：**

1. 将消息内容写入临时文件（使用 Write 工具）：
   - 路径：`.claude/tmp/msg.txt`

2. 执行 PowerShell 脚本（使用 Bash 工具）：
   ```bash
   powershell -ExecutionPolicy Bypass -File ".claude/skills/feishu-webhook/scripts/feishu-webhook.ps1" -Webhook "912c3ff9626dc8fd25a16fd9d102f629" -MsgFile ".claude/tmp/msg.txt"
   ```

3. 删除临时文件：
   ```bash
   rm .claude/tmp/msg.txt
   ```
