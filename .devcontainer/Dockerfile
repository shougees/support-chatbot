FROM debian:bookworm

ENV PATH=/home/vscode/.local/share/mise/shims:${PATH}

COPY .devcontainer/mise.toml /tmp/mise.toml

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      autoconf \
      bison \
      build-essential \
      ca-certificates \
      curl \
      git \
      gnupg \
      libffi-dev \
      libgdbm-dev \
      libgmp-dev \
      libncurses-dev \
      libreadline-dev \
      libssl-dev \
      libvips \
      libyaml-dev \
      pkg-config \
      sqlite3 \
      zlib1g-dev && \
    curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh && \
    useradd -m -s /bin/bash -U vscode && \
    mkdir -p /etc/mise && \
    cp /tmp/mise.toml /etc/mise/config.toml && \
    rm -f /tmp/mise.toml && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN printf '%s\n' \
      'export GEM_HOME=/home/vscode/.bundle' \
      'export BUNDLE_PATH=/home/vscode/.bundle' \
      'export PATH=/home/vscode/.bundle/bin:/home/vscode/.local/share/mise/shims:$PATH' \
      > /etc/profile.d/mise.sh

USER vscode
WORKDIR /home/vscode

RUN mkdir -p /home/vscode/.bundle /home/vscode/.codex && \
    MISE_YES=1 mise trust /etc/mise/config.toml && \
    MISE_YES=1 mise install && \
    mise exec -- gem install bundler -v 4.0.13 && \
    mise reshim

ENV GEM_HOME=/home/vscode/.bundle \
    BUNDLE_PATH=/home/vscode/.bundle \
    PATH=/home/vscode/.bundle/bin:/home/vscode/.local/share/mise/shims:${PATH}

WORKDIR /workspaces/support-chatbot
