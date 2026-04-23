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

# Install system dependencies, i.e., frequent tools available to AI agents.
RUN apt-get update && apt-get install -y \
    git \
    curl \
    iputils-ping \
    python3 \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"
RUN npm install -g pnpm && SHELL=bash pnpm setup

# Only keep the rust build binary as requested
COPY --from=builder /agent-browser/cli/target/release/agent-browser /usr/local/bin/agent-browser

# Install search-cli
COPY search-cli /opt/search-cli
RUN cd /opt/search-cli/src && npm install \
    && chmod +x search-cli.js \
    && ln -s /opt/search-cli/src/search-cli.js /usr/local/bin/search-cli

WORKDIR /worktrees
