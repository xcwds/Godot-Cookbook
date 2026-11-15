# Health

Hit points as a node. Add a `Health` child to anything that can be hurt; other nodes call `damage()` and `heal()` on it and listen to its signals. It knows nothing about what it is attached to.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Add a `Node` with `health.gd` as a child of your character or prop and set `max_health`.
3. Hurt it from anywhere: `target.get_node("Health").damage(3.0)`.
4. React to it:

```gdscript
func _ready() -> void:
	$Health.died.connect(queue_free)
	$Health.damaged.connect(func(_amount: float) -> void: $HitSound.play())
```

Health starts full.

## Requirements

None. See `recipe.cfg`.

## Settings

| Member | Purpose |
|---|---|
| `max_health` | Upper limit. Lowering it clamps the current value. |
| `invulnerable` | While true, `damage()` does nothing. |
| `current_health` | Current value. Read it; change it with the methods below. |
| `damage(amount)` | Removes health, returns the amount actually lost. |
| `heal(amount)` | Restores health up to the maximum. Does nothing once dead. |
| `reset()` | Back to full, also from dead. |
| `is_dead()` | True at zero health. |
| `changed(current, maximum)` | Signal: either value changed. |
| `damaged(amount)` | Signal: damage was applied. |
| `died` | Signal: health reached zero. Emitted once. |

## Where to take it next

- Damage has to be delivered by something. The `hitbox` recipe calls `damage()` when areas overlap.
- No invulnerability window after a hit here; `Hurtbox` in the `hitbox` recipe has one, or set `invulnerable` from a timer on `damaged`.
- No damage types, resistances or shields. `damage()` is the one place to add them.
- Finding the node is by convention (`get_node("Health")`). A group or a typed helper scales better.
