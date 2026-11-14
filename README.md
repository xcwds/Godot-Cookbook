# Godot Cookbook

Starter recipes for 3D game development in Godot 4. Each recipe is a small folder you can copy into your own project: a starting point to build on, not a finished system.

## Recipes

| Recipe | What it is |
|---|---|
| [state_machine](recipes/state_machine/) | Node-based finite state machine. |
| [third_person_movement](recipes/third_person_movement/) | Character that runs, jumps, dashes, wall slides and wall jumps. |
| [orbit_camera](recipes/orbit_camera/) | Third-person camera that follows, orbits, zooms and avoids walls. |
| [aim_camera](recipes/aim_camera/) | Over-the-shoulder camera that takes over while aiming. |
| [health](recipes/health/) | Hit points as a node, with damage, heal and signals. |
| [health_bar](recipes/health_bar/) | 2D bar that follows a health node, and a billboarded 3D version. |
| [pause_menu](recipes/pause_menu/) | Pause, resume, restart and quit. |

## Try them

Open the repository folder in Godot 4.7 (the exact version is in `.godot-version`) and run the project. The recipe browser lists every demo; press F1 inside a demo to return to it.

## Use a recipe

Copy the recipe's folder into your project, along with the recipes it depends on, then follow its README for input actions and scene setup. Leave out `demo*` files.

## Layout

| Path | Contents |
|---|---|
| `recipes/` | One folder per recipe. |
| `shared/` | Demo-only scenes and assets. Recipes do not depend on it. |
| `browser/` | The recipe browser shown when the project runs. |
| `docs/` | [Recipe contract](docs/recipe_contract.md), [README template](docs/recipe_template.md), [style guide](docs/style_guide.md), [upgrading Godot](docs/upgrading.md). |
| `tests/` | Headless test scripts (`tests/test_*.gd`). |
| `tools/` | Checks used locally and in the dev container. |

## Development

Open the repository in the dev container (`.devcontainer/`) to get the pinned Godot version (headless), `gdlint` and `gdformat`. Outside a container, `tools/install_godot.sh` installs the same Godot binary on Linux.

```bash
tools/check.sh        # repo checks, import, run the browser and every demo headless, run tests/, lint
tools/check.sh test   # only the tests; also: repo, import, smoke, lint
```

The same checks run on every pull request. The container is headless: use it to import, lint and test. To play the demos, open the project in the Godot editor on your machine. `docs/vscode_sample_settings.json` has editor settings for working outside the container.

## Assets

Third-party assets are CC0 only and listed in [CREDITS.md](CREDITS.md).
