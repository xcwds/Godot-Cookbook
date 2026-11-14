#!/usr/bin/env bash
# Checks every Godot project in the repository (any directory with a project.godot).
#
#   tools/check.sh            import + smoke (the default)
#   tools/check.sh import     import assets and parse all scripts
#   tools/check.sh smoke      run each project's main scene (or demo.tscn) headless for a few frames
#   tools/check.sh lint       gdlint + gdformat --check
#   tools/check.sh all        import + smoke + lint
#
# GODOT overrides the Godot binary (default: godot).
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SMOKE_FRAMES=120

mapfile -t projects < <(find . -name project.godot -not -path '*/.godot/*' -printf '%h\n' | sort)
if [ "${#projects[@]}" -eq 0 ]; then
	echo "No Godot projects found." >&2
	exit 1
fi

# Godot often exits 0 despite script or resource errors, so the log is checked as well.
run_godot() {
	local log status=0
	log="$(mktemp)"
	"$GODOT" --headless "$@" >"$log" 2>&1 || status=$?
	if [ "$status" -ne 0 ] || grep -qE '^(SCRIPT )?ERROR:' "$log"; then
		cat "$log"
		rm -f "$log"
		return 1
	fi
	rm -f "$log"
}

do_import() {
	for project in "${projects[@]}"; do
		echo "== import: $project"
		run_godot --path "$project" --import
	done
}

do_smoke() {
	for project in "${projects[@]}"; do
		if grep -q '^run/main_scene=' "$project/project.godot"; then
			echo "== smoke: $project (main scene)"
			run_godot --path "$project" --quit-after "$SMOKE_FRAMES"
		elif [ -f "$project/demo.tscn" ]; then
			echo "== smoke: $project (demo.tscn)"
			run_godot --path "$project" --quit-after "$SMOKE_FRAMES" res://demo.tscn
		else
			echo "== smoke: $project has no main scene or demo.tscn" >&2
			return 1
		fi
	done
}

do_lint() {
	echo "== lint"
	gdlint "${projects[@]}"
	gdformat --check "${projects[@]}"
}

case "${1:-default}" in
	import) do_import ;;
	smoke) do_smoke ;;
	lint) do_lint ;;
	default) do_import; do_smoke ;;
	all) do_import; do_smoke; do_lint ;;
	*) sed -n '2,10p' "$0" >&2; exit 2 ;;
esac
echo "OK"
