# Godot Cookbook

Starter recipes for 3D game development in Godot 4. Each recipe is a small folder you can copy into your own project: a starting point to build on, not a finished system.

## Recipes

| Recipe | What it is |
|---|---|
| [state_machine](recipes/state_machine/) | Node-based finite state machine. |
| [third_person_controller](recipes/third_person_controller/) | Character movement with dash and wall jump, orbit camera and aim camera. |
| [health_bar](recipes/health_bar/) | 2D health bar and a billboarded 3D version. |
| [pause_menu](recipes/pause_menu/) | Pause, resume, restart and quit. |

## Try them

Open the repository folder in Godot 4.7 and run the project. The recipe browser lists every demo; press F1 inside a demo to return to it.

## Use a recipe

Copy the recipe's folder into your project, along with the recipes it depends on, then follow its README for input actions and scene setup. Leave out `demo*` files.

## Layout

| Path | Contents |
|---|---|
| `recipes/` | One folder per recipe. |
| `shared/` | Demo-only scenes and assets. Recipes do not depend on it. |
| `browser/` | The recipe browser shown when the project runs. |
| `docs/` | [Recipe contract](docs/recipe_contract.md), [README template](docs/recipe_template.md), [style guide](docs/style_guide.md). |
| `tools/` | Checks used locally and in the dev container. |

## Development

Open the repository in the dev container (`.devcontainer/`) to get Godot 4.7.2 (headless), `gdlint` and `gdformat`.

```bash
tools/check.sh        # import the project, then run the browser and every demo headless
tools/check.sh lint   # gdlint + gdformat --check
```

The container is headless: use it to import, lint and smoke-test. To play the demos, open the project in the Godot editor on your machine. `docs/vscode_sample_settings.json` has editor settings for working outside the container.

## Assets

Third-party assets are CC0 only and listed in [CREDITS.md](CREDITS.md).
