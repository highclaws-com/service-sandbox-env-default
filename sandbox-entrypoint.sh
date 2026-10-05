#!/bin/sh
set -eu

mkdir -p \
    /home/agent/.hermes/profiles \
    /home/agent/profile-staging \
    /home/agent/.supervisor/conf.d \
    /var/log/supervisor
chown -R agent:agent /home/agent/.supervisor

# A missing marker means this is a fresh provision. Reset profiles before
# gateways start so a local test cannot reuse the previous sandbox's agents.
if [ ! -f /home/agent/.hermes/provision_callback_completed ]; then
    rm -rf /home/agent/.hermes/profiles/*
    : > /home/agent/.hermes/profile.yaml
fi

# Hooks and plugins are sandbox infrastructure, not agent data: replace them
# with the image's copies on every start, e.g. after a restore or image update.
rm -rf /home/agent/.hermes/hooks /home/agent/.hermes/plugins
cp -a /home/agent/hermes-init/hooks /home/agent/hermes-init/plugins /home/agent/.hermes/

# Do not use chown -R on /home/agent/.hermes. Persisted Hermes dirs can grow
# large. Also, Docker creates missing bind-mount source dirs as root:root, so
# fix the mountpoint directories Hermes need write to.
chown agent:agent \
    /home/agent/.hermes \
    /home/agent/.hermes/.env \
    /home/agent/.hermes/config.yaml \
    /home/agent/.hermes/SOUL.md \
    /home/agent/.hermes/profiles \
    /home/agent/profile-staging || true

if [ ! -f /home/agent/AGENTS.md ]; then
    echo "Missing required file: /home/agent/AGENTS.md" >&2
    exit 1
fi

chown agent:agent /home/agent/AGENTS.md

# Do not use chmod -R on /worktrees. User worktrees can contain many files;
# only the root and immediate worktree dirs need write/search permission for
# normal sandbox startup.
for path in /worktrees /worktrees/* /worktrees/.[!.]* /worktrees/..?*; do
    [ -e "$path" ] || continue
    [ -d "$path" ] || continue
    chmod u+rwx "$path" || true
done

# Start the Core Supervisor as PID 1.
exec /usr/bin/supervisord -c /etc/supervisor/core-supervisord.conf
