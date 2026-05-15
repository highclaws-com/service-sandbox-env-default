#!/bin/sh
set -eu

mkdir -p /home/agent/.supervisor/conf.d /var/log/supervisor
chown -R agent:agent /home/agent/.supervisor
chmod -R u+rwX /worktrees

exec "$@"
