extends Area3D
## Demo-only pickup that remembers whether it was collected.

signal collected

var is_collected := false


func _ready() -> void:
	add_to_group(SaveGame.GROUP)
	body_entered.connect(func(_body: Node3D) -> void: _set_collected(true))


func save_data() -> Dictionary:
	return {"collected": is_collected}


func load_data(data: Dictionary) -> void:
	_set_collected(data["collected"])


func _set_collected(value: bool) -> void:
	is_collected = value
	visible = not value
	# Changing monitoring is not allowed while the physics server is busy.
	set_deferred(&"monitoring", not value)
	collected.emit()
