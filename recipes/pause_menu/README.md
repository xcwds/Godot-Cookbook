# Pause menu

A `CanvasLayer` that pauses the scene tree on the `pause` action and shows Resume, Restart and Quit over a dimmed screen. It is also the one place that changes the mouse mode around pausing, so mouse-look games do not need to handle that elsewhere.

## Add it to your project

1. Copy this folder (without `demo.tscn`) into your project.
2. Add a `pause` input action (Esc and gamepad Start in the cookbook project).
3. Instance `pause_menu.tscn` anywhere in your gameplay scene.

While paused, only nodes whose `process_mode` allows it keep running. The menu sets its own.

## Requirements

Input action: `pause` (or whatever you set `pause_action` to). See `recipe.cfg`.

## Settings

| Member | Purpose |
|---|---|
| `pause_action` | Input action that opens and closes the menu. |
| `capture_mouse` | Capture the mouse while playing. On pause the mouse is released, and on resume the previous mouse mode is restored either way. Turn it off for games that use a visible cursor. |
| `pause()`, `resume()`, `toggle()`, `is_open()` | Control it from code. |
| `restart()`, `quit()` | What the buttons call. |
| `paused`, `resumed` | Signals, for muting audio or showing a HUD hint. |

## Where to take it next

- Restart reloads the current scene and Quit closes the game with no confirmation. Most games want "back to main menu" and an "are you sure?".
- No settings screen. A settings recipe is on the roadmap; a button here would open it.
- The menu uses the default theme. Give `Panel` a theme, or replace the layout under `Center`.
- Anything else that opens over the game (inventory, dialogue) will fight over pause and mouse mode. At that point move both into one small manager.
