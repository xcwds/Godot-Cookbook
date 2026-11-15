# Godot Cookbook

Starter recipes for 3D game development in Godot 4. Each recipe is a small folder you can copy into your own project: a starting point to build on, not a finished system.

## Recipes

| Recipe | What it is |
|---|---|
| [state_machine](recipes/state_machine/) | Node-based finite state machine. |
| [third_person_movement](recipes/third_person_movement/) | Character that runs, jumps, dashes, wall slides and wall jumps. |
| [first_person_movement](recipes/first_person_movement/) | First-person character: look, walk, sprint, crouch and jump. |
| [orbit_camera](recipes/orbit_camera/) | Third-person camera that follows, orbits, zooms and avoids walls. |
| [aim_camera](recipes/aim_camera/) | Over-the-shoulder camera that takes over while aiming. |
| [chase_enemy](recipes/chase_enemy/) | Enemy that chases a target along the navigation mesh. |
| [interaction](recipes/interaction/) | Walk up to something, see a prompt, press a button. |
| [health](recipes/health/) | Hit points as a node, with damage, heal and signals. |
| [hitbox](recipes/hitbox/) | Areas that deal damage and areas that take it. |
| [checkpoint](recipes/checkpoint/) | Checkpoints and respawning at the last one reached. |
| [health_bar](recipes/health_bar/) | 2D bar that follows a health node, and a billboarded 3D version. |
| [scene_transition](recipes/scene_transition/) | Fade between scenes with background loading and a progress bar. |
| [settings_menu](recipes/settings_menu/) | Volume, fullscreen, v-sync and key rebinding, saved between sessions. |
| [save_load](recipes/save_load/) | Save the current scene's state to a file and restore it. |
| [pause_menu](recipes/pause_menu/) | Pause, resume, restart and quit. |

## Try them

Open the repository folder in Godot 4.7 (the exact version is in `.godot-version`) and run the project. The recipe browser lists every demo; press F1 inside a demo to return to it.

## Use a recipe

From a clone of this repository:

```bash
tools/cookbook list
```

```bash
tools/cookbook info third_person_movement
```

```bash
tools/cookbook add third_person_movement --to ~/games/my_game
```

`add` copies the recipe and the recipes it depends on into `addons/cookbook/` in your project (change with `--dest`), leaves the demos behind, and adds the input actions and physics layer names they need to your `project.godot` without touching ones you already have. It then lists what is left to do by hand; the recipe's README has the scene setup. `--dry-run` shows what would happen. It needs Python 3.

Copying a recipe folder by hand works too: take the recipes it depends on, skip the `demo*` files, and replace `res://recipes/` in the copied scenes with the new location.

## Layout

| Path | Contents |
|---|---|
| `recipes/` | One folder per recipe. |
| `shared/` | Demo-only scenes and assets. Recipes do not depend on it. |
| `browser/` | The recipe browser shown when the project runs. |
| `docs/` | [Recipe contract](docs/recipe_contract.md), [README template](docs/recipe_template.md), [style guide](docs/style_guide.md), [upgrading Godot](docs/upgrading.md). |
| `tests/` | Headless test scripts (`tests/test_*.gd`). |
| `tools/` | `cookbook` (add recipes to a project), `check.sh`, `install_godot.sh`. |

## Development

Open the repository in the dev container (`.devcontainer/`) to get the pinned Godot version (headless), `gdlint` and `gdformat`. Outside a container, `tools/install_godot.sh` installs the same Godot binary on Linux.

```bash
tools/check.sh        # repo checks, import, demos, tests, recipes in an empty project, lint
tools/check.sh test   # only the tests; also: repo, import, smoke, cli, lint
```

The same checks run on every pull request. The container is headless: use it to import, lint and test. To play the demos, open the project in the Godot editor on your machine. `docs/vscode_sample_settings.json` has editor settings for working outside the container.

## Assets

Third-party assets are CC0 only and listed in [CREDITS.md](CREDITS.md).
