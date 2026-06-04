#!/usr/bin/env python3
import json
import os
import sys
from urllib import request


URL = f"{os.environ['NOTIFICATION_BASE_URL']}/api/v1/event"
SILENT = "[SILENT]"

# Hermes writes hook payload JSON to stdin, for example:
# {
#   "hook_event_name": "transform_llm_output",
#   "tool_name": null,
#   "tool_input": null,
#   "session_id": "cron_abc123def456_20260604_031500",
#   "cwd": "/home/agent",
#   "extra": {
#     "response_text": "Something changed, notify the user.",
#     "model": "openai/gpt-5.4-mini"
#   }
# }


def main() -> int:
    data = json.load(sys.stdin)
    session_id = data["session_id"]
    if not session_id.startswith("cron_"):
        return 0

    response = data["extra"]["response_text"]
    if SILENT in response.upper():
        return 0

    job_id = session_id.split("_", 2)[1]
    event = {
        "event_type": "cronjob:news",
        "context": {
            "job_id": job_id,
            "session_id": session_id,
            "response": response,
        },
    }
    body = json.dumps(event, indent=2, ensure_ascii=False)
    print(body, file=sys.stderr, flush=True)

    req = request.Request(
        URL,
        data=body.encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req, timeout=3) as resp:
        print(f"notification response: {resp.status}", file=sys.stderr, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
