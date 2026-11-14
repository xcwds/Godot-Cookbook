# Aim camera

An over-the-shoulder camera (`AimCamera`) that takes over from an orbit camera while the aim action is held and hands the view back on release. Both cameras copy each other's direction when they switch, so the view does not jump.

`AimCamera` extends `OrbitCamera`: it is the same rig with a short arm, a shoulder offset and no zoom, plus the switching.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) and the `orbit_camera` recipe into your project.
2. Add the `aim` input action (right mouse button and right trigger in the cookbook project).
3. Instance `aim_camera.tscn` next to your orbit camera. Set `target` to your character and `orbit_camera` to the orbit rig.
4. Set `target_offset` to roughly head height relative to the target's origin.
5. Make the character face the aim direction while aiming:

```gdscript
func _process(_delta: float) -> void:
	if aim_camera.is_aiming():
		model.rotation.y = aim_camera.yaw
```

If you only want a permanent over-the-shoulder view, you do not need this recipe: use `orbit_camera` with a `shoulder_offset` and a short `distance`.

## Requirements

| Kind | Needed |
|---|---|
| Recipes | `orbit_camera` |
| Input actions | `aim`, plus the look actions from `orbit_camera` |
| Physics layers | Same as `orbit_camera`. |

## Settings

Everything from `orbit_camera`, plus:

| Member | Purpose |
|---|---|
| `orbit_camera` | The normal camera to take over from and hand back to. |
| `aim_action` | Input action that is held to aim. |
| `is_aiming()`, `start_aim()`, `end_aim()` | Query and control from code. |
| `aim_started`, `aim_ended` | Signals, for switching animations or showing a crosshair. |

## Where to take it next

- Hold to aim only. A toggle is a small change in `_process`.
- The switch is a cut. Tween FOV or blend between the two camera transforms for a smooth zoom-in.
- No crosshair and nothing to aim at yet; a ray from `get_camera()` through the screen centre is the usual next step.
- No shoulder swap. Flip the sign of `shoulder_offset.x`.
