FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG GDTOOLKIT_VERSION=4.*

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip pipx libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

# Official Godot editor binary, used with --headless for import, tests and the language server.
# The version is pinned in .godot-version at the repository root.
COPY .godot-version /tmp/setup/.godot-version
COPY tools/install_godot.sh /tmp/setup/tools/install_godot.sh
RUN /tmp/setup/tools/install_godot.sh && rm -rf /tmp/setup

# gdlint / gdformat
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install "gdtoolkit==${GDTOOLKIT_VERSION}" \
    && gdlint --version
