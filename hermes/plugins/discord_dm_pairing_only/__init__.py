"""Use DMs for pairing. Do not use DMs to talk to the Agent.

An unknown user gets a pairing code. An approved user can use the Agent in a
server channel, but not in a DM. This keeps private DMs from spending model
tokens.
"""

from gateway.config import Platform


def register(ctx):
    # Give dropped DMs a pairing-code path.
    ctx.register_platform_handler("discord", _register_pairing_listener)
    # Stop approved DMs before the Agent runs.
    ctx.register_hook("pre_gateway_dispatch", _skip_authorized_discord_dm)


def _register_pairing_listener(native, adapter):
    """Let an unknown Discord user start pairing.

    Without this listener:
    1. `allow_all_users` is off and user 123 comes here.
    2. User 123 sends the Bot a DM to ask for access.
    3. The Discord adapter drops the DM before Hermes can make a code.
    4. User 123 gets no code and can never pair.

    This listener handles that dropped DM and sends a pairing code.
    """
    import discord

    async def on_message(message):
        if (
            not isinstance(message.channel, discord.DMChannel)
            or message.author == native.user
        ):
            return

        gateway = adapter.gateway_runner
        source = adapter.build_source(
            chat_id=str(message.channel.id),
            chat_type="dm",
            user_id=str(message.author.id),
            user_name=message.author.display_name,
        )

        with gateway._profile_scope_for_source(source):
            # If the adapter already accepts this user, do not send a second reply.
            # Their DM reaches `_skip_authorized_discord_dm`, which blocks the Agent.
            if adapter._is_allowed_user(
                source.user_id, message.author, guild=None, is_dm=True,
            ):
                return

            behavior = gateway._get_unauthorized_dm_behavior(
                Platform.DISCORD, profile=source.profile,
            )
            if behavior == "pair":
                await gateway._hm_offer_pairing_code(source)

    native.add_listener(on_message, "on_message")


def _skip_authorized_discord_dm(event, gateway, **kwargs):
    """Stop an approved DM before the Agent runs."""
    source = event.source
    # If user 123 is approved, skip the DM. They must use a server channel.
    if (
        source.platform == Platform.DISCORD
        and source.chat_type == "dm"
        and gateway._is_user_authorized_for_source(source)
    ):
        return {"action": "skip"}
    else:
        return None
