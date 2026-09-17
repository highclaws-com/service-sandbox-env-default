import asyncio
import json
import os
from urllib import request


URL = f"{os.environ['NOTIFICATION_BASE_URL']}/api/v1/event"


def _post_json(url: str, payload: dict) -> None:
    data = json.dumps(payload, indent=2, ensure_ascii=False)
    print(data, flush=True)
    req = request.Request(
        url,
        data=data.encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req, timeout=3) as response:
        print(f"notification response: {response.status}", flush=True)


async def handle(event_type: str, context: dict):
    from hermes_cli.profiles import get_active_profile_name

    payload = {
        "event_type": event_type, "context": context,
        "profile": get_active_profile_name(),
    }
    try:
        await asyncio.to_thread(_post_json, URL, payload)
    except Exception as exc:
        print(f"[notification] failed to forward event: {exc}", flush=True)
