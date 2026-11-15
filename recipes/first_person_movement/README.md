# First-person movement

A first-person `CharacterBody3D` (`FirstPersonCharacter`) in a single script: mouse and stick look, walking with acceleration, sprinting, crouching under things, and jumping with coyote time and input buffering.

It is deliberately one file with no state machine, as a contrast to `third_person_movement`. Start here if you want something small to read and change.

## Add it to your project

1. Copy this folder (without `demo.tscn`) into your project.
2. Add the input actions listed below.
3. Instance `first_person_character.tscn` in a level that has collision on physics layer 1. Its origin is at its feet.

The character captures the mouse when it enters the scene. Turn `capture_mouse` off if something else, such as the `pause_menu` recipe, does that for you.

## Requirements

| Kind | Needed |
|---|---|
| Input actions | `move_left`, `move_right`, `move_up`, `move_down`, `look_left`, `look_right`, `look_up`, `look_down`, `jump`, `sprint`, `crouch` |
| Physics layers | The character is on layer 2 and collides with layer 1. |

Bindings in the cookbook project: WASD / left stick to move, mouse / arrow keys / right stick to look, Space / A to jump, Shift / left stick click to sprint, Ctrl / B to crouch.

## Settings

| Property | Purpose |
|---|---|
| `walk_speed`, `sprint_speed`, `crouch_speed` | Target speeds. |
| `ground_acceleration`, `air_acceleration` | How quickly speed changes. Lower air acceleration means less control while airborne. |
| `jump_velocity`, `coyote_time`, `jump_buffer_time` | Jumping and its assists. |
| `mouse_sensitivity`, `stick_speed`, `invert_y`, `pitch_limit_degrees` | Looking. |
| `capture_mouse` | Capture the mouse on ready. |
| `stand_height`, `crouch_height`, `eye_offset`, `crouch_transition_speed` | Crouching. The capsule and the camera height follow these. |
| `yaw`, `pitch`, `set_look(yaw, pitch)` | The view direction in radians, and how to set it. |
| `is_crouching`, `is_sprinting()`, `get_target_speed()` | State, for a HUD or footsteps. |
| `jumped`, `landed`, `crouch_changed(crouching)` | Signals. |
| `teleport(transform)` | Moves the character and looks the way the transform faces, with the view level, for respawning and loading. It stops and clears buffered jumps and coyote time. The `checkpoint` and `save_load` recipes call it. |
| `head`, `camera` | The node that tilts and the `Camera3D`, for attaching a weapon or changing FOV. |

The input action names are constants at the top of the script.

## Scene layout

`FirstPersonCharacter` → `Head` → `Camera`. `Head` holds the whole view direction and is placed by the script every frame at eye height above the body, so looking around is immediate and, with **Physics Interpolation** on in Project Settings (recommended), movement is as smooth as the display. The body turns to match the view on the physics tick. The collision capsule shrinks from the top when crouching, and the character stays crouched while there is no room to stand.

## Where to take it next

- Crouch is hold only, and sprint works in every direction. Both are a line or two in `_update_crouch()` and `is_sprinting()`.
- No head bob, FOV change when sprinting, or camera tilt. `camera` and `head` are there for that.
- No step-up for stairs and no ladders; slopes are whatever `CharacterBody3D` does.
- No sliding or mantling.
- Nothing to hold or shoot. Add it under `Head` so it follows the view; the `interaction` recipe's `Interactor` goes there too, with `facing` set to `Head`.
