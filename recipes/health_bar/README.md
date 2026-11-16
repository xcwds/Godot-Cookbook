# Health bar

A 2D bar (`HealthBar2D`) that follows a `Health` node, or any other `Meter` such as stamina, and turns yellow, then red, as it drains, and a 3D version (`HealthBar3D`) that renders the 2D bar through a `SubViewport` onto a billboarded `Sprite3D`.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) and the `meter` recipe into your project. `Health` from the `health` recipe is a `Meter`.
2. For a HUD, instance `health_bar_2d.tscn` in your UI. Above a character, instance `health_bar_3d.tscn` as a child of the character.
3. Set the bar's `meter` property to the `Health` node, or other `Meter`, it should show. That is all; the bar connects itself.

To drive a bar from something that is not a `Meter`, leave `meter` empty and call `set_values(current, maximum)`.

The property used to be called `health`. That name still works in scenes and code, so nothing saved before the rename breaks; the editor writes `meter` the next time it saves such a scene.

## Requirements

Recipe: `meter`. See `recipe.cfg`.

## Settings

| Property | On | Purpose |
|---|---|---|
| `meter` | both | The `Meter` to follow, for example a `Health` node. |
| `low_threshold`, `mid_threshold` | `HealthBar2D` | Fractions of the maximum where the colour changes. |
| `low_color`, `mid_color`, `high_color` | `HealthBar2D` | Bar colours. |

The bar size is the `SubViewport` size in `health_bar_3d.tscn` and the gradient texture size in `health_bar_2d.tscn`. To change the 3D bar's colours, edit the `HealthBar2d` instance inside it.

## Where to take it next

- The fill is a flat generated texture. Swap `texture_progress`, `texture_under` and `texture_over` for real art.
- The value jumps. Tween `value` in `set_values()` for a smooth drain.
- The 3D bar is always visible and always the same world size. Hide it at full health or scale it with distance.
- Each 3D bar owns a `SubViewport`, which is fine for a handful of characters and wasteful for a crowd.
