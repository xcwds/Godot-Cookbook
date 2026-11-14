# Recipe contract

A recipe is a folder under `recipes/` that someone can copy into their own project as a starting point. It is not a finished system: it should be small, readable and honest about its shortcuts.

## Rules

1. **Copyable on its own.** A recipe depends only on Godot and on other recipes named in its `recipe.cfg`. Only `demo.tscn` and files named `demo*` may use anything from `shared/`, or from recipes that are not in `depends`.
2. **Relocatable.** `tools/cookbook add` copies a recipe to another path and rewrites `res://recipes/` in scenes and import files. Scripts should not build `res://recipes/...` paths at runtime, and the `.uid` and `.import` files stay next to their sources.
3. **Exports and signals over paths.** Configuration is exported properties; communication with other recipes is signals or exported node references, not `$Hard/Coded/Paths` into another recipe.
4. **A `demo.tscn`** that runs by itself and shows the recipe working. The recipe browser lists every recipe that has one.
5. **A `recipe.cfg`** manifest (see below).
6. **A `README.md`** following [recipe_template.md](recipe_template.md).
7. **Naming and style.** `snake_case` folders, scenes and scripts; code follows the [style guide](style_guide.md).
8. **CC0 assets only**, each listed in `CREDITS.md`. The check fails for an asset file that is not.

## recipe.cfg

```ini
[recipe]

name="Human-readable name"
description="One sentence, shown in the recipe browser."
depends=["other_recipe_folder"]

[requires]

godot="4.7"
input_actions=["jump"]
physics_layers_3d={"player": 2}
```

`input_actions` are actions the recipe reads and the target project must define; `tools/cookbook add` copies their bindings from this project's `project.godot`. `physics_layers_3d` maps a layer name to the layer number the recipe uses. `depends` lists recipe folder names. Keep the values JSON-compatible, as above, so both Godot and the CLI can read them.

## Adding a recipe

1. Create `recipes/<name>/` with the scripts and scenes, `recipe.cfg`, `README.md` and `demo.tscn`.
2. Add any new input actions to `project.godot` and list them in `recipe.cfg`.
3. If the recipe has logic worth pinning down, add a `tests/test_<name>.gd` (see `tests/test_state_machine.gd`).
4. Run `tools/check.sh`. It imports the project, runs the browser and every demo headless, runs the tests, adds each recipe on its own to an empty project to prove it is copyable, and lints.
