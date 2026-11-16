#!/usr/bin/env python3
"""Checks that the recipes, their recipe.cfg files and the READMEs agree.

    tools/check_recipes.py [COOKBOOK_ROOT]

Run by `tools/check.sh repo`. Needs only Python 3 and no Godot binary. Checks:

1. The recipe tables in the root README.md list every folder under recipes/
   and nothing else, each under the heading of the category in its recipe.cfg
   and in folder-name order, which is how the recipe browser shows them.
2. Every recipe a recipe.cfg depends on exists.
3. Every input action in a recipe.cfg is defined in the cookbook's
   project.godot, so `tools/cookbook add` can copy it.
4. Every input action a recipe's own scripts and scenes read is declared in
   its recipe.cfg. Demo files are not checked.
5. The "## Requirements" section of each recipe README names the same recipes,
   input actions and physics layer numbers as recipe.cfg.

Prints one line per problem and exits 1 if there are any.
"""

import importlib.machinery
import importlib.util
import re
import sys
from pathlib import Path

# Calls whose string arguments are input action names.
ACTION_CALL = re.compile(
    r"\b(?:is_action\w*|get_vector|get_axis|get_action_\w+|action_press|action_release)\("
)
# An action name given to a constant, variable or scene property whose own
# name contains "action", such as `const ACTION_JUMP := &"jump"`.
ACTION_ASSIGNMENT = re.compile(
    r"\b\w*action\w*\s*(?::\s*\w+\s*)?:?=\s*&?\"(\w+)\"", flags=re.IGNORECASE
)
STRING = re.compile(r"&?\"(\w+)\"")
TABLE_ROW = re.compile(r"^\|\s*\[(\w+)\]\(recipes/(\w+)/?\)")
HEADING = re.compile(r"^#+\s+(.*?)\s*$")
# recipe.cfg categories and their README headings, in display order. The same
# list is in browser/recipe_browser.gd.
CATEGORIES = {
    "movement": "Movement",
    "cameras": "Cameras",
    "combat": "Combat",
    "world": "World",
    "ui": "UI",
    "systems": "Systems",
}
# "layer 2", and lists such as "layers 1, 2 and 5".
LAYER = re.compile(r"\blayers?\s+(\d+(?:(?:\s*,\s*|\s+(?:and|or)\s+)\d+)*)", flags=re.IGNORECASE)


