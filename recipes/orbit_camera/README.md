# Orbit camera

A third-person camera rig (`OrbitCamera`): it follows a target, orbits it with the mouse, a stick or keys, zooms with the mouse wheel, and uses a spring arm so walls and props do not block the view.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Add the four look actions listed below.
3. Instance `orbit_camera.tscn` in your scene and set `target` to your character. It can be a child of the character or sit anywhere else; it ignores its parent's transform.
4. Set `target_offset` to the point to orbit. The default suits a character whose origin is at its feet.
5. Capture the mouse (`Input.mouse_mode = Input.MOUSE_MODE_CAPTURED`); mouse look only runs while it is captured.
6. Recommended: turn on **Physics Interpolation** in Project Settings (`physics/common/physics_interpolation`, under Advanced Settings). See "Smooth following" below.

For movement relative to the camera, rotate your input by the rig's `yaw`:

```gdscript
var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera.yaw)
```

## Requirements

| Kind | Needed |
|---|---|
| Input actions | `look_left`, `look_right`, `look_up`, `look_down` (stick or keys; the mouse needs none) |
| Physics layers | The spring arm collides with layer 1. A target that is a physics body is excluded automatically. |

## Settings

| Member | Purpose |
|---|---|
| `target`, `target_offset` | What to follow and the point to orbit, relative to the target's origin. |
| `shoulder_offset` | Shifts the camera sideways or up for an over-the-shoulder view. |
| `active` | Whether the rig reads input, follows and owns the view. Switch rigs with `activate()` and `deactivate()`. |
| `mouse_sensitivity`, `stick_speed`, `invert_x`, `invert_y` | Look input. |
| `pitch_min_degrees`, `pitch_max_degrees`, `initial_pitch_degrees` | Vertical limits and starting angle. |
| `follow_speed` | How quickly the rig catches up; `0` follows rigidly. |
| `distance`, `zoom_min`, `zoom_max`, `zoom_step` | Camera distance and mouse wheel zoom; `zoom_step = 0` disables zoom. |
| `yaw`, `pitch`, `set_look(yaw, pitch)` | Current direction in radians, and how to set it. |
| `get_camera()` | The `Camera3D`, for FOV and other camera settings. |

## Smooth following

A character that is a physics body only moves on physics ticks, 60 times a second by default. A camera that moved every frame toward such a target would make it jitter on displays faster than that, so the rig handles the two cases:

- **Physics interpolation on (recommended):** the engine draws the character at in-between positions, and the rig follows where it is drawn, every frame. Movement is as smooth as the display.
- **Physics interpolation off:** the rig follows a physics body on the physics tick instead. There is no jitter, but the camera's position updates at the tick rate. Looking around is still every frame.

A target that is not a physics body is followed every frame. If you move such a target yourself every frame while physics interpolation is on, set its `physics_interpolation_mode` to off.

## Scene layout

`OrbitCamera` (yaw) → `Pitch` → `SpringArm` → `Camera`. The spring arm's collision shape and mask are set on the `SpringArm` node.

## Where to take it next

- The look action names are fixed in `_process`. Export them if your project names them differently.
- No auto-rotate behind the character and no recentre button.
- Mouse wheel is the only zoom input; there is no gamepad zoom.
