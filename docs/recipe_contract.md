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
8. **Move on the physics tick, teleport explicitly.** The project has physics interpolation on, so anything visible that moves does so in `_physics_process` and is drawn smoothly in between. Code that places a node somewhere new (respawn, load, reuse from a pool) calls `reset_physics_interpolation()` afterwards. Cameras and other nodes that must follow input every frame turn interpolation off for themselves and read `get_global_transform_interpolated()` from what they follow.
9. **CC0 assets only**, each listed in `CREDITS.md`. The check fails for an asset file that is not.

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

An optional `project_settings={"physics/common/physics_interpolation": true}` under `[requires]` names project settings the recipe works best with. `tools/cookbook` reports them and never changes them.

`input_actions` are actions the recipe reads and the target project must define; `tools/cookbook add` copies their bindings from this project's `project.godot`. `physics_layers_3d` maps a layer name to the layer number the recipe uses. `depends` lists recipe folder names. Keep the values JSON-compatible, as above, so both Godot and the CLI can read them.

## Adding a recipe

1. Create `recipes/<name>/` with the scripts and scenes, `recipe.cfg`, `README.md` and `demo.tscn`.
2. Add any new input actions to `project.godot` and list them in `recipe.cfg`.
3. If the recipe has logic worth pinning down, add a `tests/test_<name>.gd` (see `tests/test_state_machine.gd`). A test that needs extra Godot arguments declares them in a `## godot-args: ...` comment line.
4. Run `tools/check.sh`. It imports the project, runs the browser and every demo headless, runs the tests, adds each recipe on its own to an empty project to prove it is copyable, and lints.

## Saveable nodes

A recipe with state worth keeping can take part in saving without depending on the `save_load` recipe. The convention is duck-typed, so it costs nothing in a project without `save_load`:

- Join the group by its literal name in `_ready()`: `add_to_group(&"saveable")`. Do not use `SaveGame.GROUP`, which would add a dependency.
- `func save_data() -> Dictionary` returns the node's state. Values are numbers, strings, booleans, arrays, dictionaries and engine types such as `Vector3`; never nodes or resources, so store a path relative to the node instead.
- `func load_data(data: Dictionary) -> void` restores it. Use `data.get(key, default)`, so that a save from before a key existed still loads.
- Optional `func load_missing() -> void`. Loading reloads the saved scene and removes each saveable node that has no entry in the save, because it was gone when the game was saved. By default the node is freed. A node that is part of something else (`Health`, `Inventory`, a `SaveTransform`) implements `load_missing()` to free what it belongs to.

Data is applied after every node in the reloaded scene is ready and before its first physics tick, so `load_data()` can rely on `_ready()` having run. A node that is moved in `load_data()` calls `reset_physics_interpolation()` (rule 8).
