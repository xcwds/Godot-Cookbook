# Checkpoint and respawn

Two pieces:

- `Checkpoint`: an `Area3D` with a spawn point. When the character walks in, it becomes that character's checkpoint and its pad changes colour.
- `Respawner`: a node on the character that remembers the last checkpoint and puts the character back there. Before any checkpoint is reached it uses the character's starting position.

The respawner moves the character when you call `respawn()`, and by itself when the character falls below `fall_limit_y`.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Put your character on physics layer 2 (`player`); checkpoints only notice bodies on that layer.
3. Add a `Node` with `respawner.gd` as a child of the character.
4. Instance `checkpoint.tscn` wherever the player should be able to restart. Move its `SpawnPoint` to where the character's origin should be placed.
5. Call `respawn()` when the character dies. With the `health` recipe that is two lines:

```gdscript
func _ready() -> void:
	$Health.died.connect($Respawner.respawn)
	$Respawner.respawned.connect(func(_spawn: Transform3D) -> void: $Health.reset())
```

## Requirements

| Kind | Needed |
|---|---|
| Physics layers | The character is on layer 2. Checkpoints look only at layer 2. |

## Settings

| Member | On | Purpose |
|---|---|---|
| `body` | `Respawner` | The node to move. Defaults to the parent. |
| `fall_limit_y` | `Respawner` | Respawn when the body falls below this height. |
| `current_checkpoint`, `set_checkpoint(checkpoint)` | `Respawner` | The checkpoint in use, and setting it from code. |
| `respawn()`, `get_spawn_transform()` | `Respawner` | Move the body back, or ask where that would be. |
| `respawned(spawn)`, `checkpoint_changed(checkpoint)` | `Respawner` | Signals. `spawn` includes the direction the spawn point faces. |
| `inactive_color`, `active_color` | `Checkpoint` | Colours of the pad. Delete the `Pad` node to use your own visuals. |
| `is_active`, `activated`, `deactivated` | `Checkpoint` | State and signals, for effects and sounds. |

## Where to take it next

- The respawn is instant. Fade out, wait, then call `respawn()`; the `scene_transition` recipe shows the fade.
- Only position is restored. The character's facing, the camera and the rest of the level (enemies, pickups, doors) are left as they are; use `respawned` to reset them.
- Any checkpoint touched becomes the current one, including earlier ones. Give checkpoints an order if that matters.
- The checkpoint is not saved between sessions. With the `save_load` recipe, save the current checkpoint's name from the respawner and look it up again on load.
