#!/usr/bin/env python3
"""Tests for tools/cookbook and tools/check_recipes.py.

    python3 tests/test_cookbook_cli.py        (or: tools/check.sh unit)

Needs only Python 3 and no Godot binary. Each test copies the two tools into a
small made-up cookbook in a temporary folder, so the tests control the recipes
and do not depend on the real ones. `tools/check.sh cli` covers the real
recipes, with Godot.
"""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent / "tools"

INPUT_ACTION = '{name}={{\n"deadzone": 0.2,\n"events": [Object(InputEventKey,"keycode":{key})]\n}}\n'

COOKBOOK_PROJECT = (
    "config_version=5\n\n[application]\n\n"
    'config/name="Fixture cookbook"\n'
    'config/features=PackedStringArray("4.7", "Forward Plus")\n\n'
    "[input]\n\n"
    + INPUT_ACTION.format(name="move_left", key=65)
    + INPUT_ACTION.format(name="jump", key=32)
    + INPUT_ACTION.format(name="fire", key=70)
)

COOKBOOK_README = """# Fixture cookbook

| Recipe | What it does |
|---|---|
| [base](recipes/base/) | Base recipe. |
| [mover](recipes/mover/) | Moves. |
"""

BASE_CFG = """[recipe]

name="Base"
description="Something other recipes build on."
depends=[]

[requires]

godot="4.7"
input_actions=[]
physics_layers_3d={"world": 1}
"""

MOVER_CFG = """[recipe]

name="Mover"
description="Moves left and jumps."
depends=["base"]

[requires]

godot="4.7"
input_actions=["move_left", "jump"]
physics_layers_3d={"player": 2}
project_settings={"physics/common/physics_interpolation": true}
"""

MOVER_SCRIPT = """extends Node

const ACTION_JUMP := &"jump"


func _process(_delta: float) -> void:
\tif Input.is_action_pressed(&"move_left") or Input.is_action_just_pressed(ACTION_JUMP):
\t\tpass
"""

BASE_SCRIPT = "class_name Base\nextends Node\n"

EMPTY_PROJECT = 'config_version=5\n\n[application]\n\nconfig/name="Game"\n'


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as file:
        file.write(text)


def read(path):
    with open(path, encoding="utf-8", newline="") as file:
        return file.read()


def snapshot(folder):
    """Every file under a folder with its bytes, to show nothing changed."""
    return {
        str(path.relative_to(folder)): path.read_bytes()
        for path in sorted(folder.rglob("*"))
        if path.is_file()
    }


class FixtureCase(unittest.TestCase):
    """Builds a cookbook with two recipes and an empty target project."""

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="cookbook_test_")).resolve()
        self.addCleanup(shutil.rmtree, self.work, ignore_errors=True)
        self.cookbook = self.work / "cookbook"
        self.target = self.work / "game"
        (self.cookbook / "tools").mkdir(parents=True)
        for tool in ("cookbook", "check_recipes.py"):
            shutil.copy(TOOLS / tool, self.cookbook / "tools" / tool)
        write(self.cookbook / "project.godot", COOKBOOK_PROJECT)
        write(self.cookbook / "README.md", COOKBOOK_README)

        base = self.cookbook / "recipes" / "base"
        write(base / "recipe.cfg", BASE_CFG)
        write(base / "base.gd", BASE_SCRIPT)
        write(
            base / "base.tscn",
            '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://recipes/base/base.gd" id="1"]\n',
        )
        write(base / "README.md", "# Base\n\n## Requirements\n\nThe level is on layer 1.\n")
        write(base / "demo.tscn", "[gd_scene format=3]\n")
        write(base / "demo_helper.gd", "extends Node\n")
        (base / "icon.png").write_bytes(b"\x89PNG\r\n\x1a\n\x00binary")
        write(
            base / "icon.png.import",
            '[remap]\n\npath="res://.godot/imported/icon.ctex"\n\n[deps]\n\n'
            'source_file="res://recipes/base/icon.png"\n'
            'dest_files=["res://.godot/imported/icon.ctex"]\n',
        )

        mover = self.cookbook / "recipes" / "mover"
        write(mover / "recipe.cfg", MOVER_CFG)
        write(mover / "mover.gd", MOVER_SCRIPT)
        write(
            mover / "README.md",
            "# Mover\n\n## Requirements\n\nRecipe `base`. Actions `move_left` and `jump`. "
            "The character is on layer 2.\n\n## Settings\n\nNone, and layer 9 is not a requirement.\n",
        )

        write(self.target / "project.godot", EMPTY_PROJECT)

    def run_tool(self, tool, *arguments):
        return subprocess.run(
            [sys.executable, str(self.cookbook / "tools" / tool), *map(str, arguments)],
            capture_output=True,
            text=True,
            check=False,
        )

    def cli(self, *arguments, expect=0):
        result = self.run_tool("cookbook", *arguments)
        self.assertEqual(result.returncode, expect, result.stdout + result.stderr)
        return result

    def add(self, *arguments, expect=0):
        return self.cli("add", *arguments, "--to", self.target, expect=expect)

    def project(self):
        return read(self.target / "project.godot")


