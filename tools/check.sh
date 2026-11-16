#!/usr/bin/env bash
# Checks the cookbook project.
#
#   tools/check.sh            repo + unit + lint + import + smoke + test + cli (the default)
#   tools/check.sh repo       Godot version is consistent, every asset is in CREDITS.md,
#                             tools/newer_stable.sh compares versions correctly, and the
#                             READMEs, recipe.cfg files and scripts agree (tools/check_recipes.py)
#   tools/check.sh unit       run tests/test_*.py, the tests of the Python tools
#   tools/check.sh import     import assets and parse all scripts
#   tools/check.sh smoke      run the main scene and every recipes/*/demo.tscn headless for a few frames
#   tools/check.sh test       run tests/test_*.gd headless
#   tools/check.sh cli        add each recipe to an empty project with tools/cookbook and load it
#   tools/check.sh lint       gdlint + gdformat --check
#
# GODOT overrides the Godot binary (default: godot). GODOT_TIMEOUT is how many
# seconds one Godot run may take before it counts as hung (default: 180).
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
GODOT_TIMEOUT="${GODOT_TIMEOUT:-180}"
SMOKE_FRAMES=120
SCRIPT_DIRS=(recipes browser shared tests tools/load_all.gd)
ASSET_EXTENSIONS="fbx|glb|gltf|obj|blend|dae|png|jpg|jpeg|webp|svg|exr|hdr|ogg|wav|mp3|ttf|otf|woff2"

# Runs Godot headless, stopping it after GODOT_TIMEOUT seconds so that a test
# whose await never completes fails instead of blocking. Where `timeout` is
# missing (stock macOS), Godot runs without a limit.
godot_headless() {
	if command -v timeout >/dev/null; then
		timeout --kill-after=10 "$GODOT_TIMEOUT" "$GODOT" --headless "$@"
	else
		"$GODOT" --headless "$@"
	fi
}

# Explains a failed Godot run whose exit status says it was stopped.
report_timeout() {
	if [ "$1" -eq 124 ] || [ "$1" -eq 137 ]; then
		echo "Godot did not finish within ${GODOT_TIMEOUT}s and was stopped." >&2
	fi
}

# Godot often exits 0 despite script or resource errors, so the log is checked as well.
run_godot() {
	local log status=0
	log="$(mktemp)"
	godot_headless --path "${PROJECT:-.}" "$@" >"$log" 2>&1 || status=$?
	if [ "$status" -ne 0 ] || grep -qE '^(SCRIPT )?ERROR:' "$log"; then
		report_timeout "$status"
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

	# Recipe scripts must find their own files relative to themselves, so a
	# copied or moved recipe keeps working (rule 2 of docs/recipe_contract.md).
	local script
	while IFS= read -r script; do
		echo "$script contains a res://recipes/ path; resolve it relative to the script" >&2
		failed=1
	done < <(git ls-files 'recipes/*.gd' | grep -v '/demo[^/]*$' | xargs grep -l 'res://recipes/' || true)

	# tools/newer_stable.sh decides whether the weekly workflow proposes an upgrade.
	local pin tags want got
	while IFS='|' read -r pin tags want; do
		got="$(tr ' ' '\n' <<<"$tags" | tools/newer_stable.sh "$pin")"
		if [ "$got" != "$want" ]; then
			echo "newer_stable.sh $pin with [$tags] printed '$got', expected '$want'" >&2
			failed=1
		fi
	done <<'CASES'
4.7.2-stable|4.6.9-stable 4.7.2-stable 4.7-stable|
4.7.2-stable|4.6.9-stable 4.7.3-stable 4.7.2-stable|4.7.3-stable
4.7.2-stable|4.7.10-stable 4.7.9-stable|4.7.10-stable
4.7.2-stable|4.8-stable 4.7.10-stable 4.8.1-rc1 5.0-beta1|4.8-stable
4.7-stable|4.7.1-stable 4.7-stable|4.7.1-stable
4.7.2-stable|latest nightly|
CASES

	# READMEs, recipe.cfg files and the input actions scripts read must agree.
	python3 tools/check_recipes.py || failed=1
	return "$failed"
}

