class_name Health
extends Node
## Tracks hit points for whatever it is attached to. Other nodes call
## [method damage] and [method heal] and listen to the signals.

## Emitted whenever [member current_health] or [member max_health] changes.
signal changed(current: float, maximum: float)
## Emitted when damage is applied, with the amount actually lost.
signal damaged(amount: float)
## Emitted once when health reaches zero, through damage or because
## [member max_health] was lowered to zero.
signal died

## Largest value [member current_health] can have. Health starts full.
@export var max_health := 10.0:
	set(value):
		var was_alive := not is_dead()
		max_health = maxf(value, 0.0)
		current_health = minf(current_health, max_health)
		changed.emit(current_health, max_health)
		if was_alive and is_dead():
			died.emit()
## While true, [method damage] does nothing.
@export var invulnerable := false

var current_health := 0.0


func _ready() -> void:
	reset()
	# Lets the save_load recipe pick this up, if it is in the project. See
	# "Saveable nodes" in docs/recipe_contract.md.
	add_to_group(&"saveable")


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


func save_data() -> Dictionary:
	return {"current": current_health, "max": max_health}


func load_data(data: Dictionary) -> void:
	max_health = data.get("max", max_health)
	current_health = clampf(data.get("current", max_health), 0.0, max_health)
	changed.emit(current_health, max_health)


## What this belonged to was gone when the game was saved.
func load_missing() -> void:
	get_parent().queue_free()
