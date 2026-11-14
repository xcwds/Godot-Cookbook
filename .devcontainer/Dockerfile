FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Keep in sync with config/features in each project.godot.
ARG GODOT_VERSION=4.7.2-stable
ARG GDTOOLKIT_VERSION=4.*
# Set automatically by BuildKit (amd64 / arm64).
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip pipx libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

# Official Godot editor binary; used with --headless for import, smoke runs and the language server.
RUN case "${TARGETARCH:-amd64}" in \
        amd64) GODOT_ARCH=x86_64 ;; \
        arm64) GODOT_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && GODOT_FILE="Godot_v${GODOT_VERSION}_linux.${GODOT_ARCH}" \
    && curl -fsSL -o /tmp/godot.zip \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_FILE}.zip" \
    && unzip -q /tmp/godot.zip -d /opt/godot \
    && ln -s "/opt/godot/${GODOT_FILE}" /usr/local/bin/godot \
    && rm /tmp/godot.zip \
    && godot --headless --version

# gdlint / gdformat
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install "gdtoolkit==${GDTOOLKIT_VERSION}" \
    && gdlint --version
