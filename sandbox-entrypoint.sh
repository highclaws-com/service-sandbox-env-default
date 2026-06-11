#!/bin/sh
set -eu

mkdir -p /home/agent/.supervisor/conf.d /var/log/supervisor
chown -R agent:agent /home/agent/.supervisor
# `|| true` is required because .hermes contains read-only (:ro) bind mounts (like SOUL.md).
# Without it, chown will exit with an error on those files and crash the container.
chown -R agent:agent /home/agent/.hermes || true

if [ ! -f /home/agent/AGENTS.md ]; then
    echo "Missing required file: /home/agent/AGENTS.md" >&2
    exit 1
fi

chown agent:agent /home/agent/AGENTS.md

for path in /worktrees /worktrees/* /worktrees/.[!.]* /worktrees/..?*; do
    [ -e "$path" ] || continue
    [ -d "$path" ] || continue
    chmod u+rwx "$path" || true
done

exec "$@"
