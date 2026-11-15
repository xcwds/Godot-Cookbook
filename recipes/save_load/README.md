# Save and load

Saves the state of the current scene to one JSON file per slot under `user://saves/`, and restores it. Nodes opt in by joining a group and providing two methods; `SaveGame` does the rest.

## Add it to your project

1. Copy this folder (without the `demo*` files) into your project.
2. For anything that should remember where it is, add a `Node` with `save_transform.gd` as its child.
3. For anything with its own state, add it to the `saveable` group and give it two methods:

```gdscript
func _ready() -> void:
	add_to_group(SaveGame.GROUP)


func save_data() -> Dictionary:
	return {"is_open": is_open, "coins": coins}


func load_data(data: Dictionary) -> void:
	is_open = data["is_open"]
	coins = data["coins"]
```

4. Save and load from wherever suits your game:

```gdscript
SaveGame.save_game(get_tree())

if SaveGame.load_game(get_tree()) != OK:
	print("Nothing to load.")
```

`load_game` replaces the current scene at the end of the frame, so code that runs after it in the old scene never learns how the load went. To react once the saved state is in place, connect to `SaveGame.events.loaded` from the new scene's `_ready()` or from an autoload:

```gdscript
func _ready() -> void:
	SaveGame.events.loaded.connect(func(slot: String) -> void: print("Loaded ", slot))
```

5. Free what is gone, or hide it: either works. A saveable node that is not in the save is removed on load. If your node is a part of something else, such as `SaveTransform` or `Health`, give it a `load_missing()` that frees what it belongs to.

The dictionary can hold numbers, strings, booleans, arrays, dictionaries and engine types such as `Vector3`, `Transform3D` and `Color`. It cannot hold nodes or resources; save a name or a path instead.

## Requirements

None. See `recipe.cfg`.

## Settings

| Member | Purpose |
|---|---|
| `save_game(tree, slot)` | Writes every saveable node in the current scene. Returns an `Error`. |
| `load_game(tree, slot)` | Reloads the saved scene and applies the slot to it. Returns an `Error` straight away; the scene changes at the end of the frame. |
| `SaveGame.events.loaded(slot)` | Signal emitted once a load is applied. |
| `has_save(slot)`, `delete_save(slot)` | Slot management. |
| `get_save_info(slot)` | The scene and time of a save without loading it, for a load menu. |
| `SaveGame.VERSION` | Save format version. A save from a newer version is refused. |
| `SaveGame.SAVE_DIR` | Where saves go. |

The slot is any name; it defaults to `slot_1`.

## How it works

Each node's data is stored under its path relative to the scene root, so a node must keep its name and place in the tree between saving and loading.

Loading always reloads the saved scene, even when it is the one already open, and then hands each saveable node its saved data. Anything that is not saved is therefore as the scene starts, never what the session left behind. The data is applied when the new scene's `ready` signal fires, before its first physics tick, so a checkpoint or pickup at the level's start position cannot fire before the player is moved to the saved place. `SaveTransform` also hands a moved `CharacterBody3D` or `AnimatableBody3D` straight to the physics server, which otherwise applies a kinematic body's new place only during its next step. If you move a body in your own `load_data()`, give it a `SaveTransform` instead, or areas will see it at its start position for one tick. This was checked with Godot Physics; Jolt was not tested.

A saveable node that has no entry in the save was gone when the game was saved, so it is removed: `load_missing()` is called if the node has one, and otherwise the node is freed. This is how a collected `Pickup` stays collected. Only a save of the current `VERSION` removes nodes, because a game update that adds saveable nodes to a level would otherwise delete them when an older save is loaded. Bump `VERSION` when you add saveable nodes to a scene that has shipped.

Because the scene is reloaded, every `_ready()` runs again: music restarts and anything built at startup, such as a baked navigation mesh, is built again, which can cause a visible hitch. Wrap loads in a fade with the `scene_transition` recipe. State outside the scene (autoloads, nodes parented to the root, static variables) is not reset.

These cookbook recipes are saveable without depending on this one: `Inventory`, `Pickup`, `Health`, `Respawner` (its checkpoint), `FirstPersonCharacter` (where it looks) and `ThirdPersonCharacter` (which way the model faces). `MovingPlatform` and `ChaseEnemy` are not: they start over on load.

Saves are plain JSON and are parsed as data only, so a save file from someone else cannot run code. They are written to a temporary file and then renamed, so a crash mid-save leaves the previous save intact.

## Where to take it next

- Nodes created at runtime are not restored. Save a list and respawn from it in a manager's `load_data()`.
- State outside the current scene (inventory in an autoload, settings, unlocked levels) is not covered. Add those nodes to the group only if they are inside the scene, or save them next to `nodes` in `save_game()`.
- No migration: when you bump `VERSION`, convert older saves in `_read()`.
- No autosave, no thumbnails, no list of slots. `get_save_info()` and `DirAccess.get_files_at(SaveGame.SAVE_DIR)` are the starting points.
- Saves are readable and editable by the player. That is usually fine for single-player games.
