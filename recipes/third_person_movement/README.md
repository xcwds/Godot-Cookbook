# Third-person movement

A `CharacterBody3D` (`ThirdPersonCharacter`) that walks and runs relative to the camera, jumps with coyote time and input buffering, dashes, and slides down and jumps off walls. Each move is a state under a `StateMachine`. It comes with a CC0 Kenney character and an animation tree, and knows nothing about cameras, health or UI.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) and the `state_machine` recipe into your project.
2. Add the input actions listed below.
3. Instance `third_person_character.tscn` in a level that has collision on physics layer 1.
4. Add a camera. Movement is relative to the viewport's current camera, so any camera works; `orbit_camera` is made for this.
5. Recommended: turn on **Physics Interpolation** in Project Settings, so the character is drawn smoothly on displays faster than the physics rate.

`demo.tscn` shows it wired to `orbit_camera`, `aim_camera`, `health`, `health_bar` and `pause_menu`. The only glue is two lines in `demo.gd` that turn on `strafe` while aiming.

## Requirements

| Kind | Needed |
|---|---|
| Recipes | `state_machine` |
| Input actions | `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `dash` |
| Physics layers | The character is on layer 2 and collides with layer 1. |

Bindings in the cookbook project: WASD / left stick to move, Space / A to jump, Shift / left shoulder to dash.

## Settings

| Property | Purpose |
|---|---|
| `view` | Node whose yaw decides which way is forward. Empty uses the current camera. |
| `strafe` | Face the view direction instead of the movement direction. Turn it on while aiming. |
| `speed`, `rotation_speed`, `jump_velocity`, `air_control` | Basic movement. |
| `coyote_time`, `jump_buffer_time` | Jump assists, in seconds. `0` turns either off. |
| `dash_enabled`, `dash_speed`, `dash_distance`, `dash_cooldown` | Dash. One dash per jump while airborne. |
| `wall_slide_enabled`, `wall_slide_speed`, `wall_jump_push`, `wall_jump_control_lock` | Wall slide and wall jump. |
| `jumped`, `landed`, `dashed` | Signals, for sounds and effects. |

The input action names are constants at the top of `third_person_character.gd`.

## Scene layout

- `StateMachine` with `Ground`, `Air`, `Dash` and `WallSlide`. Each state's script in `states/` is the whole of that move; `third_person_character.gd` only holds settings and shared helpers. To remove dashing or wall sliding, turn off its `*_enabled` setting.
- `Model` holds everything visual: the character mesh, `AnimationPlayer`, `AnimationTree` and `Animator`. The model carries the facing: it turns toward the movement direction, and the root does not turn. Rotate the root to choose which way the character faces when it spawns. Use `get_model_yaw()`, `set_model_yaw()` and `get_facing_direction()`, which work in world space, rather than `Model.rotation`, which is relative to the root.
- `Animator` (`character_animator.gd`) picks the animation from the current state and velocity. The movement code never touches animations.

### Swapping the model

1. Replace `Model/Character` with your model, facing -Z, feet at the bottom of the capsule.
2. Point `AnimationPlayer` and `AnimationTree` at it and rebuild the tree with the states `Locomotion`, `Strafe`, `Air` and `WallSlide`, or change the names in `character_animator.gd`.

## Where to take it next

- Velocity changes instantly. Add acceleration and friction in `steer()` for weightier movement.
- No variable jump height: releasing jump early does not cut the jump short.
- No slopes handling beyond what `CharacterBody3D` does, no stairs, no moving platforms.
- The Kenney bundle has only idle, walk, run and jump clips: sideways and backwards movement while strafing slides, there is no landing animation, and wall sliding uses the jump pose.
- Wall sliding works on any wall. Restrict it with a physics layer or a group check in `can_wall_slide()`.
- The dash has no animation, effect or invulnerability; connect to `dashed`.
