#!/bin/sh
set -eu

mkdir -p \
    /home/agent/.supervisor/conf.d \
    /var/log/supervisor
chown -R agent:agent /home/agent/.supervisor

# Do not use chown -R on /home/agent/.hermes. Persisted Hermes dirs can grow
# large. Also, Docker creates missing bind-mount source dirs as root:root, so
# fix the mountpoint directories Hermes need write to.
chown agent:agent \
    /home/agent/.hermes/memories \
    /home/agent/.hermes/cron \
    /home/agent/.hermes/skills || true

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

exec "$@"
