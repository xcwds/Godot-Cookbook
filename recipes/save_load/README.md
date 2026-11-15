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

var error := await SaveGame.load_game(get_tree())
```

`load_game` must be awaited: if the save was made in another scene, it switches to that scene before restoring.

The dictionary can hold numbers, strings, booleans, arrays, dictionaries and engine types such as `Vector3`, `Transform3D` and `Color`. It cannot hold nodes or resources; save a name or a path instead.

## Requirements

None. See `recipe.cfg`.

## Settings

| Member | Purpose |
|---|---|
| `save_game(tree, slot)` | Writes every saveable node in the current scene. Returns an `Error`. |
| `load_game(tree, slot)` | Restores a slot, changing scene first if needed. Returns an `Error`. |
| `has_save(slot)`, `delete_save(slot)` | Slot management. |
| `get_save_info(slot)` | The scene and time of a save without loading it, for a load menu. |
| `SaveGame.VERSION` | Save format version. A save from a newer version is refused. |
| `SaveGame.SAVE_DIR` | Where saves go. |

The slot is any name; it defaults to `slot_1`.

## How it works

Each node's data is stored under its path relative to the scene root, so a node must keep its name and place in the tree between saving and loading. Loading does not rebuild the scene: it hands each node that still exists its saved data.

Saves are plain JSON and are parsed as data only, so a save file from someone else cannot run code. They are written to a temporary file and then renamed, so a crash mid-save leaves the previous save intact.

## Where to take it next

- Nodes created or freed at runtime are not handled. Hide and disable instead of freeing (as the demo's pickups do), or save a list and respawn from it in a manager's `load_data()`.
- State outside the current scene (inventory in an autoload, settings, unlocked levels) is not covered. Add those nodes to the group only if they are inside the scene, or save them next to `nodes` in `save_game()`.
- No migration: when you bump `VERSION`, convert older saves in `_read()`.
- No autosave, no thumbnails, no list of slots. `get_save_info()` and `DirAccess.get_files_at(SaveGame.SAVE_DIR)` are the starting points.
- Loading is abrupt. Wrap it in a fade with the `scene_transition` recipe.
- Saves are readable and editable by the player. That is usually fine for single-player games.
