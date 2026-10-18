#!/bin/sh
set -eu

# Copy hermes-init/ into agent profiles:
#   --seed <profile>:          hooks/, plugins/, SOUL.md, config.yaml into <profile>;
#                              also .env and the bundled cron job if <profile>
#                              is /home/agent/.hermes
#   --only-hooks-and-plugins:  hooks/, plugins/ into every agent profile

# Prompt the default agent's bundled cron job runs each time it fires.
bundled_job_prompt="Decide whether it is worth proactively sending the user a
message right now. Send one only if there is something worth saying;
otherwise stay silent.

Run these checks in order. If any check fails, output [SILENT].

1. Idle check: in the gateway logs, the user's last inbound message must be
   more than 1 hour old. If the user sent a message within the last hour
   (busy, or just finished chatting), output [SILENT].
2. Frequency check: look at today's runs of this job in cron/output. At most
   one proactive message per day; if one was already sent today, output
   [SILENT].
3. Content check: find one thing truly worth interrupting the user for,
   from these five reasons (send only one, the most worthwhile):
   - time_sensitive: something with a deadline is coming up soon
   - changed: something the user cares about has changed
   - requested: something the user asked you to watch has progress to report
   - ready_for_decision: something you prepared is waiting for their decision
   - new_opportunity: a new opportunity
   If none of the five applies, output [SILENT].
   Do not rely only on internal records: when outside information is needed,
   search for it proactively, based on what you know about the user (who
   they are, what you remember, their preferences, what you have discussed).
4. Filter check: if the user already knows about or has handled it, or you
   cannot confirm it from a reliable source, output [SILENT].

Output rules:
- Be brief and clear: state the point and nothing more."

copy_hooks_and_plugins() {
    rm -rf "$1/hooks" "$1/plugins"
    cp -a /home/agent/hermes-init/hooks /home/agent/hermes-init/plugins "$1"
}

if [ "$#" -eq 2 ] && [ "$1" = --seed ]; then
    agent_profile=$2
    copy_hooks_and_plugins "$agent_profile"
    cp /home/agent/hermes-init/SOUL.md "$agent_profile/SOUL.md"
    cp /home/agent/hermes-init/config.yaml "$agent_profile/config.yaml"
    if [ "$agent_profile" = /home/agent/.hermes ]; then
        cp /home/agent/hermes-init/env "$agent_profile/.env"
        runuser -u agent -- env HOME=/home/agent HERMES_HOME="$agent_profile" \
            hermes cron create "0 10,15,20 * * *" --name bundled-job \
            "$bundled_job_prompt" --deliver all --failure-deliver local
    fi
elif [ "$#" -eq 1 ] && [ "$1" = --only-hooks-and-plugins ]; then
    for agent_profile in /home/agent/.hermes /home/agent/.hermes/profiles/*/; do
        [ -d "$agent_profile" ] || continue
        copy_hooks_and_plugins "$agent_profile"
    done
else
    echo "usage: $0 --seed <profile> | --only-hooks-and-plugins" >&2
    exit 1
fi
