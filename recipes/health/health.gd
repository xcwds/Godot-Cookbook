class_name Health
extends Meter
## Tracks hit points for whatever it is attached to. Other nodes call
## [method damage] and [method heal] and listen to the signals.
##
## It is a [Meter] with the words of health: [member max_health] is
## [member Meter.maximum], [member current_health] is [member Meter.current],
## and it adds invulnerability, staying dead until [method reset], and the
## [signal damaged] and [signal died] signals. [signal Meter.changed] is
## emitted whenever either value changes.

## Emitted when damage is applied, with the amount actually lost.
signal damaged(amount: float)
## Emitted once when health reaches zero, through damage or because
## [member max_health] was lowered to zero.
signal died

## Largest value [member current_health] can have. Health starts full. The
## same value as [member Meter.maximum], under the name scenes and code
## written for this recipe use.
@export var max_health: float = 10.0:
	get:
		return maximum
	set(value):
		maximum = value
## While true, [method damage] does nothing.
@export var invulnerable := false

## Current hit points. The same value as [member Meter.current].
var current_health: float:
	get:
		return current
	set(value):
		current = value

# True while damage() runs, so that died follows damaged as it always has.
var _is_taking_damage := false


func _init() -> void:
	depleted.connect(_on_depleted)


func is_dead() -> bool:
	return is_empty()


## Removes up to [param amount] health and returns how much was removed.
func damage(amount: float) -> float:
	if invulnerable or is_dead() or amount <= 0.0:
		return 0.0
	_is_taking_damage = true
	var lost := drain(amount)
	_is_taking_damage = false
	damaged.emit(lost)
	if is_dead():
		died.emit()
	return lost


## Restores up to [param amount] health and returns how much was restored.
## Does nothing once dead; call [method reset] to revive.
func heal(amount: float) -> float:
	if is_dead():
		return 0.0
	return add(amount)


## Back to full health, also from dead.
func reset() -> void:
	fill()


## Keeps the keys saves have always used for health.
func save_data() -> Dictionary:
	return {"current": current, "max": maximum}


func load_data(data: Dictionary) -> void:
	var loaded_maximum: float = data.get("max", maximum)
	super({"current": data.get("current", loaded_maximum), "maximum": loaded_maximum})


## What this belonged to was gone when the game was saved.
func load_missing() -> void:
	get_parent().queue_free()


func _on_depleted() -> void:
	if not _is_taking_damage:
		died.emit()
