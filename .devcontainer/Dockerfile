FROM mcr.microsoft.com/devcontainers/base:bookworm

ENV MISE_DATA_DIR=/home/vscode/.local/share/mise \
    MISE_CONFIG_DIR=/home/vscode/.config/mise \
    MISE_CACHE_DIR=/home/vscode/.cache/mise \
    PATH=/home/vscode/.local/share/mise/shims:/home/vscode/.local/bin:${PATH}

RUN apt-get update -qq && \
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
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

USER vscode

RUN curl https://mise.run | sh && \
    /home/vscode/.local/bin/mise use --global ruby@3.3.8 node@22 && \
    /home/vscode/.local/bin/mise install && \
    /home/vscode/.local/bin/mise exec -- gem install bundler -v 4.0.13
