# Health bar

A 2D bar (`HealthBar2D`) that follows a `Health` node and turns yellow, then red, as it drains, and a 3D version (`HealthBar3D`) that renders the 2D bar through a `SubViewport` onto a billboarded `Sprite3D`.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) and the `health` recipe into your project.
2. For a HUD, instance `health_bar_2d.tscn` in your UI. Above a character, instance `health_bar_3d.tscn` as a child of the character.
3. Set the bar's `health` property to the `Health` node it should show. That is all; the bar connects itself.

To drive a bar from something other than a `Health` node, leave `health` empty and call `set_values(current, maximum)`.

## Requirements

Recipe: `health`. See `recipe.cfg`.

## Settings

| Property | On | Purpose |
|---|---|---|
| `health` | both | The `Health` node to follow. |
| `low_threshold`, `mid_threshold` | `HealthBar2D` | Fractions of the maximum where the colour changes. |
| `low_color`, `mid_color`, `high_color` | `HealthBar2D` | Bar colours. |

The bar size is the `SubViewport` size in `health_bar_3d.tscn` and the gradient texture size in `health_bar_2d.tscn`. To change the 3D bar's colours, edit the `HealthBar2d` instance inside it.

## Where to take it next

- The fill is a flat generated texture. Swap `texture_progress`, `texture_under` and `texture_over` for real art.
- The value jumps. Tween `value` in `set_values()` for a smooth drain.
- The 3D bar is always visible and always the same world size. Hide it at full health or scale it with distance.
- Each 3D bar owns a `SubViewport`, which is fine for a handful of characters and wasteful for a crowd.
