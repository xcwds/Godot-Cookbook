extends "res://tests/support/test_case.gd"
## Headless test for recipes/save_load, alone and together with the other
## saveable recipes. Run with:
##   godot --headless --path . -s tests/test_save_load.gd

const DEMO := "res://recipes/save_load/demo.tscn"
const FIXTURE := "res://tests/save_load_fixture.tscn"
const OTHER_SCENE := "res://recipes/state_machine/demo.tscn"
const SLOT := "test_slot"
## Away from everything in the fixture, so opening it collects nothing.
const AWAY := Vector3(-4, 1.1, -12)


func _before_all() -> void:
	SaveGame.delete_save(SLOT)
	await _open(DEMO)


func _after_all() -> void:
	SaveGame.delete_save(SLOT)


## Opens a scene. With [param player_at], its Player is moved there before
## the first physics tick, so it does not touch what is at its start.
func _open(scene_path: String, player_at: Variant = null) -> void:
	var scene: Node = load(scene_path).instantiate()
	if player_at != null:
		# Placed the way SaveTransform places a loaded body.
		var move := func() -> void:
			var player: Node3D = scene.get_node("Player")
			var transform := player.global_transform
			transform.origin = player_at
			player.get_node("SaveTransform").load_data({"transform": transform})
		scene.ready.connect(move, CONNECT_ONE_SHOT)
	change_scene_to_node(scene)
	await process_frame
	await process_frame
	await physics_frame


## Loads a slot and waits until the data is applied.
func _load(slot := SLOT) -> Error:
	var done := [false]
	var on_loaded := func(loaded_slot: String) -> void: done[0] = loaded_slot == slot
	SaveGame.events.loaded.connect(on_loaded)
	var error := SaveGame.load_game(self, slot)
	if error == OK:
		for i in 10:
			if done[0]:
				break
			await process_frame
		_check(done[0], "a successful load emits loaded within a few frames")
	SaveGame.events.loaded.disconnect(on_loaded)
	return error


func _player() -> Node3D:
	return current_scene.get_node("Player")


func _pickup(index: int) -> Node:
	return current_scene.get_node("Pickups").get_child(index)


## Moves the player somewhere and lets the physics notice.
func _teleport(to: Vector3) -> void:
	_player().global_position = to
	_player().reset_physics_interpolation()
	await _wait(0.3)


func test_round_trip_in_the_same_scene() -> void:
	_check(not SaveGame.has_save(SLOT), "no save to begin with")
	_check(await _load() != OK, "loading an empty slot fails")

	_player().global_position = Vector3(5, 1.1, 5)
	_pickup(0).load_data({"collected": true})
	_check(SaveGame.save_game(self, SLOT) == OK, "save succeeds")
	_check(SaveGame.has_save(SLOT), "the slot now has a save")
	var info := SaveGame.get_save_info(SLOT)
	_check(info.get("scene") == DEMO and info.has("saved_at"), "save info names the scene")

	var old_scene := current_scene
	_player().global_position = Vector3(-9, 1.1, -9)
	_pickup(0).load_data({"collected": false})
	_pickup(1).load_data({"collected": true})
	_check(await _load() == OK, "load succeeds")
	_check(current_scene != old_scene, "loading reloads the scene even when it is open")
	_check(_player().global_position.is_equal_approx(Vector3(5, 1.1, 5)), "position is restored")
	_check(_pickup(0).is_collected and not _pickup(0).visible, "collected pickup is restored")
	_check(not _pickup(1).is_collected and _pickup(1).visible, "uncollected pickup is restored")


func test_load_changes_to_the_saved_scene() -> void:
	await _open(OTHER_SCENE)
	_check(await _load() == OK, "load from another scene succeeds")
	_check(current_scene.scene_file_path == DEMO, "it switches to the saved scene")
	_check(_player().global_position.is_equal_approx(Vector3(5, 1.1, 5)), "and applies the state")
	_check(_pickup(0).is_collected, "to every saveable node")


func test_load_result_outlives_the_scene() -> void:
	var slots: Array[String] = []
	var on_loaded := func(slot: String) -> void: slots.append(slot)
	SaveGame.events.loaded.connect(on_loaded)
	_check(SaveGame.load_game(self, SLOT) == OK, "load_game reports success straight away")
	_check(slots.is_empty(), "and applies the data only once the new scene is ready")
	await process_frame
	await process_frame
	_check(slots == [SLOT], "loaded is emitted once, with the slot, after the scene is replaced")
	SaveGame.events.loaded.disconnect(on_loaded)


## The stock Pickup, Inventory, Health, Respawner and character together.
## The world after a load must not depend on what was open before it.
func _world() -> Dictionary:
	var player: ThirdPersonCharacter = _player()
	var respawner: Respawner = player.get_node("Respawner")
	var pickups: Array[String] = []
	for pickup in current_scene.get_node("Pickups").get_children():
		if not pickup.is_queued_for_deletion():
			pickups.append(str(pickup.name))
	var active: Array[String] = []
	for checkpoint: Checkpoint in current_scene.get_node("Checkpoints").get_children():
		if checkpoint.is_active:
			active.append(str(checkpoint.name))
	return {
		"position": player.global_position.snapped(Vector3.ONE * 0.05),
		"facing": snappedf(player.get_model_yaw(), 0.01),
		"coins": (player.get_node("Inventory") as Inventory).get_count(&"coin"),
		"health": (player.get_node("Health") as Health).current_health,
		"checkpoint":
		str(respawner.current_checkpoint.name) if respawner.current_checkpoint else "",
		"active_checkpoints": active,
		"pickups": pickups,
	}


