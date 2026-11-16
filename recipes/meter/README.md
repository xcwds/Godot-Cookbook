# Meter

A number between zero and a maximum, as a node: stamina, mana, shield, charge, oxygen. Other nodes call `add()`, `spend()` and `drain()` on it and listen to its signals. `Health` in the `health` recipe is a `Meter` with the words of health on top.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Add a `Node` with `meter.gd` as a child of whatever owns the value, name it for what it measures (`Stamina`), and set `maximum`.
3. Use it:

```gdscript
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"dash") and $Stamina.spend(3.0):
		dash()
	$Stamina.add(2.0 * delta)  # regenerate
```

4. React to it:

```gdscript
func _ready() -> void:
	$Stamina.depleted.connect(func() -> void: $OutOfBreath.play())
```

To show it, point the `meter` property of a bar from the `health_bar` recipe at it.

## Requirements

None. See `recipe.cfg`.

## Settings

| Member | Purpose |
|---|---|
| `maximum` | Upper limit. Lowering it clamps the current value. Never negative. |
| `start_full` | Start at `maximum` (the default) or at zero. |
| `current` | Current value, always between zero and `maximum`. Setting it clamps it and emits the signals. |
| `add(amount)` | Adds up to `amount`, returns how much was added. |
| `drain(amount)` | Removes up to `amount`, returns how much was removed. For damage and drains over time. |
| `spend(amount)` | Removes exactly `amount` if there is that much and returns whether it did. For costs. |
| `fill()`, `empty()` | To the maximum, or to zero. |
| `is_empty()`, `is_full()`, `get_fraction()` | Reading the state; the fraction is from 0 to 1. |
| `changed(current, maximum)` | Signal: either value changed. Not emitted when a call changes nothing. |
| `depleted` | Signal: reached zero from above. Emitted once each time. |
| `filled` | Signal: reached the maximum from below. Emitted once each time, and not for starting full. |

A `Meter` saves and loads itself with the `save_load` recipe, if that is in the project. Loading does not emit `depleted` or `filled`.

## Design decisions

- **It is its own recipe**, and `health` depends on it, so that stamina or a HUD counter does not have to bring health along.
- **Float only.** There is no integer mode. Whole-number counts such as ammunition or coins belong in `Inventory` (the `inventory` recipe).
- **No regeneration.** Add it where the value lives, as in the snippet above, so that the rules (a delay after spending, no regeneration while sprinting) are yours.
- **The name is `Meter`**, not `Stat` or `ResourcePool`; `Resource` is taken by the engine.

## Where to take it next

- Regeneration with a delay after the last spend: a timer you restart on `changed`, and `add()` only when it has run out.
- `spend()` compares exactly. If costs come from accumulated floats, allow a small tolerance.
- No temporary changes to the maximum (buffs). Keep the base maximum yourself and set `maximum` from it.
- One number per node. For many stats on one character, a dictionary of values in one script reads better than a dozen child nodes.