def load_cookbook(root):
    """Imports tools/cookbook (a script without a .py suffix) as a module."""
    path = str(root / "tools" / "cookbook")
    sys.dont_write_bytecode = True  # No tools/__pycache__ for a file without a suffix.
    loader = importlib.machinery.SourceFileLoader("cookbook_cli", path)
    spec = importlib.util.spec_from_loader("cookbook_cli", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def call_arguments(text, start):
    """The text between the bracket at `start - 1` and the one that closes it."""
    depth = 1
    for index in range(start, len(text)):
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                return text[start:index]
    return text[start:]


def without_comments(text):
    return re.sub(r"#.*", "", text)


def actions_read(recipe_dir):
    """Maps each input action the recipe's scripts and scenes name to a file."""
    found = {}
    for path in sorted(recipe_dir.rglob("*")):
        if path.name.startswith("demo") or path.suffix not in {".gd", ".tscn"}:
            continue
        text = path.read_text(encoding="utf-8")
        names = []
        if path.suffix == ".gd":
            text = without_comments(text)
            for call in ACTION_CALL.finditer(text):
                names += STRING.findall(call_arguments(text, call.end()))
        names += ACTION_ASSIGNMENT.findall(text)
        for name in names:
            found.setdefault(name, path)
    return found


def requirements_section(readme_text):
    """The body of the "## Requirements" section, or None if there is none."""
    match = re.search(r"^## Requirements\n(.*?)(?=^## |\Z)", readme_text, flags=re.M | re.S)
    return match.group(1) if match else None


def check(root):
    cookbook = load_cookbook(root)
    recipes_dir = root / "recipes"
    problems = []
    folders = sorted(p.name for p in recipes_dir.iterdir() if p.is_dir())

    # 1. The README table.
    readme = (root / "README.md").read_text(encoding="utf-8")
    listed = []
    listed_under = {}
    heading = ""
    for line in readme.splitlines():
        if HEADING.match(line):
            heading = HEADING.match(line).group(1)
        row = TABLE_ROW.match(line)
        if not row:
            continue
        label, folder = row.groups()
        if listed and listed_under[listed[-1]] == heading and folder < listed[-1]:
            problems.append(
                f"README.md: under '{heading}', '{folder}' comes after '{listed[-1]}'; "
                f"keep each table in folder-name order"
            )
        listed.append(folder)
        listed_under[folder] = heading
        if label != folder:
            problems.append(f"README.md: the row for recipes/{folder}/ is labelled '{label}'")
    for name in folders:
        if name not in listed:
            problems.append(f"README.md: recipes/{name}/ is not in the recipe table")
    for name in listed:
        if name not in folders:
            problems.append(f"README.md: the recipe table lists '{name}', which is not a folder")
    for name in sorted({n for n in listed if listed.count(n) > 1}):
        problems.append(f"README.md: the recipe table lists '{name}' more than once")

    project_text = cookbook.to_lf(cookbook.read_text(root / "project.godot"))
    project_inputs = dict(cookbook.split_sections(project_text)[1]).get("input", "")
    defined_actions = set(cookbook.section_entries(project_inputs))

    for name in folders:
        folder = recipes_dir / name
        cfg = f"recipes/{name}/recipe.cfg"
        if not (folder / "recipe.cfg").is_file():
            problems.append(f"{cfg}: missing")
            continue
        try:
            manifest = cookbook.read_manifest(name)
        except cookbook.CookbookError as error:
            problems.append(str(error))
            continue
        category = manifest.get("category")
        if category not in CATEGORIES:
            problems.append(
                f"{cfg}: category is {category!r}; use one of {', '.join(CATEGORIES)}"
            )
        elif listed_under.get(name, CATEGORIES[category]) != CATEGORIES[category]:
            problems.append(
                f"README.md: recipes/{name}/ is under '{listed_under[name]}', but its "
                f"category is '{category}' ({CATEGORIES[category]})"
            )
        depends = manifest["depends"]
        actions = manifest["input_actions"]
        layers = {int(number) for number in manifest["physics_layers_3d"].values()}

        # 2. Dependencies exist.
        for dependency in depends:
            if dependency not in folders:
                problems.append(f"{cfg}: depends on '{dependency}', which is not a recipe")

        # 3. Declared actions can be copied from the cookbook project.
        for action in actions:
            if action not in defined_actions:
                problems.append(
                    f"{cfg}: input action '{action}' is not defined in project.godot"
                )

        # 4. Actions the recipe reads are declared.
        for action, path in actions_read(folder).items():
            if action not in actions:
                problems.append(
                    f"{path.relative_to(root)}: reads input action '{action}', "
                    f"which is not in input_actions in {cfg}"
                )

        # 5. The README's Requirements section.
        readme_path = folder / "README.md"
        where = f"recipes/{name}/README.md"
        if not readme_path.is_file():
            problems.append(f"{where}: missing")
            continue
        section = requirements_section(readme_path.read_text(encoding="utf-8"))
        if section is None:
            problems.append(f"{where}: no '## Requirements' section")
            continue
        quoted = set(re.findall(r"`(\w+)`", section))
        for dependency in depends:
            if dependency not in quoted:
                problems.append(f"{where}: Requirements does not name the recipe `{dependency}`")
        for action in actions:
            if action not in quoted:
                problems.append(f"{where}: Requirements does not name the action `{action}`")
        for word in sorted(quoted):
            if word in folders and word != name and word not in depends:
                problems.append(f"{where}: Requirements names `{word}`, which is not in depends")
            if word in defined_actions and word not in actions:
                problems.append(
                    f"{where}: Requirements names `{word}`, which is not in input_actions"
                )
        mentioned = {
            int(number) for group in LAYER.findall(section) for number in re.findall(r"\d+", group)
        }
        for number in sorted(layers - mentioned):
            problems.append(f"{where}: Requirements does not mention physics layer {number}")
        for number in sorted(mentioned - layers):
            problems.append(
                f"{where}: Requirements mentions physics layer {number}, "
                f"which is not in physics_layers_3d"
            )
    return problems


def main():
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1].startswith("-")):
        print(__doc__, file=sys.stderr)
        return 2
    root = Path(sys.argv[1] if len(sys.argv) == 2 else Path(__file__).parent.parent).resolve()
    problems = check(root)
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
