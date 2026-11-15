extends Node
## Saves whatever is in [member data], for tests/test_save_load.gd.

var data := {}


func _ready() -> void:
	add_to_group(&"saveable")


func save_data() -> Dictionary:
	return data


func load_data(new_data: Dictionary) -> void:
	data = new_data
