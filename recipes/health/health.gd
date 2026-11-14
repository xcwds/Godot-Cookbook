class_name Health
extends Node
## Tracks hit points for whatever it is attached to. Other nodes call
## [method damage] and [method heal] and listen to the signals.

## Emitted whenever [member current_health] or [member max_health] changes.
signal changed(current: float, maximum: float)
## Emitted when damage is applied, with the amount actually lost.
signal damaged(amount: float)
## Emitted once when health reaches zero.
signal died

## Largest value [member current_health] can have. Health starts full.
@export var max_health := 10.0:
	set(value):
		max_health = maxf(value, 0.0)
		current_health = minf(current_health, max_health)
		changed.emit(current_health, max_health)
## While true, [method damage] does nothing.
@export var invulnerable := false

var current_health := 0.0


func _ready() -> void:
	reset()


func is_dead() -> bool:
	return current_health <= 0.0


## Removes up to [param amount] health and returns how much was removed.
func damage(amount: float) -> float:
	if invulnerable or is_dead() or amount <= 0.0:
		return 0.0
	var lost := minf(amount, current_health)
	current_health -= lost
	changed.emit(current_health, max_health)
	damaged.emit(lost)
	if is_dead():
		died.emit()
	return lost


## Restores up to [param amount] health and returns how much was restored.
## Does nothing once dead; call [method reset] to revive.
func heal(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var gained := minf(amount, max_health - current_health)
	current_health += gained
	changed.emit(current_health, max_health)
	return gained


## Back to full health, also from dead.
func reset() -> void:
	current_health = max_health
	changed.emit(current_health, max_health)
