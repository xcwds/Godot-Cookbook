extends Projectile
## Demo-only: a projectile that also deals damage, by carrying a Hitbox from
## the hitbox recipe.

@onready var _hitbox: Hitbox = $Hitbox


func _ready() -> void:
	# The hitbox only connects while flying, and a hit ends the flight.
	launched.connect(func() -> void: _hitbox.active = true)
	despawned.connect(func() -> void: _hitbox.active = false)
	_hitbox.hit_landed.connect(func(_hurtbox: Hurtbox) -> void: despawn())
