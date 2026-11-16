# Lock-on targeting

Lock the camera onto a target, as in third-person action games. Three pieces:

- `LockOnTarget`: a marker on anything that can be locked onto.
- `LockOn`: a node on the player. On the `lock_on` action it picks the target nearest the centre of the view, keeps the orbit camera turned toward it, switches between targets, and lets go when the target is lost.
- `LockOnIndicator`: a UI marker drawn over the locked target.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) and the `orbit_camera` recipe into your project.
2. Add a `lock_on` input action (Tab and right stick click in the cookbook project).
3. Add a `Node` with `lock_on.gd` as a child of your player and set its `orbit_camera`.
4. Add a `Node3D` with `lock_on_target.gd` as a child of each enemy, placed where the camera should aim.
5. Instance `lock_on_indicator.tscn` in your UI and set its `lock_on`.
6. Make the character face the target while locked. With `third_person_movement` that is:

```gdscript
func _ready() -> void:
	$LockOn.locked.connect(func(_target: LockOnTarget) -> void: strafe = true)
	$LockOn.unlocked.connect(func() -> void: strafe = false)
```

## Requirements

| Kind | Needed |
|---|---|
| Recipes | `orbit_camera` |
| Input actions | `lock_on`. `look_left` and `look_right` switch targets while locked. |
| Physics layers | The line-of-sight check looks at layer 1 (`line_of_sight_mask`). |

## Settings

| Member | On | Purpose |
|---|---|---|
| `origin` | `LockOn` | Where the player is. Defaults to the parent. |
| `orbit_camera` | `LockOn` | The camera to turn. Without it the lock is tracked and signalled only. |
| `lock_action`, `switch_left_action`, `switch_right_action` | `LockOn` | Input actions. |
| `max_distance`, `max_angle_degrees`, `requires_line_of_sight`, `line_of_sight_mask` | `LockOn` | Which targets can be picked. |
| `break_distance` | `LockOn` | The lock is dropped beyond this distance. |
| `camera_turn_speed` | `LockOn` | How quickly the camera turns toward the target. |
| `target`, `is_locked()`, `toggle()`, `lock(target)`, `unlock()`, `switch_target(direction)`, `find_best_target()` | `LockOn` | State and control from code. |
| `locked(target)`, `unlocked` | `LockOn` | Signals. |
| `enabled` | `LockOnTarget` | Turn off when the enemy dies. |
| `lock_on` | `LockOnIndicator` | The lock-on to follow. |

The lock is also dropped when the target is disabled or freed.

## How it works

While locked, the camera's yaw is steered toward the direction from the player to the target, so the target stays ahead and the player stays in frame. Pitch is left to the player. `LockOn` runs after the camera each frame, so it overrides sideways look input but not zoom.

## Where to take it next

- The camera only turns; it does not pull back or raise to frame both characters. Adjust the camera's `distance` and pitch from `locked` and `unlocked`.
- Losing sight of a locked target does not break the lock; only distance does. Add a timer in `_process()` using `_has_line_of_sight()`.
- Switching uses the look actions' press, so a mouse movement does not switch. Add an action or read mouse motion.
- When the locked target dies, the lock is dropped. Many games jump to the next nearest target instead: call `lock(find_best_target())` from `unlocked`.
- The indicator is a text label. Replace `Marker` with a texture.
