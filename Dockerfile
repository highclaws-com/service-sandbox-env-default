FROM node:22-trixie-slim AS builder

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
RUN npm install -g pnpm && SHELL=bash pnpm setup

# Clone and build the agent-browser cli with a tab-isolation feature
WORKDIR /agent-browser
COPY browser-cli .
RUN pnpm install && pnpm build:native

FROM node:22-trixie-slim

# Install system dependencies and frequent tools available to AI agents.
RUN apt-get update && apt-get install -y \
    git \
    curl \
    iputils-ping \
    python3 \
    python3-pip \
    postgresql-client \
    wget \
    ripgrep \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"
RUN npm install -g pnpm && rm -rf /root/.npm && SHELL=bash pnpm setup

# Only keep the rust build binary as requested
COPY --from=builder /agent-browser/cli/target/release/agent-browser /usr/local/bin/agent-browser

# Install search-cli
COPY search-cli /opt/search-cli
RUN cd /opt/search-cli/src && npm install \
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

# build Hermes
ARG HERMES_SOURCE
RUN wget -qO hermes.tar.gz "$HERMES_SOURCE" && \
    tar xzf hermes.tar.gz && \
    mv hermes-agent-* hermes && \
    rm hermes.tar.gz

# set up Hermes
ENV PATH="/home/agent/.local/bin:${PATH}"
RUN cd hermes && \
    pip install --no-cache-dir -e ".[cli,messaging,cron,pty]" --break-system-packages && \
    bash -c "mkdir -p ~/.hermes/{cron,sessions,logs,memories,skills}" && \
    bash -c "cp cli-config.yaml.example ~/.hermes/config.yaml.example" && \
    bash -c "cp .env.example ~/.hermes/.env.example"

COPY --chown=agent:agent ./hermes/env /home/agent/.hermes/.env
COPY --chown=agent:agent ./hermes/config.yaml /home/agent/.hermes/config.yaml

WORKDIR /worktrees
CMD ["hermes", "gateway"]
