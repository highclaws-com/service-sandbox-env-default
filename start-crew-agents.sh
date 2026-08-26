#!/bin/sh

for profile_dir in /home/agent/.hermes/profiles/*; do
    [ -f "$profile_dir/SOUL.md" ] || continue
    hermes -p "$(basename "$profile_dir")" gateway run &
done

wait
