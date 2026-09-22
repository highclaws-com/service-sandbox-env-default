from gateway.config import Platform


def register(ctx):
    ctx.register_hook("pre_gateway_dispatch", _skip_authorized_discord_dm)


def _skip_authorized_discord_dm(event, gateway, **kwargs):
    source = event.source
    if (
        source.platform == Platform.DISCORD
        and source.chat_type == "dm"
        and gateway._is_user_authorized_for_source(source)
    ):
        return {"action": "skip"}
    else:
        return None
