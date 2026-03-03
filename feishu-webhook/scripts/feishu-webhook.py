import argparse
import json
import urllib.request
import urllib.error


def send_message(webhook_url: str, message: str, msg_type: str = "text") -> dict:
    """发送飞书消息"""
    payload = {
        "type": msg_type,
        "content": {
            "text": message
        } if msg_type == "text" else {"text": message}
    }
    
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={"Content-Type": "application/json; charset=utf-8"}
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            return {"success": True, "data": json.loads(response.read().decode("utf-8"))}
    except urllib.error.HTTPError as e:
        return {"success": False, "error": f"HTTP {e.code}: {e.reason}"}
    except Exception as e:
        return {"success": False, "error": str(e)}


def main():
    parser = argparse.ArgumentParser(description="飞书 Webhook 消息发送工具")
    parser.add_argument("--webhook", "-w", required=True, help="飞书 webhook URL 或 ID")
    parser.add_argument("--message", "-m", required=True, help="消息内容")
    parser.add_argument("--type", "-t", default="text", choices=["text"], help="消息类型")
    
    args = parser.parse_args()
    
    webhook_id = args.webhook
    if not webhook_id.startswith("http"):
        webhook_id = f"https://www.feishu.cn/flow/api/trigger-webhook/{webhook_id}"
    
    result = send_message(webhook_id, args.message, args.type)
    
    if result["success"]:
        print(f"消息发送成功: {result['data']}")
    else:
        print(f"消息发送失败: {result['error']}")


if __name__ == "__main__":
    main()