func test_recipes_compose() -> void:
	await _open(FIXTURE, AWAY)
	var player: ThirdPersonCharacter = _player()
	_check(_world()["pickups"] == ["AtStart", "Far"], "the fixture starts with both pickups")
	await _teleport(Vector3(5, 1.1, 0))
	await _teleport(Vector3(-5, 1.1, 0))
	_check(_world()["coins"] == 1 and _world()["checkpoint"] == "Far", "collected and checkpointed")
	(player.get_node("Health") as Health).damage(3.0)
	player.set_model_yaw(1.0)
	await _teleport(Vector3(0, 1.1, -12))
	_check(SaveGame.save_game(self, SLOT) == OK, "the composed scene saves")
	var saved := _world()

	# Change everything, including walking over what lies at the start.
	await _teleport(Vector3(0, 1.1, 0))
	(_player().get_node("Health") as Health).heal(3.0)
	_check(_world()["coins"] == 2 and _world()["checkpoint"] == "AtStart", "state changed")

	_check(await _load() == OK, "loads into the open scene")
	await _wait(0.3)
	var in_place := _world()
	_check(
		in_place == saved, "loading in place restores the world: %s, saved %s" % [in_place, saved]
	)
	_check(
		"AtStart" in in_place["pickups"] and in_place["coins"] == 1,
		"the pickup at the start position is not collected by the load"
	)

	await _open(OTHER_SCENE)
	_check(await _load() == OK, "loads from another scene")
	await _wait(0.3)
	var fresh := _world()
	_check(fresh == saved, "loading from elsewhere gives the same world: %s" % fresh)


func test_older_save_keeps_new_nodes() -> void:
	# The save from the last test has no entry for the collected "Far" pickup.
	var save: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(SaveGame.get_save_path(SLOT))
	)
	save["version"] = SaveGame.VERSION - 1
	var file := FileAccess.open(SaveGame.get_save_path(SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(save))
	file.close()
	_check(await _load() == OK, "a save from an older version loads")
	_check(
		_world()["pickups"] == ["AtStart", "Far"],
		"and keeps nodes it has no entry for, which may be new in this version"
	)


func test_engine_types_survive() -> void:
	await _open(FIXTURE, AWAY)
	var data := {
		"position": Vector3(1, 2, 3),
		"color": Color(0.1, 0.2, 0.3),
		"count": 7,
		"ratio": 0.5,
		"name": "abc",
		"list": [1, 2, Vector2(3, 4)],
	}
	current_scene.get_node("Probe").data = data.duplicate(true)
	SaveGame.save_game(self, SLOT)
	await _load()
	var loaded: Dictionary = current_scene.get_node("Probe").data
	_check(loaded == data, "vectors, colours, ints and nested values round-trip")
	_check(typeof(loaded.get("count")) == TYPE_INT, "ints stay ints")


func test_missing_and_damaged_saves() -> void:
	print("(errors about save files are expected below)")
	var scene := current_scene
	var path := SaveGame.get_save_path(SLOT)

	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not json at all")
	file.close()
	_check(SaveGame.load_game(self, SLOT) != OK, "a damaged save is rejected")
	_check(SaveGame.get_save_info(SLOT).is_empty(), "and has no info")

	# Valid JSON with the wrong shape, from issue #10 and around it.
	var damaged: Array[String] = [
		'{"version":"2","scene":"x","saved_at":"t","nodes":{}}',
		'{"version":1,"scene":5,"saved_at":"t","nodes":{}}',
		'{"version":1,"scene":"%s","saved_at":"t","nodes":[1]}' % DEMO,
		'{"version":1,"scene":"%s","saved_at":"t","nodes":{"Player":5}}' % DEMO,
		'{"version":1.5,"scene":"%s","saved_at":"t","nodes":{}}' % DEMO,
		'{"version":-1,"scene":"%s","saved_at":"t","nodes":{}}' % DEMO,
		'{"version":1,"scene":"%s","nodes":{}}' % DEMO,
		"[1, 2, 3]",
	]
	for text in damaged:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		_check(SaveGame.get_save_info(SLOT).is_empty(), "no info for %s" % text)
		_check(SaveGame.load_game(self, SLOT) != OK, "load refuses %s" % text)

	file = FileAccess.open(path, FileAccess.WRITE)
	var newer := {"version": SaveGame.VERSION + 1, "scene": DEMO, "saved_at": "", "nodes": {}}
	file.store_string(JSON.stringify(newer))
	file.close()
	_check(SaveGame.load_game(self, SLOT) != OK, "a save from a newer version is rejected")

	file = FileAccess.open(path, FileAccess.WRITE)
	var gone := {
		"version": SaveGame.VERSION, "scene": "res://nowhere.tscn", "saved_at": "", "nodes": {}
	}
	file.store_string(JSON.stringify(gone))
	file.close()
	_check(
		SaveGame.load_game(self, SLOT) != OK, "a save of a scene that no longer exists is rejected"
	)
	await process_frame
	await process_frame
	_check(current_scene == scene, "a rejected save changes nothing")

	SaveGame.delete_save(SLOT)
	_check(not SaveGame.has_save(SLOT), "delete removes the save")
