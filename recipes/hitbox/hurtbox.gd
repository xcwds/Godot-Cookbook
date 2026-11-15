class_name Hurtbox
extends Area3D
## The part of something that can be hurt. Give it a collision shape that
## covers the body, and point [member health] at the [Health] to damage.

## Emitted when a hit gets through. [param amount] is the health lost.
signal hit(hitbox: Hitbox, amount: float)

## Where damage goes. Optional: without it only [signal hit] is emitted.
@export var health: Health
## Hitboxes with the same team are ignored. Empty belongs to no team.
@export var team := &""
## Seconds after a hit during which further hits are ignored.
@export var invulnerability_time := 0.0

var _invulnerable_left := 0.0


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


## Called by a [Hitbox]. Returns true if the hit got through.
func take_hit(hitbox: Hitbox) -> bool:
	if _invulnerable_left > 0.0:
		return false
	if team != &"" and team == hitbox.team:
		return false
	var amount := hitbox.damage
	if health != null:
		amount = health.damage(hitbox.damage)
		if amount <= 0.0:
			return false
	_invulnerable_left = invulnerability_time
	hit.emit(hitbox, amount)
	return true
