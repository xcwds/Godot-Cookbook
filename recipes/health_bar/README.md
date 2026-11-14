# Health bar

A 2D health bar that turns yellow below 70% and red below 35%, and a 3D version that renders the 2D bar through a `SubViewport` onto a billboarded `Sprite3D`.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. For UI, instance `health_bar_2d.tscn`, set `max_value`, and call `update_healthbar(value)` when health changes.
3. Above a character, instance `health_bar_3d.tscn` as a child and call `set_max_value(max)` and `update_healthbar(value)`.

## Requirements

None. See `recipe.cfg`.

## Settings

The colours and thresholds are constants at the top of `health_bar_2d.gd`. The bar size is the `SubViewport` size in `health_bar_3d.tscn` and the gradient texture size in `health_bar_2d.tscn`.

## Where to take it next

- The bar is pushed values by whoever owns the health. A `Health` node with `changed` and `died` signals that the bar connects to is the planned next step.
- The fill is a flat generated texture. Swap `texture_progress`, `texture_under` and `texture_over` for real art.
- No animation when the value changes; a `Tween` on `value` is a small addition.
