#!/bin/sh
set -eu

mkdir -p /worktrees/.supervisor/conf.d /var/log/supervisor
chown -R agent:agent /worktrees
chmod -R u+rwX /worktrees

exec "$@"
