FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip pipx libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

# Official Godot editor binary, used with --headless for import, tests and the language server.
# The version is pinned in .godot-version at the repository root.
COPY .godot-version /tmp/setup/.godot-version
COPY tools/install_godot.sh /tmp/setup/tools/install_godot.sh
RUN /tmp/setup/tools/install_godot.sh && rm -rf /tmp/setup

# gdlint / gdformat, at the exact version CI uses (.gdtoolkit-version).
COPY .gdtoolkit-version /tmp/setup/.gdtoolkit-version
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin \
        pipx install "gdtoolkit==$(tr -d '[:space:]' < /tmp/setup/.gdtoolkit-version)" \
    && gdlint --version && rm -rf /tmp/setup

# Node.js, which Claude Code runs on. The official build, checked against SHASUMS256.txt.
ARG NODE_VERSION=24.22.3
RUN case "$(uname -m)" in x86_64) arch=x64 ;; aarch64|arm64) arch=arm64 ;; *) exit 1 ;; esac \
    && file="node-v${NODE_VERSION}-linux-${arch}.tar.xz" \
    && cd /tmp \
    && curl -fsSLO --retry 3 "https://nodejs.org/dist/v${NODE_VERSION}/${file}" \
    && curl -fsSLO --retry 3 "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
    && grep " ${file}\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "$file" -C /usr/local --strip-components=1 --exclude='*.md' --exclude=LICENSE \
    && rm -f "$file" SHASUMS256.txt \
    && node --version

# Claude Code. Global npm packages go to a folder the vscode user owns, so
# `claude update` (and its auto-update) work without sudo.
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=/usr/local/share/npm-global/bin:$PATH
RUN mkdir -p /usr/local/share/npm-global && chown vscode:vscode /usr/local/share/npm-global
USER vscode
# --allow-scripts lets its postinstall step put the native binary in place.
RUN npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code \
    && claude --version

# Claude Code keeps its sign-in, settings and history here (CLAUDE_CONFIG_DIR in
# devcontainer.json). A named volume is mounted on it so they survive a rebuild;
# creating the folder in the image first gives the volume the right owner.
RUN mkdir -p /home/vscode/.claude
USER root