class ListAndInfoTest(FixtureCase):
    def test_list_shows_every_recipe_with_its_description(self):
        lines = self.cli("list").stdout.splitlines()
        self.assertEqual(len(lines), 2)
        self.assertRegex(lines[0], r"^base\s+Something other recipes build on\.$")
        self.assertRegex(lines[1], r"^mover\s+Moves left and jumps\.$")

    def test_info_includes_what_dependencies_need(self):
        output = self.cli("info", "mover").stdout
        self.assertIn("Mover (mover)", output)
        self.assertRegex(output, r"Depends on:\s+base\n")
        self.assertRegex(output, r"Input actions:\s+move_left, jump\n")
        self.assertRegex(output, r"Physics layers:\s+1 \(world\), 2 \(player\)\n")
        self.assertIn("physics/common/physics_interpolation=true", output)

    def test_info_for_an_unknown_recipe_fails(self):
        result = self.cli("info", "nope", expect=1)
        self.assertIn("no recipe named 'nope'", result.stderr)


class AddTest(FixtureCase):
    def test_copies_the_recipe_and_its_dependencies_without_demos(self):
        output = self.add("mover").stdout
        dest = self.target / "addons" / "cookbook"
        self.assertTrue((dest / "mover" / "mover.gd").is_file())
        self.assertTrue((dest / "base" / "base.gd").is_file())
        self.assertEqual(list(self.target.rglob("demo*")), [])
        self.assertIn("copy   base -> addons/cookbook/base", output)
        self.assertIn("copy   mover -> addons/cookbook/mover", output)
        self.assertLess(output.index("copy   base"), output.index("copy   mover"))
        # Only the recipe that was asked for gets a setup note.
        self.assertIn("Setup steps for 'mover': addons/cookbook/mover/README.md", output)
        self.assertNotIn("Setup steps for 'base'", output)

    def test_rewrites_paths_and_leaves_binary_files_alone(self):
        self.add("base")
        dest = self.target / "addons" / "cookbook" / "base"
        self.assertIn('path="res://addons/cookbook/base/base.gd"', read(dest / "base.tscn"))
        self.assertEqual(
            (dest / "icon.png").read_bytes(),
            (self.cookbook / "recipes" / "base" / "icon.png").read_bytes(),
        )
        imported = read(dest / "icon.png.import")
        self.assertIn('source_file="res://addons/cookbook/base/icon.png"', imported)
        # Lines that point into the cookbook's import cache are dropped.
        self.assertNotIn(".godot/imported", imported)

    def test_adds_input_actions_and_layer_names_to_an_empty_project(self):
        output = self.add("mover").stdout
        project = self.project()
        self.assertTrue(project.startswith(EMPTY_PROJECT))
        self.assertIn("\n[input]\n\n", project)
        self.assertIn(INPUT_ACTION.format(name="move_left", key=65), project)
        self.assertIn(INPUT_ACTION.format(name="jump", key=32), project)
        self.assertNotIn("fire=", project)
        self.assertIn('\n[layer_names]\n\n3d_physics/layer_1="world"\n3d_physics/layer_2="player"\n', project)
        self.assertIn("add    input action 'move_left'", output)
        self.assertIn("add    physics layer 2 name 'player'", output)

    def test_keeps_actions_and_layers_the_project_already_has(self):
        own_jump = 'jump={\n"deadzone": 0.5,\n"events": []\n}\n'
        write(
            self.target / "project.godot",
            EMPTY_PROJECT
            + "\n[input]\n\n"
            + own_jump
            + '\n[layer_names]\n\n3d_physics/layer_1="world"\n3d_render/layer_2="fx"\n'
            + '\n[rendering]\n\nquality="high"\n',
        )
        output = self.add("mover").stdout
        project = self.project()
        self.assertIn("keep   input action 'jump' (already defined)", output)
        self.assertIn("add    input action 'move_left'", output)
        self.assertNotIn("physics layer 1", output)
        self.assertIn(own_jump, project)
        for once in ("[input]", "[layer_names]", "jump=", "move_left=", "3d_physics/layer_1="):
            self.assertEqual(project.count("\n" + once), 1, once)
        self.assertIn('3d_physics/layer_2="player"\n', project)
        # Sections the tool does not own are untouched and stay in order.
        self.assertIn('3d_render/layer_2="fx"\n', project)
        self.assertTrue(project.endswith('[rendering]\n\nquality="high"\n'))
        self.assertLess(project.index("move_left="), project.index("[layer_names]"))

    def test_keeps_crlf_line_endings(self):
        write(self.target / "project.godot", EMPTY_PROJECT.replace("\n", "\r\n"))
        self.add("mover")
        project = self.project()
        self.assertIn("move_left=", project)
        self.assertEqual(project.count("\n"), project.count("\r\n"))

    def test_a_layer_with_another_name_is_reported_and_not_renamed(self):
        write(
            self.target / "project.godot",
            EMPTY_PROJECT + '\n[layer_names]\n\n3d_physics/layer_2="monsters"\n',
        )
        output = self.add("mover").stdout
        self.assertIn(
            "Physics layer 2 is already named \"monsters\"; the recipes use it as 'player'.",
            output,
        )
        self.assertIn('3d_physics/layer_2="monsters"\n', self.project())
        self.assertNotIn('"player"', self.project())

    def test_adding_twice_changes_nothing(self):
        self.add("mover")
        before = snapshot(self.target)
        output = self.add("mover").stdout
        self.assertEqual(snapshot(self.target), before)
        self.assertIn("skip   addons/cookbook/mover (already there; --force to overwrite)", output)
        self.assertIn("keep   input action 'jump'", output)

    def test_force_replaces_a_copied_recipe(self):
        self.add("mover")
        copied = self.target / "addons" / "cookbook" / "mover"
        write(copied / "mover.gd", "# edited\n")
        write(copied / "stale.gd", "# left over\n")
        self.add("mover")
        self.assertEqual(read(copied / "mover.gd"), "# edited\n")
        self.add("mover", "--force", "--discard-edits")
        self.assertEqual(read(copied / "mover.gd"), MOVER_SCRIPT)
        self.assertFalse((copied / "stale.gd").exists())

    def test_force_says_what_it_deletes(self):
        self.add("base")
        output = self.add("base", "--force").stdout
        self.assertIn("delete addons/cookbook/base (6 files, to replace it)", output)
        self.assertLess(output.index("delete addons"), output.index("copy   base"))

    def test_force_refuses_to_delete_edits(self):
        self.add("mover")
        copied = self.target / "addons" / "cookbook" / "mover"
        write(copied / "mover.gd", "# edited\n")
        write(copied / "mine.gd", "# added\n")
        (copied / "README.md").unlink()
        before = snapshot(self.target)
        result = self.add("mover", "--force", expect=1)
        self.assertIn("error: addons/cookbook/mover has been edited since it was copied", result.stderr)
        for line in ("changed  mover.gd", "added    mine.gd", "deleted  README.md"):
            self.assertIn(line, result.stderr)
        self.assertIn("--discard-edits", result.stderr)
        # Nothing was replaced, not even the dependency that had no edits.
        self.assertEqual(snapshot(self.target), before)

    def test_files_godot_generates_are_not_edits(self):
        self.add("base")
        copied = self.target / "addons" / "cookbook" / "base"
        write(copied / "icon.png.import", "[remap]\n\npath=\"res://.godot/imported/x.ctex\"\n")
        write(copied / "base.gd.uid", "uid://abc\n")
        self.add("base", "--force")

    def test_force_replaces_a_copy_without_a_stamp(self):
        self.add("base")
        copied = self.target / "addons" / "cookbook" / "base"
        (copied / ".cookbook").unlink()
        write(copied / "base.gd", "# edited, but nothing records it\n")
        self.add("base", "--force")
        self.assertEqual(read(copied / "base.gd"), BASE_SCRIPT)
        self.assertTrue((copied / ".cookbook").is_file())

    def test_dry_run_writes_nothing(self):
        before = snapshot(self.target)
        output = self.add("mover", "--dry-run").stdout
        self.assertEqual(snapshot(self.target), before)
        self.add("mover")
        before = snapshot(self.target)
        self.assertIn("(dry run) delete", self.add("mover", "--dry-run", "--force").stdout)
        self.assertEqual(snapshot(self.target), before)
        self.assertIn("(dry run) copy   mover -> addons/cookbook/mover", output)
        self.assertIn("(dry run) add    input action 'jump'", output)
        self.assertIn("(dry run) add    physics layer 2 name 'player'", output)

    def test_dest_chooses_the_folder(self):
        self.add("base", "--dest", "/game/parts/")
        dest = self.target / "game" / "parts" / "base"
        self.assertIn('path="res://game/parts/base/base.gd"', read(dest / "base.tscn"))
        self.assertFalse((self.target / "addons").exists())

    def test_recommended_settings_are_reported_until_they_are_set(self):
        note = "Recommended project setting: physics/common/physics_interpolation = true"
        self.assertIn(note, self.add("mover").stdout)
        self.assertNotIn("physics_interpolation", self.project())
        write(
            self.target / "project.godot",
            self.project() + "\n[physics]\n\ncommon/physics_interpolation=true\n",
        )
        self.assertNotIn(note, self.add("mover").stdout)
        # A recipe without recommended settings says nothing about them.
        self.assertNotIn("Recommended", self.add("base").stdout)

    def test_an_older_godot_in_the_target_is_reported(self):
        features = 'config/features=PackedStringArray("{}", "Forward Plus")\n'
        write(self.target / "project.godot", EMPTY_PROJECT + features.format("4.6"))
        output = self.add("base").stdout
        self.assertIn("'base' was written for Godot 4.7; this project is on 4.6.", output)
        for same_or_newer in ("4.7", "4.10"):
            write(self.target / "project.godot", EMPTY_PROJECT + features.format(same_or_newer))
            self.assertNotIn("was written for", self.add("base").stdout)

    def test_actions_the_cookbook_cannot_supply_are_left_to_the_user(self):
        cfg = self.cookbook / "recipes" / "mover" / "recipe.cfg"
        write(cfg, read(cfg).replace('"jump"]', '"jump", "warp"]'))
        output = self.add("mover").stdout
        self.assertIn("Define these input actions yourself: warp", output)
        self.assertNotIn("warp", self.project())


