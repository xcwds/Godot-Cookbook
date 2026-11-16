#!/usr/bin/env bash
# Installs the official Godot editor binary for Linux and links it as `godot`.
#
#   tools/install_godot.sh
#
# The version comes from GODOT_VERSION, or else from .godot-version.
# GODOT_INSTALL_DIR (default /opt/godot) is where the binary is unpacked,
# GODOT_BIN_DIR (default /usr/local/bin) is where the `godot` link goes.
#
# The download is checked against the release's SHA512-SUMS.txt. If the
# binary is already in GODOT_INSTALL_DIR (a CI cache), it is only linked.
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

mkdir -p "$install_dir" "$bin_dir"
if [ -x "$install_dir/$file" ]; then
	echo "Godot ${version} (${arch}) is already in $install_dir"
else
	echo "Installing Godot ${version} (${arch})"
	release="https://github.com/godotengine/godot/releases/download/${version}"
	curl -fsSL --retry 3 -o "$tmp/godot.zip" "$url"
	curl -fsSL --retry 3 -o "$tmp/SHA512-SUMS.txt" "$release/SHA512-SUMS.txt"
	expected="$(awk -v name="${file}.zip" '$2 == name { print $1 }' "$tmp/SHA512-SUMS.txt")"
	if [ -z "$expected" ]; then
		echo "SHA512-SUMS.txt for ${version} has no entry for ${file}.zip" >&2
		exit 1
	fi
	actual="$(sha512sum "$tmp/godot.zip" | cut -d' ' -f1)"
	if [ "$actual" != "$expected" ]; then
		echo "Checksum mismatch for ${file}.zip: expected $expected, got $actual" >&2
		exit 1
	fi
	unzip -q -o "$tmp/godot.zip" -d "$install_dir"
fi
ln -sf "$install_dir/$file" "$bin_dir/godot"
"$bin_dir/godot" --headless --version
