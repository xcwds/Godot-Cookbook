# Scene transition

Changes scene with a fade to black. The next scene loads in the background while the screen is covered, and a progress bar appears if that takes more than a moment.

## Add it to your project

1. Copy this folder (without the `demo*` files) into your project.
2. Call it from anywhere instead of `get_tree().change_scene_to_file()`:

```gdscript
SceneTransition.change_scene(get_tree(), "res://levels/level_2.tscn")
```

There is nothing to add to a scene and no autoload to register: the call puts the overlay on top of the game and removes it when the new scene is showing.

To wait for it, or to react to a scene that fails to load:

```gdscript
var transition := SceneTransition.change_scene(get_tree(), path)
transition.failed.connect(func() -> void: print("could not load ", path))
await transition.finished
```

It unpauses the tree before switching, so it is safe to call from a pause menu.

## Requirements

None. See `recipe.cfg`.

`scene_transition.gd` finds its own scene through the `SCENE_PATH` constant. `tools/cookbook add` updates it; if you move the folder by hand, update that line.

## Settings

| Member | Purpose |
|---|---|
| `fade_duration` | Seconds for each fade. Set on the root of `scene_transition.tscn`. |
| `show_progress_after` | The progress bar appears only if loading takes longer than this. |
| `change_scene(tree, path, minimum_load_time)` | Starts the transition. `minimum_load_time` keeps the loading screen up for at least that long. A call made during a transition is ignored. |
| `finished`, `failed` | Signals. |

The look is `scene_transition.tscn`: `Cover` is the colour that fades in, `Progress` is the bar.

## Where to take it next

- Only a fade. For wipes or dissolves, put a shader on `Cover` and tween a shader parameter in `_fade()`.
- The loading screen is a bar on black. Add a tip, a spinner or artwork under `Cover`.
- It replaces the whole scene. To keep the player and swap only the level, load the same way but add the result under your own node, without calling `change_scene_to_packed()`.
- Nothing is passed to the new scene. Keep state in an autoload, or set properties on the scene before it is added.
- A scene that fails to load is logged and the game carries on in the old scene; show the player something.
