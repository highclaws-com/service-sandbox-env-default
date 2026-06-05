import json
import os
import asyncio
from urllib import request

URL = f"{os.environ.get('NOTIFICATION_BASE_URL', 'http://sandbox_event:8000')}/api/v1/event"


def _post_json(url: str, payload: dict) -> None:
    try:
        data = json.dumps(payload, ensure_ascii=False)
        req = request.Request(
            url,
            data=data.encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with request.urlopen(req, timeout=3) as response:
            pass
    except Exception:
        pass


async def _post_thinking_async(session_id: str, thinking_log: list):
    payload = {
        "event_type": "job:thinking",
        "context": {
            "session_id": session_id,
            "thinking_process": thinking_log
        }
    }
    try:
        await asyncio.to_thread(_post_json, URL, payload)
    except Exception:
        pass


def register(ctx):
    ctx.register_hook("post_llm_call", _capture_cron_thinking)


def _capture_cron_thinking(session_id: str, conversation_history: list, **kwargs):
    if not session_id or not session_id.startswith("cron_"):
        return

    if not conversation_history:
        return

    # Fire and forget asynchronously
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(_post_thinking_async(session_id, conversation_history))
    except RuntimeError:
        # No running event loop
        try:
            asyncio.run(_post_thinking_async(session_id, conversation_history))
        except Exception:
            pass
