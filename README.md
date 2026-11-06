# sandbox-env-default

The image of the `sandbox_env` container, where a sandbox's Hermes agents run.

- `Dockerfile`: what the image installs, and where.
- `sandbox-entrypoint.sh`: what runs at startup, and how each `hermes/` entry
  reaches the sandbox.
- `supervisor/`: the programs the container runs.
- `hermes/AGENTS.md`: the guide the agent reads inside the sandbox.
- `.github/workflows/docker-push-ghcr.yml`: how the image is published.

Build:

```sh
git submodule update --init --recursive
docker build .
```
