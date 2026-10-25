FROM node:24.22.1-trixie-slim AS builder

# Install system dependencies: git, curl, ping, and build tools
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    python3 \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
ENV PATH="/root/.cargo/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Install pnpm
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"
RUN npm install -g --no-audit --no-fund pnpm@11.1.3 && SHELL=bash pnpm setup

# Build the agent-browser cli (customized)
WORKDIR /agent-browser
COPY browser-cli .
RUN pnpm install --frozen-lockfile && pnpm build:native

# Build the default sandbox home page
FROM node:24.22.1-trixie-slim AS home-ui-builder
WORKDIR /home-ui-default
COPY home-ui-default/package.json home-ui-default/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY home-ui-default .
RUN npm run build

FROM node:24.22.1-trixie-slim AS node-runtime

FROM python:3.14.9-slim-trixie
COPY --from=node-runtime /usr/local/ /usr/local/

# Install system dependencies and frequent tools available to AI agents.
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    iputils-ping \
    postgresql-client \
    wget \
    sudo \
    ripgrep \
    iproute2 \
    procps \
    supervisor \
    openssh-client \
    openssh-server \
    sshpass \
    && rm -rf /var/lib/apt/lists/*

# The user's `ssh -R` logs in as `tunnel`; "*" = no password, keys still work.
RUN useradd --system --no-create-home --shell /usr/sbin/nologin \
    --password '*' tunnel

# Install cloudflared from Cloudflare's apt repository.
RUN mkdir -p --mode=0755 /usr/share/keyrings && \
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg > /usr/share/keyrings/cloudflare-main.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" > /etc/apt/sources.list.d/cloudflared.list && \
    apt-get update && \
    apt-get install -y cloudflared && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"
RUN npm install -g --no-audit --no-fund pnpm@9.15.9 && rm -rf /root/.npm && SHELL=bash pnpm setup

# Only keep the rust build binary as requested
COPY --from=builder /agent-browser/cli/target/release/agent-browser /usr/local/bin/agent-browser

# Install search-cli
COPY search-cli /opt/search-cli
RUN cd /opt/search-cli/src && npm ci --no-audit --no-fund \
    && rm -rf /root/.npm \
    && chmod +x search-cli.js \
    && ln -s /opt/search-cli/src/search-cli.js /usr/local/bin/search-cli

# Create the agent user so host UID/GID 1000 bind mounts resolve to agent.
RUN groupadd --gid 1000 agent && \
    useradd --uid 1000 --gid agent --create-home --shell /bin/bash agent && \
    usermod -aG sudo agent && \
    echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent && \
    chmod 0440 /etc/sudoers.d/agent && \
    mkdir -p /worktrees && \
    chown agent:agent /worktrees
USER agent
WORKDIR /home/agent

# set up Hermes
ENV PATH="/home/agent/.local/bin:${PATH}"
COPY --chown=agent:agent ./hermes/fork /home/agent/hermes
COPY --chown=agent:agent ./hermes/install-stamp.json /home/agent/hermes/install-stamp.json
# Install the exact versions in hermes/uv.lock into /home/agent/hermes/.venv.
# uv, not pip: the lock carries uv overrides (e.g. pillow over
# browser-harness's pin) that pip's resolver would reject.
# python-socks 3.1.1 is for the NaoNao plugin; the lock holds 2.8.2.
RUN cd hermes && \
    pip install --no-cache-dir --break-system-packages uv==0.13.5 && \
    uv sync --frozen --no-dev --no-cache \
        --extra messaging --extra cron --extra pty --extra feishu && \
    uv pip install --no-cache "python-socks==3.1.1"

ENV PATH="/home/agent/hermes/.venv/bin:${PATH}"

COPY --chown=agent:agent ./hermes/hooks /home/agent/hermes-init/hooks
COPY --chown=agent:agent ./hermes/plugins /home/agent/hermes-init/plugins
COPY --chown=agent:agent ./hermes/SOUL.md /home/agent/hermes-init/SOUL.md
COPY --chown=agent:agent ./hermes/env /home/agent/hermes-init/env
COPY --chown=agent:agent ./hermes/config.yaml /home/agent/hermes-init/config.yaml

# set up Supervisor
USER root
COPY supervisor/ /etc/supervisor/
COPY --chown=agent:agent home-ui-demo /home/agent/home-ui-demo
# Copy the whole project, not only the build, so the agent can easily
# customize it with the source code.
COPY --chown=agent:agent --from=home-ui-builder /home-ui-default /home/agent/home-ui-default
COPY --chmod=0755 sandbox-entrypoint.sh /usr/local/bin/sandbox-entrypoint.sh
COPY --chmod=0755 copy-hermes-init.sh /usr/local/bin/copy-hermes-init.sh
RUN mkdir -p /var/log/supervisor /home/agent/.supervisor/conf.d && \
    chown -R agent:agent /home/agent/.supervisor

WORKDIR /worktrees
ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint.sh"]
