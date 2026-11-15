extends SceneTree
## Headless test for recipes/save_load. Run with:
##   godot --headless --path . -s tests/test_save_load.gd

const DEMO := "res://recipes/save_load/demo.tscn"
const OTHER_SCENE := "res://recipes/state_machine/demo.tscn"
const SLOT := "test_slot"

var _failures := 0


func _initialize() -> void:
	SaveGame.delete_save(SLOT)
	await _open(DEMO)
	await _test_round_trip_in_the_same_scene()
	await _test_load_changes_to_the_saved_scene()
	await _test_engine_types_survive()
	await _test_missing_and_damaged_saves()
	SaveGame.delete_save(SLOT)
	if _failures == 0:
		print("test_save_load: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _open(scene: String) -> void:
	change_scene_to_file(scene)
	await process_frame
	await process_frame
	await physics_frame


func _player() -> Node3D:
	return current_scene.get_node("Player")


func _pickup(index: int) -> Node:
	return current_scene.get_node("Pickups").get_child(index)


func _test_round_trip_in_the_same_scene() -> void:
	_check(not SaveGame.has_save(SLOT), "no save to begin with")
	_check(await SaveGame.load_game(self, SLOT) != OK, "loading an empty slot fails")

	_player().global_position = Vector3(5, 1.1, 5)
	_pickup(0).load_data({"collected": true})
	_check(SaveGame.save_game(self, SLOT) == OK, "save succeeds")
	_check(SaveGame.has_save(SLOT), "the slot now has a save")
	var info := SaveGame.get_save_info(SLOT)
	_check(info.get("scene") == DEMO and info.has("saved_at"), "save info names the scene")

	_player().global_position = Vector3(-9, 1.1, -9)
	_pickup(0).load_data({"collected": false})
	_pickup(1).load_data({"collected": true})
	_check(await SaveGame.load_game(self, SLOT) == OK, "load succeeds")
	_check(_player().global_position.is_equal_approx(Vector3(5, 1.1, 5)), "position is restored")
	_check(_pickup(0).is_collected and not _pickup(0).visible, "collected pickup is restored")
	_check(not _pickup(1).is_collected and _pickup(1).visible, "uncollected pickup is restored")


func _test_load_changes_to_the_saved_scene() -> void:
	await _open(OTHER_SCENE)
	_check(await SaveGame.load_game(self, SLOT) == OK, "load from another scene succeeds")
	_check(current_scene.scene_file_path == DEMO, "it switches to the saved scene")
	_check(_player().global_position.is_equal_approx(Vector3(5, 1.1, 5)), "and applies the state")
	_check(_pickup(0).is_collected, "to every saveable node")


func _test_engine_types_survive() -> void:
	var probe := Probe.new()
	probe.name = "Probe"
	current_scene.add_child(probe)
	probe.data = {
		"position": Vector3(1, 2, 3),
		"color": Color(0.1, 0.2, 0.3),
		"count": 7,
		"ratio": 0.5,
		"name": "abc",
		"list": [1, 2, Vector2(3, 4)],
	}
	var expected := probe.data.duplicate(true)
	SaveGame.save_game(self, SLOT)
	probe.data = {}
	await SaveGame.load_game(self, SLOT)
	_check(probe.data == expected, "vectors, colours, ints and nested values round-trip")
	_check(typeof(probe.data.get("count")) == TYPE_INT, "ints stay ints")
	probe.free()


func _test_missing_and_damaged_saves() -> void:
	print("(errors about save files are expected below)")
	var before := _player().global_position
	var path := SaveGame.get_save_path(SLOT)

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not json at all")
	file.close()
	_check(await SaveGame.load_game(self, SLOT) != OK, "a damaged save is rejected")
	_check(SaveGame.get_save_info(SLOT).is_empty(), "and has no info")

	file = FileAccess.open(path, FileAccess.WRITE)
	var newer := {"version": SaveGame.VERSION + 1, "scene": DEMO, "saved_at": "", "nodes": {}}
	file.store_string(JSON.stringify(newer))
	file.close()
	_check(await SaveGame.load_game(self, SLOT) != OK, "a save from a newer version is rejected")
	_check(_player().global_position == before, "a rejected save changes nothing")

	SaveGame.delete_save(SLOT)
	_check(not SaveGame.has_save(SLOT), "delete removes the save")


class Probe:
	extends Node
	var data := {}

	func _ready() -> void:
		add_to_group(SaveGame.GROUP)

	func save_data() -> Dictionary:
		return data

	func load_data(new_data: Dictionary) -> void:
		data = new_data
