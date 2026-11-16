# Free camera

A detached camera (`FreeCamera`) that flies anywhere: a photo mode, or a way to look around a level while debugging. It takes the view from whichever camera is current, starts exactly where that camera is, and gives the view back when it is turned off. By default the game is paused while it flies.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Add the input actions listed below.
3. Instance `free_camera.tscn` anywhere in your scene. It does nothing until it is turned on.
4. Press the `free_camera` action, or call `activate()` and `deactivate()` from your own code, for example from a "Photo mode" button.
5. For a camera that leaves the game running, turn `pause_game` off and read "Spectator mode" below.

## Requirements

| Kind | Needed |
|---|---|
| Input actions | `move_left`, `move_right`, `move_up`, `move_down` to fly, `look_left`, `look_right`, `look_up`, `look_down` to look with a stick or keys (the mouse needs none), `camera_up` and `camera_down` to rise and sink, `sprint` to go faster, `free_camera` to turn it on and off |
| Physics layers | None. Set `collision_mask` if the camera should stop at walls. |

The camera works with any `Camera3D`. It does not need the orbit camera or the pause menu, but it is written to get along with both.

## Settings

| Member | Purpose |
|---|---|
| `toggle_action` | Action that turns the camera on and off. Empty leaves it to `activate()` and `deactivate()`. |
| `pause_game` | On: the scene tree is paused while the camera is active (photo mode). Off: the game keeps running (spectator or debug camera). |
| `capture_mouse` | Capture the mouse while active. The mouse mode from before is put back afterwards. |
| `speed`, `speed_min`, `speed_max`, `speed_step` | Flying speed, and how the mouse wheel changes it. `speed_step = 1` turns the wheel off. |
| `fast_multiplier` | Speed multiplier while `sprint` is held. |
| `acceleration` | How quickly the camera reaches its speed and stops; `0` is instant. |
| `mouse_sensitivity`, `stick_speed`, `invert_y` | Look input. |
| `copy_fov` | Start with the field of view of the camera the view was taken from. |
| `collision_mask`, `collision_radius` | Layers the camera cannot fly through, and the size of the sphere that is swept. `0` (the default) lets it go anywhere. |
| `active`, `activate()`, `deactivate()`, `toggle()` | Whether the camera has the view, and how to change that. |
| `activated`, `deactivated` | Signals for hiding the HUD, showing photo mode controls and the like. |
| `yaw`, `pitch`, `set_look(yaw, pitch)` | Current direction in radians, and how to set it. |
| `get_camera()` | The `Camera3D`, for FOV and other camera settings. |
| `is_blocked()` | Whether the camera is standing back for something else, such as a pause menu. |

## How it behaves

- **Taking and giving back the view.** `activate()` remembers the viewport's current `Camera3D`, moves to where that camera is drawn and looks the same way (roll is dropped). `deactivate()` makes the remembered camera current again. If that camera was freed in the meantime, the free camera just lets go of the view.
- **Pausing.** The node runs with `PROCESS_MODE_ALWAYS`, so it flies while the tree is paused. With `pause_game` on it pauses the tree on `activate()` and puts back the pause state from before on `deactivate()`, so turning it on from a menu that already paused the game leaves the game paused.
- **Frame rate.** It moves in `_process` and is not physics-interpolated, so flying is as smooth as the display and covers the same distance at any frame rate.
- **Pause menu.** While something else has paused the tree, the toggle action is ignored. While the camera is active it also stands still whenever the mouse mode is not the one it set, which is what an open `PauseMenu` looks like. The menu still opens and closes on top of photo mode; when it resumes the game, the free camera pauses it again. Restarting the scene from the menu unpauses as usual, because a free camera that leaves the tree deactivates first.

## Spectator mode

With `pause_game` off the rest of the game keeps reading input, so your character would walk while you fly. Use the signals to hand the controls over. The demo does this:

```gdscript
func _on_free_camera_activated() -> void:
	if not free_camera.pause_game:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		orbit_camera.deactivate()


func _on_free_camera_deactivated() -> void:
	if not orbit_camera.active:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		orbit_camera.activate()
```

Disabling the character freezes it in place, also in mid-air. To keep it simulated, add a flag to your character that makes it ignore input instead.

## Scene layout

`FreeCamera` (moves and turns) → `Camera`. The rig ignores its parent's transform.

## Where to take it next

- Screenshots: hide the UI, wait a frame, then save `get_viewport().get_texture().get_image()`.
- Depth of field, exposure and filters: give `get_camera()` a `CameraAttributesPractical` and expose a few of its settings in a small photo mode panel. A roll and a field of view control belong there too.
- Recording and replay: store the transform at intervals and play the path back, for trailers and fly-throughs.
- The move, look and sprint action names are constants at the top of the script. Change them there if your project names them differently.
- Flying follows unscaled frame time only as far as `Engine.time_scale` allows: slow motion slows the camera too.
- Collision is a single swept sphere with a simple slide. It does not push the camera out if it is turned on inside a wall.
