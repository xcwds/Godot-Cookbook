# Settings menu

Player settings and a screen to change them:

- `GameSettings`: volume per audio bus, fullscreen, v-sync and key bindings. Every change is applied at once and saved to `user://settings.cfg`.
- `SettingsMenu`: a panel with Audio, Video and Controls tabs that edits them.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Apply saved settings when the game starts, in your first scene or an autoload:

```gdscript
func _ready() -> void:
	GameSettings.load_and_apply()
```

3. Instance `settings_menu.tscn` wherever settings should be shown, such as a main menu or a pause menu, and connect `closed` to hide it again.

The Audio tab gets one slider per audio bus in your project, so add buses such as Music and SFX in the Audio panel at the bottom of the editor. The Controls tab lists every input action in your project except the built-in `ui_` ones; set `remappable_actions` on the menu to choose and order them yourself.

## Requirements

None. See `recipe.cfg`.

## Settings

| Member | On | Purpose |
|---|---|---|
| `load_and_apply()` | `GameSettings` | Loads the file and applies it. Call once at startup. |
| `get_bus_volume(bus)`, `set_bus_volume(bus, linear)` | `GameSettings` | Volume from 0 to 1. Zero mutes the bus. |
| `is_fullscreen()`, `set_fullscreen(enabled)` | `GameSettings` | Window mode. |
| `is_vsync()`, `set_vsync(enabled)` | `GameSettings` | V-sync. |
| `get_binding_text(action)`, `set_binding(action, event)` | `GameSettings` | The key or mouse button for an action. |
| `find_conflict(action, event)` | `GameSettings` | Another action already using that input, if any. |
| `reset_bindings()` | `GameSettings` | Back to the project's bindings. |
| `settings_path` | `GameSettings` | Where the file is stored. |
| `remappable_actions` | `SettingsMenu` | Actions shown on the Controls tab. Empty shows all. |
| `closed` | `SettingsMenu` | Signal emitted by the Back button. |

## How rebinding works

Each action has one key or mouse button that the player can change. Rebinding replaces that and leaves gamepad bindings alone. Bindings are saved as key and button numbers, so the settings file stays readable.

When the new input is already used by another action, the menu says so and keeps both; it does not swap or block.

## Where to take it next

- Gamepad buttons cannot be rebound, and there is one keyboard binding per action.
- Action names are shown as written in the input map (`move_up` becomes "Move Up"). Use a dictionary of display names, or translations.
- Video settings stop at fullscreen and v-sync. Resolution, window size, render scale and quality presets go in the same place.
- No mouse sensitivity or other gameplay options. Add a section to `GameSettings` and a tab to the menu; the `orbit_camera` recipe has the properties to set.
- The menu uses the default theme and does not grab focus for gamepad navigation when shown.
