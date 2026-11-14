#!/usr/bin/env bash
# Installs the official Godot editor binary for Linux and links it as `godot`.
#
#   tools/install_godot.sh
#
# The version comes from GODOT_VERSION, or else from .godot-version.
# GODOT_INSTALL_DIR (default /opt/godot) is where the binary is unpacked,
# GODOT_BIN_DIR (default /usr/local/bin) is where the `godot` link goes.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="${GODOT_VERSION:-$(tr -d '[:space:]' <"$root/.godot-version")}"
install_dir="${GODOT_INSTALL_DIR:-/opt/godot}"
bin_dir="${GODOT_BIN_DIR:-/usr/local/bin}"

case "$(uname -m)" in
	x86_64) arch=x86_64 ;;
	aarch64 | arm64) arch=arm64 ;;
	*) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

file="Godot_v${version}_linux.${arch}"
url="https://github.com/godotengine/godot/releases/download/${version}/${file}.zip"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Installing Godot ${version} (${arch})"
curl -fsSL -o "$tmp/godot.zip" "$url"
mkdir -p "$install_dir" "$bin_dir"
unzip -q -o "$tmp/godot.zip" -d "$install_dir"
ln -sf "$install_dir/$file" "$bin_dir/godot"
"$bin_dir/godot" --headless --version
