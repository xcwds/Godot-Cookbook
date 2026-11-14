# Third-person controller

A `CharacterBody3D` with idle/walk/run, jump, dash, optional mid-air control, optional wall slide and wall jump, a mouse or stick orbit camera on a spring arm with zoom, and an over-the-shoulder aim camera. Animated with a CC0 Kenney character.

This recipe is still one piece. It will be split into movement, orbit camera and aim camera recipes.

## Add it to your project

1. Copy this folder (without `demo.tscn`) and its dependencies, `state_machine` and `health_bar`, into your project.
2. Add the input actions listed below.
3. Instance `third_person_controller.tscn` in a level that has collision on physics layer 1.
4. Capture the mouse (`Input.mouse_mode = Input.MOUSE_MODE_CAPTURED`), for example with the `pause_menu` recipe; mouse look only runs while it is captured.

## Requirements

| Kind | Needed |
|---|---|
| Recipes | `state_machine`, `health_bar` |
| Input actions | `move_left`, `move_right`, `move_up`, `move_down`, `look_left`, `look_right`, `look_up`, `look_down`, `jump`, `dash`, `aim` |
| Physics layers | The player is on layer 2 and collides with layer 1. |

Bindings in the cookbook project: WASD / left stick to move, mouse / arrow keys / right stick to look, Space / A to jump, Shift / left shoulder to dash, right mouse / right trigger to aim, mouse wheel to zoom.

## Settings

On the root node: `speed`, `rotation_speed`, `jump_velocity`, `dash_speed`, `dash_length`, `dash_cooldown`, `is_dash_hold`, `is_mid_air_movement`, `is_wall_slide`, `wall_slide_velocity`, `hp`, `max_hp`.
On `Twist`: mouse sensitivity, pitch limits, axis inversion and locks. On `FreeCamSpringArm`: zoom range and step. On `AimCamera`: sensitivity and inversion.

## Scene layout

- `Model`: the character, its `AnimationPlayer` and `AnimationTree`, and the aim camera.
- `Twist/Pitch/FreeCamSpringArm/FreeCamera`: the orbit camera rig. `Twist` is top-level and follows the player.
- `StateMachine`: one node per movement state in `states/`. Delete `WallSlide` and `WallJump` (and turn off `is_wall_slide`) if you do not want them.

## Where to take it next

- The controller script owns movement, aiming, camera switching and health, and the states call back into it. Splitting those apart is the next planned step.
- Nodes are found by hard-coded path, so renaming nodes in the scene breaks the scripts.
- Holding jump re-jumps on every landing, and there is no coyote time or jump buffering.
- Jumping while pressed against a wall drops straight into the wall slide instead of rising.
- The end of a dash pushes velocity toward +X/+Z regardless of dash direction.
- The character has only idle, walk, run and jump clips: sideways and backwards movement while aiming slides, and falling, landing and wall sliding all use the jump pose.
- The aim camera was placed for a different model and sits close to this character's head; aim pitch is not clamped.
- Orbit camera follow is frame-rate dependent.
