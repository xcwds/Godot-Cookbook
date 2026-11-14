#!/usr/bin/env bash
# Checks the cookbook project.
#
#   tools/check.sh            import + smoke (the default)
#   tools/check.sh import     import assets and parse all scripts
#   tools/check.sh smoke      run the main scene and every recipes/*/demo.tscn headless for a few frames
#   tools/check.sh lint       gdlint + gdformat --check
#   tools/check.sh all        import + smoke + lint
#
# GODOT overrides the Godot binary (default: godot).
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SMOKE_FRAMES=120
SCRIPT_DIRS=(recipes browser)

# Godot often exits 0 despite script or resource errors, so the log is checked as well.
run_godot() {
	local log status=0
	log="$(mktemp)"
	"$GODOT" --headless --path . "$@" >"$log" 2>&1 || status=$?
	if [ "$status" -ne 0 ] || grep -qE '^(SCRIPT )?ERROR:' "$log"; then
		cat "$log"
		rm -f "$log"
		return 1
	fi
	rm -f "$log"
}

do_import() {
	echo "== import"
	run_godot --import
}

do_smoke() {
	echo "== smoke: main scene"
	run_godot --quit-after "$SMOKE_FRAMES"
	local demo missing=0
	for recipe in recipes/*/; do
		demo="${recipe}demo.tscn"
		if [ ! -f "$demo" ]; then
			echo "== missing $demo" >&2
			missing=1
			continue
		fi
		echo "== smoke: $demo"
		run_godot --quit-after "$SMOKE_FRAMES" "res://$demo"
	done
	return "$missing"
}

do_lint() {
	echo "== lint"
	gdlint "${SCRIPT_DIRS[@]}"
	gdformat --check "${SCRIPT_DIRS[@]}"
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
