#!/bin/sh
set -eu

# Copy hermes-init/ into agent profiles:
#   --seed <profile>:          hooks/, plugins/, SOUL.md, config.yaml into <profile>;
#                              also .env if <profile> is /home/agent/.hermes
#   --only-hooks-and-plugins:  hooks/, plugins/ into every agent profile
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
