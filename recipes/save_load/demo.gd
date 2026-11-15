extends Node3D
## F5 saves, F9 loads, F8 deletes the save.

const SLOT := "demo"

@onready var _status: Label = %Status
@onready var _counter: Label = %Counter


func _ready() -> void:
	for pickup in $Pickups.get_children():
		pickup.collected.connect(_update_counter)
	_update_counter()
	_show_save_info()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_F5:
			var error := SaveGame.save_game(get_tree(), SLOT)
			_status.text = "Saved." if error == OK else "Save failed: %s" % error_string(error)
		KEY_F9:
			var error := await SaveGame.load_game(get_tree(), SLOT)
			_status.text = "Loaded." if error == OK else "Nothing to load."
		KEY_F8:
			SaveGame.delete_save(SLOT)
			_status.text = "Save deleted."


func _update_counter() -> void:
	var count := 0
	for pickup in $Pickups.get_children():
		if pickup.is_collected:
			count += 1
	_counter.text = "Collected: %d / %d" % [count, $Pickups.get_child_count()]


func _show_save_info() -> void:
	var info := SaveGame.get_save_info(SLOT)
	if info.is_empty():
		_status.text = "No save yet."
	else:
		_status.text = "Save from %s. Press F9 to load it." % info["saved_at"]
