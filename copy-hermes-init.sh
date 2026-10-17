#!/bin/sh
set -eu

# Copy hermes-init/ into the given agent profiles, or all of them:
#   always:  hooks/, plugins/
#   --seed:  SOUL.md; .env, config.yaml only for /home/agent/.hermes,
#            which is seeded only on a fresh provision
seed=false
if [ "${1:-}" = "--seed" ]; then
    seed=true
    shift
fi
if [ "$#" -eq 0 ]; then
    set -- /home/agent/.hermes /home/agent/.hermes/profiles/*/
fi
for agent_profile in "$@"; do
    [ -d "$agent_profile" ] || continue
    rm -rf "$agent_profile/hooks" "$agent_profile/plugins"
    cp -a /home/agent/hermes-init/hooks /home/agent/hermes-init/plugins "$agent_profile"
    if [ "$seed" = true ]; then
        cp /home/agent/hermes-init/SOUL.md "$agent_profile/SOUL.md"
        if [ "$agent_profile" = /home/agent/.hermes ]; then
            cp /home/agent/hermes-init/env "$agent_profile/.env"
            cp /home/agent/hermes-init/config.yaml "$agent_profile/config.yaml"
        fi
    fi
done
