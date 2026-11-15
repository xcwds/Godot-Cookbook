#!/usr/bin/env bash
# Checks the cookbook project.
#
#   tools/check.sh            repo + import + smoke + test + cli + lint (the default)
#   tools/check.sh repo       Godot version is consistent, every asset is in CREDITS.md
#   tools/check.sh import     import assets and parse all scripts
#   tools/check.sh smoke      run the main scene and every recipes/*/demo.tscn headless for a few frames
#   tools/check.sh test       run tests/test_*.gd headless
#   tools/check.sh cli        add each recipe to an empty project with tools/cookbook and load it
#   tools/check.sh lint       gdlint + gdformat --check
#
# GODOT overrides the Godot binary (default: godot).
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SMOKE_FRAMES=120
SCRIPT_DIRS=(recipes browser shared tests tools/load_all.gd)
ASSET_EXTENSIONS="fbx|glb|gltf|obj|blend|dae|png|jpg|jpeg|webp|svg|exr|hdr|ogg|wav|mp3|ttf|otf|woff2"

# Godot often exits 0 despite script or resource errors, so the log is checked as well.
run_godot() {
	local log status=0
	log="$(mktemp)"
	"$GODOT" --headless --path "${PROJECT:-.}" "$@" >"$log" 2>&1 || status=$?
	if [ "$status" -ne 0 ] || grep -qE '^(SCRIPT )?ERROR:' "$log"; then
		cat "$log"
		rm -f "$log"
		return 1
	fi
	rm -f "$log"
}

# Checks that need no Godot binary.
do_repo() {
	echo "== repo"
	local version minor failed=0 asset
	version="$(tr -d '[:space:]' <.godot-version)"
	minor="$(echo "$version" | cut -d. -f1,2)"
	if ! grep -q "^config/features=.*\"$minor\"" project.godot; then
		echo "project.godot config/features does not name Godot $minor (.godot-version is $version)" >&2
		failed=1
	fi

	# Every asset must match a backticked path in a CREDITS.md table ("*" is a wildcard).
	local -a credited
	mapfile -t credited < <(grep '^|' CREDITS.md | grep -o '`[^`]*`' | tr -d '`')
	while IFS= read -r asset; do
		local found=0 pattern
		for pattern in "${credited[@]}"; do
			# shellcheck disable=SC2053
			if [[ "$asset" == $pattern ]]; then
				found=1
				break
			fi
		done
		if [ "$found" -eq 0 ]; then
			echo "asset not listed in CREDITS.md: $asset" >&2
			failed=1
		fi
	done < <(git ls-files | grep -iE "\.($ASSET_EXTENSIONS)$")
	return "$failed"
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

# Tests print expected engine errors, so a test fails on its exit code or on
# a script error, which would otherwise end a test function silently.
do_test() {
	local test log status
	local -a extra
	log="$(mktemp)"
	for test in tests/test_*.gd; do
		echo "== test: $test"
		status=0
		# A test can ask for extra Godot arguments with a line such as
		# "## godot-args: --fixed-fps 120".
		read -r -a extra < <(sed -n 's/^## godot-args: //p' "$test" | head -1) || true
		"$GODOT" --headless --path . "${extra[@]}" -s "$test" >"$log" 2>&1 || status=$?
		if [ "$status" -ne 0 ] || grep -q '^SCRIPT ERROR' "$log"; then
			cat "$log"
			rm -f "$log"
			return 1
		fi
	done
	rm -f "$log"
}

# Copies each recipe, alone, into an empty project. A recipe that needs
# something it does not declare fails to import or load there.
do_cli() {
	local work recipe project
	work="$(mktemp -d)"
	for recipe in $(tools/cookbook list | cut -d' ' -f1) all; do
		echo "== cli: $recipe"
		project="$work/$recipe"
		mkdir -p "$project"
		printf 'config_version=5\n\n[application]\n\nconfig/name="Empty"\n' >"$project/project.godot"
		if [ "$recipe" = all ]; then
			# shellcheck disable=SC2046
			tools/cookbook add $(tools/cookbook list | cut -d' ' -f1) --to "$project" >/dev/null
			# Adding again must change nothing.
			cp "$project/project.godot" "$work/before.godot"
			# shellcheck disable=SC2046
			tools/cookbook add $(tools/cookbook list | cut -d' ' -f1) --to "$project" >/dev/null
			cmp -s "$project/project.godot" "$work/before.godot" || {
				echo "adding the recipes twice changed project.godot" >&2
				return 1
			}
		else
			tools/cookbook add "$recipe" --to "$project" >/dev/null
		fi
		if find "$project" -name 'demo*' | grep -q .; then
			echo "demo files were copied for $recipe" >&2
			return 1
		fi
		PROJECT="$project" run_godot --import
		PROJECT="$project" run_godot -s "$PWD/tools/load_all.gd" -- addons/cookbook
	done
	rm -rf "$work"
}

do_lint() {
	echo "== lint"
	gdlint "${SCRIPT_DIRS[@]}"
	gdformat --check "${SCRIPT_DIRS[@]}"
}

case "${1:-default}" in
	repo) do_repo ;;
	import) do_import ;;
	smoke) do_smoke ;;
	cli) do_cli ;;
	lint) do_lint ;;
	test) do_test ;;
	default) do_repo; do_import; do_smoke; do_test; do_cli; do_lint ;;
	*) sed -n '2,12p' "$0" >&2; exit 2 ;;
esac
echo "OK"
