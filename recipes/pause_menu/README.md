# Pause menu

A full-screen `Control` that toggles `get_tree().paused` on the `pause` action and shows Resume, Restart and Quit. It also captures the mouse while playing and releases it while paused.

## Add it to your project

1. Copy this folder (without `demo.tscn`) into your project.
2. Add the `pause` input action (Esc and gamepad Start in the cookbook project).
3. Instance `pause_menu.tscn` anywhere in your gameplay scene.

Nodes that should keep running while paused need their own `process_mode`.

## Requirements

Input action: `pause`. See `recipe.cfg`.

## Where to take it next

- It captures the mouse on `_ready`, which suits a mouse-look game and nothing else. Make that an exported option.
- Restart reloads the current scene; Quit closes the game. Most games want "back to main menu" and a confirmation.
- The buttons are positioned with fixed offsets and are not focused when the menu opens, so gamepad navigation needs a `grab_focus()`.
