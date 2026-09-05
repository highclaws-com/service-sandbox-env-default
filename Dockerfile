FROM node:24-trixie-slim AS builder

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
RUN pnpm install && pnpm build:native

FROM node:22-trixie-slim

# Install system dependencies and frequent tools available to AI agents.
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    iputils-ping \
    python3 \
    python3-pip \
    postgresql-client \
    wget \
    sudo \
    ripgrep \
    python3-venv \
    iproute2 \
    procps \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

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
RUN cd /opt/search-cli/src && npm install --no-audit --no-fund \
    && rm -rf /root/.npm \
    && chmod +x search-cli.js \
    && ln -s /opt/search-cli/src/search-cli.js /usr/local/bin/search-cli

# Rename the base node user so host UID/GID 1000 bind mounts resolve to agent.
RUN groupmod -n agent node && \
    usermod -l agent -d /home/agent -m node && \
    usermod -s /bin/bash agent && \
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
RUN cd hermes && \
    pip install --no-cache-dir -e ".[cli,messaging,cron,pty,feishu]" "websockets==15.0.1" --break-system-packages && \
    bash -c "mkdir -p ~/.hermes/{cron,sessions,logs,memories,skills}" && \
    bash -c "cp cli-config.yaml.example ~/.hermes/config.yaml.example" && \
    bash -c "cp .env.example ~/.hermes/.env.example"

COPY --chown=agent:agent ./hermes/env /home/agent/.hermes/.env
COPY --chown=agent:agent ./hermes/config.yaml /home/agent/.hermes/config.yaml
COPY --chown=agent:agent ./hermes/hooks /home/agent/.hermes/hooks
COPY --chown=agent:agent ./hermes/plugins /home/agent/.hermes/plugins

# set up Supervisor
USER root
COPY supervisor/core-supervisord.conf /etc/supervisor/core-supervisord.conf
COPY supervisor/user-supervisord.conf /etc/supervisor/user-supervisord.conf
COPY supervisor/conf.d/hermes.conf /etc/supervisor/conf.d/hermes.conf
COPY supervisor/conf.d/crew-agents.conf /etc/supervisor/conf.d/crew-agents.conf
COPY supervisor/conf.d/start-user-supervisor.conf /etc/supervisor/conf.d/start-user-supervisor.conf
COPY sandbox-entrypoint.sh /usr/local/bin/sandbox-entrypoint.sh
COPY start-crew-agents.sh /usr/local/bin/start-crew-agents.sh
RUN chmod 0755 /usr/local/bin/sandbox-entrypoint.sh /usr/local/bin/start-crew-agents.sh && \
    mkdir -p /var/log/supervisor /home/agent/.supervisor/conf.d && \
    chown -R agent:agent /home/agent/.supervisor

WORKDIR /worktrees
ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint.sh"]
