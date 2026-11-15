# Hitbox and hurtbox

Two areas that turn overlaps into damage:

- `Hurtbox`: the part of something that can be hurt. It passes damage on to a `Health` node.
- `Hitbox`: the part of something that deals damage, such as a weapon swing, a projectile or a spike trap.

A hitbox hits each hurtbox once when they start overlapping. Teams stop friendly fire, an interval makes hazards hurt repeatedly, and invulnerability time gives the victim a breather.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) and the `health` recipe into your project.
2. Name physics layer 4 `hurtbox`.
3. On anything that can be hurt: add a `Health` node, instance `hurtbox.tscn`, set its `health`, and resize its shape to cover the body.
4. On anything that hurts: instance `hitbox.tscn`, set `damage`, and resize its shape.
5. Give both sides of each fight a `team`, such as `player` and `enemy`, so they do not hurt their own side.

For a melee attack, keep the hitbox's `active` off and switch it on only while the swing should connect, from an animation track or code:

```gdscript
func _on_attack_started() -> void:
	$Sword/Hitbox.active = true


func _on_attack_finished() -> void:
	$Sword/Hitbox.active = false
```

## Requirements

| Kind | Needed |
|---|---|
| Recipes | `health` |
| Physics layers | Hurtboxes are on layer 4; hitboxes only look at layer 4. Nothing else needs to change. |

## Settings

| Member | On | Purpose |
|---|---|---|
| `damage` | `Hitbox` | Health removed per hit. |
| `team` | both | A hitbox ignores hurtboxes with the same team. Empty belongs to no team and hits everything. |
| `active` | `Hitbox` | Whether it can hit. Turning it on hits whatever is already inside. |
| `hit_interval` | `Hitbox` | Seconds between hits on a hurtbox that stays inside. `0` hits once per visit or activation. |
| `hit_landed(hurtbox)` | `Hitbox` | Signal for each hit that got through. |
| `health` | `Hurtbox` | Where damage goes. Without it the hurtbox only emits `hit`. |
| `invulnerability_time` | `Hurtbox` | Seconds after a hit during which further hits are ignored. |
| `hit(hitbox, amount)` | `Hurtbox` | Signal for each hit taken, with the health actually lost. |

## Where to take it next

- No knockback. In a `hit` handler, push the victim away from `hitbox.global_position`.
- No hit feedback: flash the model, play a sound, or pause for a frame from `hit` and `hit_landed`.
- Damage is one number. Add a damage type to `Hitbox` and resistances in `Hurtbox.take_hit()`.
- A fast, small hitbox can pass through a hurtbox between physics ticks. For projectiles use a `ShapeCast3D` along the path instead.
- Teams are plain names. If you need "hurts enemies and props but not allies", move to separate physics layers per side.
