#!/usr/bin/env bash
# Prints the newest stable Godot release tag that is newer than the given one,
# or nothing when there is none.
#
#   tools/newer_stable.sh 4.7.2-stable < tags.txt
#
# Reads release tags from standard input, one per line. Only tags of the form
# 4.8-stable or 4.8.1-stable count, so betas, release candidates and anything
# else are ignored. Versions are compared as numbers: a patch release of an
# older minor version (4.6.9 when the pin is 4.7.2) is not newer.
set -euo pipefail

if [ $# -ne 1 ]; then
	sed -n '2,10p' "$0" >&2
	exit 2
fi
pinned="${1%-stable}"

newest="$(grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?-stable$' | sed 's/-stable$//' | sort -V | tail -1 || true)"
if [ -z "$newest" ] || [ "$newest" = "$pinned" ]; then
	exit 0
fi
# The newest is newer than the pin only if it sorts after it.
if [ "$(printf '%s\n%s\n' "$pinned" "$newest" | sort -V | tail -1)" = "$newest" ]; then
	echo "$newest-stable"
fi