# Tests of the Python tools. They need no Godot binary.
do_unit() {
	local test
	for test in tests/test_*.py; do
		echo "== unit: $test"
		python3 -B "$test"
	done
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
		godot_headless --path . "${extra[@]}" -s "$test" >"$log" 2>&1 || status=$?
		if [ "$status" -ne 0 ] || grep -q '^SCRIPT ERROR' "$log"; then
			cat "$log"
			report_timeout "$status"
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
	do_cli_crlf
	do_cli_moved
}

# A recipe folder moved inside a project after it was added must still work.
# scene_transition finds its scene relative to its script, so it is the case
# that a hard-coded path would break.
do_cli_moved() {
	echo "== cli: scene_transition after moving its folder"
	local work project
	work="$(mktemp -d)"
	project="$work/moved"
	mkdir -p "$project"
	printf 'config_version=5\n\n[application]\n\nconfig/name="Moved"\n' >"$project/project.godot"
	tools/cookbook add scene_transition --to "$project" --dest addons/first >/dev/null
	mkdir -p "$project/game"
	mv "$project/addons/first/scene_transition" "$project/game/transition"
	rm -rf "$project/addons"
	printf '[gd_scene format=3]\n\n[node name="Next" type="Node"]\n' >"$project/next.tscn"
	cat >"$project/check_transition.gd" <<'GD'
extends SceneTree


func _initialize() -> void:
	await process_frame
	var transition: SceneTransition = SceneTransition.change_scene(self, "res://next.tscn")
	if transition == null:
		printerr("ERROR: the moved scene_transition could not create its scene")
		quit(1)
		return
	transition.fade_duration = 0.01
	# A frame limit rather than awaiting finished, so a failure cannot hang.
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.name == &"Next" and not is_instance_valid(transition):
			quit(0)
			return
	printerr("ERROR: the moved scene_transition did not change scene")
	quit(1)
GD
	PROJECT="$project" run_godot --import
	PROJECT="$project" run_godot -s "$project/check_transition.gd"
	rm -rf "$work"
}

# A project.godot with CRLF endings (a Windows checkout) must be parsed like an
# LF one: existing actions are kept, no section is duplicated, it stays CRLF.
do_cli_crlf() {
	echo "== cli: CRLF project.godot"
	local work project file
	work="$(mktemp -d)"
	project="$work/crlf"
	file="$project/project.godot"
	mkdir -p "$project"
	printf 'config_version=5\r\n\r\n[application]\r\n\r\nconfig/name="X"\r\n\r\n[input]\r\n\r\njump={\r\n"deadzone": 0.5,\r\n"events": []\r\n}\r\n' >"$file"
	local fail="" output
	output="$(tools/cookbook add third_person_movement --to "$project")"
	grep -q "keep   input action 'jump'" <<<"$output" ||
		fail="the existing 'jump' action was not recognised"
	[ "$(grep -c '^\[input\]' "$file")" -eq 1 ] || fail="${fail:-[input] was duplicated}"
	[ "$(grep -c '^jump=' "$file")" -eq 1 ] || fail="${fail:-'jump' was defined twice}"
	grep -q '^move_left=' "$file" || fail="${fail:-the missing actions were not added}"
	grep -q '^\[layer_names\]' "$file" || fail="${fail:-[layer_names] was not added}"
	# Every line break must still be CRLF.
	if tr -d '\r' <"$file" | cmp -s - "$file" || grep -q $'[^\r]$' "$file"; then
		fail="${fail:-the file no longer uses CRLF throughout}"
	fi
	cp "$file" "$work/before.godot"
	tools/cookbook add third_person_movement --to "$project" >/dev/null
	cmp -s "$file" "$work/before.godot" || fail="${fail:-adding twice changed project.godot}"
	if [ -n "$fail" ]; then
		echo "$fail" >&2
		cat -A "$file" >&2
		rm -rf "$work"
		return 1
	fi
	rm -rf "$work"
}

do_lint() {
	echo "== lint"
	gdlint "${SCRIPT_DIRS[@]}"
	gdformat --check "${SCRIPT_DIRS[@]}"
}

case "${1:-default}" in
	repo) do_repo ;;
	unit) do_unit ;;
	import) do_import ;;
	smoke) do_smoke ;;
	cli) do_cli ;;
	lint) do_lint ;;
	test) do_test ;;
	# The checks that need no Godot run first, so they fail fast.
	default) do_repo; do_unit; do_lint; do_import; do_smoke; do_test; do_cli ;;
	*) sed -n '2,16p' "$0" >&2; exit 2 ;;
esac
echo "OK"
