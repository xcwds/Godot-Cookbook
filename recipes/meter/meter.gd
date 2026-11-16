class_name Meter
extends Node
## A number between zero and a maximum, with signals: stamina, mana, shield,
## charge, oxygen. Other nodes call [method add], [method spend] and
## [method drain] and listen to the signals. It knows nothing about what the
## number means.

## Emitted when [member current] or [member maximum] changes, and not when a
## call leaves both as they were.
signal changed(current: float, maximum: float)
## Emitted once when [member current] reaches zero from above.
signal depleted
## Emitted once when [member current] reaches [member maximum] from below.
signal filled

## Largest value [member current] can have. Lowering it clamps
## [member current]. Never negative.
@export var maximum: float = 10.0:
	get:
		return _maximum
	set(value):
		_set_values(_current, value)
## Whether the meter starts at [member maximum] rather than at zero.
@export var start_full := true

## The value, always between zero and [member maximum]. Setting it clamps it
## and emits the signals, like the methods do.
var current: float:
	get:
		return _current
	set(value):
		_set_values(value, _maximum)

var _current := 0.0
var _maximum := 10.0


func _ready() -> void:
	if start_full:
		# Starting full is not "reaching the maximum", so filled stays quiet.
		_set_values(_maximum, _maximum, false)
	# Lets the save_load recipe pick this up, if it is in the project. See
	# "Saveable nodes" in docs/recipe_contract.md.
	add_to_group(&"saveable")


## Adds up to [param amount] and returns how much was added.
func add(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before := _current
	_set_values(before + amount, _maximum)
	return _current - before


## Removes up to [param amount] and returns how much was removed. For things
## that take what is there, such as damage or a drain over time.
func drain(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before := _current
	_set_values(before - amount, _maximum)
	return before - _current


## Removes exactly [param amount] if there is that much, and returns whether
## it did. For costs: a dash that needs 3 does not happen with 2 left.
func spend(amount: float) -> bool:
	if amount > _current:
		return false
	drain(amount)
	return true


## Sets [member current] to [member maximum].
func fill() -> void:
	_set_values(_maximum, _maximum)


## Sets [member current] to zero.
func empty() -> void:
	_set_values(0.0, _maximum)


func is_empty() -> bool:
	return _current <= 0.0


func is_full() -> bool:
	return _current >= _maximum


## [member current] as a fraction of [member maximum], from 0 to 1.
func get_fraction() -> float:
	return _current / _maximum if _maximum > 0.0 else 0.0


func save_data() -> Dictionary:
	return {"current": _current, "maximum": _maximum}


## Restores both values without emitting [signal depleted] or [signal filled]:
## loading a save is not the moment the meter ran out.
func load_data(data: Dictionary) -> void:
	var loaded_maximum: float = data.get("maximum", _maximum)
	_set_values(data.get("current", loaded_maximum), loaded_maximum, false)


# The one place the values change. Clamps, then emits changed if either value
# is different, and depleted or filled if the meter got there just now.
func _set_values(new_current: float, new_maximum: float, announce_ends := true) -> void:
	new_maximum = maxf(new_maximum, 0.0)
	new_current = clampf(new_current, 0.0, new_maximum)
	if new_current == _current and new_maximum == _maximum:
		return
	var was_empty := is_empty()
	var was_full := is_full()
	_current = new_current
	_maximum = new_maximum
	changed.emit(_current, _maximum)
	if not announce_ends:
		return
	if is_empty() and not was_empty:
		depleted.emit()
	# An empty meter with a maximum of zero is not "full" in any useful sense.
	if is_full() and not was_full and _maximum > 0.0:
		filled.emit()
