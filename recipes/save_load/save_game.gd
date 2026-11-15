class_name SaveGame
extends RefCounted
## Saves and loads the state of the current scene to a JSON file per slot.
##
## Any node in the [code]saveable[/code] group that has these two methods
## takes part:
## [codeblock]
## func save_data() -> Dictionary
## func load_data(data: Dictionary) -> void
## [/codeblock]
## The dictionary can hold numbers, strings, arrays, dictionaries and engine
## types such as Vector3 and Color. It cannot hold nodes or resources.

const GROUP := &"saveable"
const SAVE_DIR := "user://saves"
## Bump when the shape of the save data changes, and convert old saves in
## [method _read].
const VERSION := 1
const DEFAULT_SLOT := "slot_1"


## Writes the state of every saveable node in the current scene to a slot.
static func save_game(tree: SceneTree, slot := DEFAULT_SLOT) -> Error:
	var scene := tree.current_scene
	if scene == null:
		return ERR_UNCONFIGURED
	var nodes := {}
	for node in tree.get_nodes_in_group(GROUP):
		if not scene.is_ancestor_of(node):
			continue
		if not node.has_method(&"save_data"):
			push_warning(
				"%s is in the '%s' group but has no save_data()." % [node.get_path(), GROUP]
			)
			continue
		nodes[str(scene.get_path_to(node))] = node.save_data()
	var save := {
		"version": VERSION,
		"scene": scene.scene_file_path,
		"saved_at": Time.get_datetime_string_from_system(),
		"nodes": JSON.from_native(nodes),
	}

	var error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if error != OK:
		return error
	# Write to a temporary file first, so a crash cannot leave half a save.
	var path := get_save_path(slot)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(save, "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)


## Restores a slot. Changes to the saved scene first if it is not the
## current one, so this must be awaited:
## [codeblock]
## var error := await SaveGame.load_game(get_tree())
## [/codeblock]
static func load_game(tree: SceneTree, slot := DEFAULT_SLOT) -> Error:
	var save := _read(slot)
	if save.is_empty():
		return ERR_FILE_CANT_READ

	var scene_path: String = save["scene"]
	if tree.current_scene == null or tree.current_scene.scene_file_path != scene_path:
		var error := tree.change_scene_to_file(scene_path)
		if error != OK:
			return error
		# The new scene is added at the end of the frame; let it get ready.
		await tree.process_frame
		await tree.process_frame

	var scene := tree.current_scene
	var nodes: Dictionary = JSON.to_native(save["nodes"])
	for node in tree.get_nodes_in_group(GROUP):
		var key := str(scene.get_path_to(node))
		if nodes.has(key) and node.has_method(&"load_data"):
			node.load_data(nodes[key])
	return OK


static func has_save(slot := DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(get_save_path(slot))


static func delete_save(slot := DEFAULT_SLOT) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(get_save_path(slot))


## The scene and time of a save without loading it, for a load menu.
## Empty if the slot has no readable save.
static func get_save_info(slot := DEFAULT_SLOT) -> Dictionary:
	var save := _read(slot)
	if save.is_empty():
		return {}
	return {"scene": save["scene"], "saved_at": save["saved_at"]}


static func get_save_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot.validate_filename() + ".json")


## Reads and checks a save file. Returns an empty dictionary if it is
## missing, damaged, or from a newer version of the game.
static func _read(slot: String) -> Dictionary:
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("SaveGame: %s is not a valid save file." % path)
		return {}
	var save: Dictionary = parsed
	for key: String in ["version", "scene", "saved_at", "nodes"]:
		if not save.has(key):
			push_error("SaveGame: %s is missing '%s'." % [path, key])
			return {}
	if save["version"] > VERSION:
		push_error("SaveGame: %s was made by a newer version of the game." % path)
		return {}
	return save