class ClassNameClashTest(FixtureCase):
    def setUp(self):
        super().setUp()
        write(self.target / "scripts" / "my_base.gd", "extends Node\nclass_name Base\n")
        self.clash = (
            "Base: scripts/my_base.gd in the project, recipes/base/base.gd in the cookbook"
        )

    def test_a_clash_stops_the_copy_and_names_both_files(self):
        before = snapshot(self.target)
        result = self.add("base", expect=1)
        self.assertIn("error: the project already defines class names", result.stderr)
        self.assertIn(self.clash, result.stderr)
        self.assertIn("--force", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(snapshot(self.target), before)

    def test_a_clash_in_a_dependency_stops_the_copy(self):
        before = snapshot(self.target)
        result = self.add("mover", expect=1)
        self.assertIn(self.clash, result.stderr)
        self.assertEqual(snapshot(self.target), before)

    def test_dry_run_reports_the_clash(self):
        self.assertIn(self.clash, self.add("base", "--dry-run", expect=1).stderr)

    def test_force_copies_and_repeats_the_clash(self):
        output = self.add("base", "--force").stdout
        self.assertTrue((self.target / "addons" / "cookbook" / "base" / "base.gd").is_file())
        self.assertIn("Class name clash, copied because of --force: " + self.clash, output)

    def test_other_class_names_and_commented_lines_do_not_clash(self):
        write(
            self.target / "scripts" / "my_base.gd",
            "# class_name Base\nclass_name BaseCamp\nextends Node\n",
        )
        self.add("base")

    def test_a_recipe_that_is_skipped_is_not_checked(self):
        (self.target / "scripts" / "my_base.gd").unlink()
        self.add("base")
        write(self.target / "scripts" / "my_base.gd", "class_name Base\n")
        self.assertIn("skip   addons/cookbook/base", self.add("base").stdout)

    def test_the_copy_being_replaced_does_not_clash_with_itself(self):
        (self.target / "scripts" / "my_base.gd").unlink()
        self.add("base")
        self.add("base", "--force")

    def test_a_copy_moved_elsewhere_clashes(self):
        (self.target / "scripts" / "my_base.gd").unlink()
        self.add("base")
        shutil.move(self.target / "addons" / "cookbook" / "base", self.target / "game_base")
        result = self.add("base", expect=1)
        self.assertIn("Base: game_base/base.gd in the project", result.stderr)

    def test_info_lists_class_names(self):
        self.assertRegex(self.cli("info", "base").stdout, r"Class names:\s+Base\n")
        self.assertRegex(self.cli("info", "mover").stdout, r"Class names:\s+none\n")


class ProvenanceTest(FixtureCase):
    def stamp(self, name="base"):
        return json.loads(read(self.target / "addons" / "cookbook" / name / ".cookbook"))

    def status(self):
        return self.cli("status", "--to", self.target).stdout

    def git(self, *arguments):
        subprocess.run(
            ["git", "-C", str(self.cookbook), "-c", "user.name=Test", "-c", "user.email=t@example.com",
             "-c", "commit.gpgsign=false", *arguments],
            check=True,
            capture_output=True,
        )

    def test_each_copied_recipe_gets_a_stamp(self):
        self.add("mover")
        for name in ("base", "mover"):
            stamp = self.stamp(name)
            self.assertEqual(stamp["recipe"], name)
            self.assertRegex(stamp["date"], r"^\d{4}-\d{2}-\d{2}$")
            self.assertNotIn(".cookbook", stamp["files"])
        self.assertEqual(sorted(self.stamp("mover")["files"]), ["README.md", "mover.gd", "recipe.cfg"])
        # The fixture cookbook is not a git repository.
        self.assertEqual(self.stamp()["commit"], "unknown")

    @unittest.skipUnless(shutil.which("git"), "needs git")
    def test_the_stamp_records_the_cookbook_commit(self):
        self.git("init", "-q")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "fixture")
        commit = subprocess.run(
            ["git", "-C", str(self.cookbook), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        self.add("mover")
        self.assertEqual(self.stamp("base")["commit"], commit)
        self.assertIn(f"from cookbook commit {commit[:10]}\n", self.status())
        # Uncommitted changes to a recipe are marked, for that recipe only.
        write(self.cookbook / "recipes" / "base" / "base.gd", BASE_SCRIPT + "# wip\n")
        self.add("mover", "--force")
        self.assertEqual(self.stamp("base")["commit"], commit + "-modified")
        self.assertEqual(self.stamp("mover")["commit"], commit)

    def test_status_without_copies(self):
        self.assertIn("No recipes copied by tools/cookbook were found", self.status())

    def test_status_of_fresh_copies(self):
        self.add("mover")
        output = self.status()
        self.assertRegex(output, r"addons/cookbook/base: base, copied \d{4}-\d\d-\d\d from")
        self.assertIn("addons/cookbook/mover: mover, copied", output)
        self.assertEqual(output.count("same as the cookbook's version"), 2)
        self.assertEqual(output.count("not edited here"), 2)

    def test_status_shows_edits_and_ignores_generated_files(self):
        self.add("mover")
        copied = self.target / "addons" / "cookbook"
        write(copied / "mover" / "mover.gd", "# edited\n")
        write(copied / "base" / "base.gd.uid", "uid://abc\n")
        write(copied / "base" / "icon.png.import", "[remap]\n")
        output = self.status()
        base, mover = output.split("addons/cookbook/mover:")
        self.assertIn("not edited here", base)
        self.assertIn("edited here:\n    changed  mover.gd\n", mover)

    def test_status_shows_when_the_cookbook_has_moved_on(self):
        self.add("mover")
        write(self.cookbook / "recipes" / "base" / "base.gd", BASE_SCRIPT + "# fixed a bug\n")
        # A change to a demo is not a change to what was copied.
        write(self.cookbook / "recipes" / "mover" / "demo.tscn", "[gd_scene format=3]\n")
        base, mover = self.status().split("addons/cookbook/mover:")
        self.assertIn("behind: the cookbook's version has changed since", base)
        self.assertIn("same as the cookbook's version", mover)
        self.add("base", "--force")
        self.assertNotIn("behind", self.status())

    def test_status_finds_a_moved_copy_and_survives_a_bad_stamp(self):
        self.add("mover")
        copied = self.target / "addons" / "cookbook"
        shutil.move(copied / "base", self.target / "game_base")
        write(copied / "mover" / ".cookbook", "not json")
        shutil.rmtree(self.cookbook / "recipes" / "base")
        output = self.status()
        self.assertIn("addons/cookbook/mover: its .cookbook file cannot be read", output)
        self.assertIn("game_base: base, copied", output)
        self.assertIn("the cookbook no longer has this recipe", output)

    def test_status_needs_a_project(self):
        result = self.cli("status", "--to", self.work, expect=1)
        self.assertIn("is not a Godot project", result.stderr)


class AddErrorTest(FixtureCase):
    def assert_fails_cleanly(self, result, message):
        self.assertIn("error: " + message, result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_unknown_recipe(self):
        before = snapshot(self.target)
        result = self.add("base", "nope", expect=1)
        self.assert_fails_cleanly(result, "no recipe named 'nope'")
        self.assertEqual(snapshot(self.target), before)

    def test_dependency_cycle(self):
        cfg = self.cookbook / "recipes" / "base" / "recipe.cfg"
        write(cfg, read(cfg).replace("depends=[]", 'depends=["mover"]'))
        before = snapshot(self.target)
        result = self.add("mover", expect=1)
        self.assert_fails_cleanly(result, "dependency cycle: mover -> base -> mover")
        self.assertEqual(snapshot(self.target), before)

    def test_target_without_a_project_file(self):
        empty = self.work / "empty"
        empty.mkdir()
        result = self.cli("add", "base", "--to", empty, expect=1)
        self.assert_fails_cleanly(result, f"{empty} is not a Godot project")
        self.assertEqual(list(empty.iterdir()), [])

    def test_target_is_the_cookbook(self):
        before = snapshot(self.cookbook)
        result = self.cli("add", "base", "--to", self.cookbook, expect=1)
        self.assert_fails_cleanly(result, "the target is the cookbook itself")
        self.assertEqual(snapshot(self.cookbook), before)

    def test_a_recipe_cfg_that_cannot_be_read(self):
        cfg = self.cookbook / "recipes" / "base" / "recipe.cfg"
        write(cfg, read(cfg).replace("depends=[]", "depends=[oops"))
        result = self.add("base", expect=1)
        self.assert_fails_cleanly(result, f"{cfg}: cannot read 'depends=[oops'")


class CheckRecipesTest(FixtureCase):
    """tools/check_recipes.py, which `tools/check.sh repo` runs."""

    def problems(self):
        result = self.run_tool("check_recipes.py")
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(result.returncode, 1 if result.stderr else 0, result.stderr)
        return result.stderr.splitlines()

    def edit(self, relative, old, new):
        path = self.cookbook / relative
        text = read(path)
        self.assertIn(old, text)
        write(path, text.replace(old, new))

    def test_the_fixture_is_consistent(self):
        self.assertEqual(self.problems(), [])
        self.assertFalse((self.cookbook / "tools" / "__pycache__").exists())

    def test_a_recipe_missing_from_the_readme_table(self):
        self.edit("README.md", "| [mover](recipes/mover/) | Moves. |\n", "")
        self.assertEqual(self.problems(), ["README.md: recipes/mover/ is not in the recipe table"])

    def test_a_table_row_without_a_folder(self):
        self.edit("README.md", "| Moves. |\n", "| Moves. |\n| [gone](recipes/gone/) | Gone. |\n")
        self.assertEqual(
            self.problems(), ["README.md: the recipe table lists 'gone', which is not a folder"]
        )

    def test_a_script_reading_an_undeclared_action(self):
        write(
            self.cookbook / "recipes" / "base" / "base.gd",
            'extends Node\n\n\nfunc _process(_delta: float) -> void:\n'
            '\tvar axis := Input.get_axis(\n\t\t&"move_left",\n\t\t"fire"\n\t)\n',
        )
        self.assertEqual(
            self.problems(),
            [
                "recipes/base/base.gd: reads input action 'move_left', "
                "which is not in input_actions in recipes/base/recipe.cfg",
                "recipes/base/base.gd: reads input action 'fire', "
                "which is not in input_actions in recipes/base/recipe.cfg",
            ],
        )

    def test_an_exported_action_and_a_scene_override_count_as_read(self):
        write(self.cookbook / "recipes" / "base" / "base.gd", 'extends Node\n\n@export var use_action := &"jump"\n')
        self.edit("recipes/base/base.tscn", "\n", '\nfire_action = &"fire"\n')
        found = " ".join(self.problems())
        self.assertIn("recipes/base/base.gd: reads input action 'jump'", found)
        self.assertIn("recipes/base/base.tscn: reads input action 'fire'", found)

    def test_demos_and_comments_are_not_checked(self):
        base = self.cookbook / "recipes" / "base"
        write(base / "demo_helper.gd", 'extends Node\n\nconst ACTION := &"fire"\n')
        write(base / "base.gd", 'extends Node\n# Input.is_action_pressed(&"fire") is up to you.\n')
        self.assertEqual(self.problems(), [])

    def test_a_declared_action_missing_from_the_cookbook_project(self):
        self.edit("recipes/mover/recipe.cfg", '"jump"]', '"jump", "warp"]')
        self.edit("recipes/mover/README.md", "and `jump`", ", `jump` and `warp`")
        self.assertEqual(
            self.problems(),
            ["recipes/mover/recipe.cfg: input action 'warp' is not defined in project.godot"],
        )

    def test_a_dependency_that_does_not_exist(self):
        self.edit("recipes/base/recipe.cfg", "depends=[]", 'depends=["ghost"]')
        self.edit("recipes/base/README.md", "The level", "Recipe `ghost`. The level")
        self.assertEqual(
            self.problems(),
            ["recipes/base/recipe.cfg: depends on 'ghost', which is not a recipe"],
        )

    def test_a_readme_that_leaves_out_what_recipe_cfg_requires(self):
        self.edit(
            "recipes/mover/README.md",
            "Recipe `base`. Actions `move_left` and `jump`. The character is on layer 2.",
            "None.",
        )
        self.assertEqual(
            self.problems(),
            [
                "recipes/mover/README.md: Requirements does not name the recipe `base`",
                "recipes/mover/README.md: Requirements does not name the action `move_left`",
                "recipes/mover/README.md: Requirements does not name the action `jump`",
                "recipes/mover/README.md: Requirements does not mention physics layer 2",
            ],
        )

    def test_a_readme_that_requires_more_than_recipe_cfg(self):
        self.edit(
            "recipes/base/README.md",
            "The level is on layer 1.",
            "Needs `mover` and `fire`. The level is on layers 1 and 3.",
        )
        self.assertEqual(
            self.problems(),
            [
                "recipes/base/README.md: Requirements names `fire`, which is not in input_actions",
                "recipes/base/README.md: Requirements names `mover`, which is not in depends",
                "recipes/base/README.md: Requirements mentions physics layer 3, "
                "which is not in physics_layers_3d",
            ],
        )

    def test_a_readme_without_a_requirements_section(self):
        self.edit("recipes/base/README.md", "## Requirements", "## Needs")
        self.assertEqual(
            self.problems(), ["recipes/base/README.md: no '## Requirements' section"]
        )


if __name__ == "__main__":
    unittest.main()
