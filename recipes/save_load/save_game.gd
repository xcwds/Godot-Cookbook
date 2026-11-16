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
##
## Loading always reloads the saved scene and then applies the data, so
## anything that is not saved is as the scene starts. A saveable node that
## has no entry in the save was gone when it was saved, and is removed: its
## optional [code]load_missing()[/code] is called, or else it is freed.

const GROUP := &"saveable"
const SAVE_DIR := "user://saves"
## Bump when the shape of the save data changes, and convert old saves in
## [method _migrate]. Bump it too when a game update adds saveable nodes to a
## scene: nodes missing from an older save are kept rather than removed.
const VERSION := 1
const DEFAULT_SLOT := "slot_1"

## Signals about loads. They outlive the scene that asked for the load,
## which is replaced by it:
## [codeblock]
## SaveGame.events.loaded.connect(func(slot: String) -> void: print("loaded ", slot))
## [/codeblock]
static var events := Events.new()


## Writes the state of every saveable node in the current scene to a slot.
static func save_game(tree: SceneTree, slot := DEFAULT_SLOT) -> Error:
	var scene := tree.current_scene
	if scene == null:
		return ERR_UNCONFIGURED
	var nodes := {}
	for node in tree.get_nodes_in_group(GROUP):
		if node != scene and not scene.is_ancestor_of(node):
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
	var stored := file.store_string(JSON.stringify(save, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	# A full disk leaves a short temporary file: keep the previous save.
	if not stored or (write_error != OK and write_error != ERR_FILE_EOF):
		DirAccess.remove_absolute(path + ".tmp")
		push_error("SaveGame: could not write %s." % path)
		return ERR_FILE_CANT_WRITE
	return DirAccess.rename_absolute(path + ".tmp", path)


## Restores a slot by reloading the saved scene, also when it is the
## current one, and then applying the data. Returns an error straight away if
## the slot cannot be read. On [constant OK] the current scene is replaced at
## the end of this frame and [signal Events.loaded] is emitted once the data
## is applied, so code after the call in the replaced scene does not see the
## result; connect to [member events] for that.
static func load_game(tree: SceneTree, slot := DEFAULT_SLOT) -> Error:
	var save := _read(slot)
	if save.is_empty():
		return ERR_FILE_CANT_READ
	var scene_path: String = save["scene"]
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("SaveGame: the saved scene %s does not exist." % scene_path)
		return ERR_FILE_NOT_FOUND
	var packed: PackedScene = load(scene_path)
	var scene := packed.instantiate() if packed != null else null
	if scene == null:
		return ERR_CANT_CREATE

	# The scene's ready signal comes after every node in it is ready and
	# before its first physics tick, so nothing at the start position can
	# fire before the saved positions are in place.
	scene.ready.connect(_apply.bind(scene, save, slot), CONNECT_ONE_SHOT)
	return tree.change_scene_to_node(scene)


static func _apply(scene: Node, save: Dictionary, slot: String) -> void:
	var nodes: Dictionary = save["nodes"]
	# A save from an older version may predate saveable nodes added since,
	# so only a save of this version can say that a node was gone.
	var can_remove: bool = save["version"] == VERSION
	# Deepest first, as _ready() runs: a SaveTransform under a character is
	# applied before the character, which can then restore its own facing.
	var saveable := scene.get_tree().get_nodes_in_group(GROUP)
	saveable.reverse()
	for node in saveable:
		if node != scene and not scene.is_ancestor_of(node):
			continue
		var key := str(scene.get_path_to(node))
		if nodes.has(key):
			if node.has_method(&"load_data"):
				node.load_data(nodes[key])
		elif can_remove:
			print_verbose("SaveGame: %s is not in the save, so it is removed." % key)
			if node.has_method(&"load_missing"):
				node.load_missing()
			else:
				node.queue_free()
		else:
			print_verbose("SaveGame: %s is not in the older save, so it is kept." % key)
	events.loaded.emit(slot)


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
## missing, damaged, or from a newer version of the game. Otherwise
## [code]nodes[/code] holds engine types again and maps each node path to a
## dictionary, and an older save has been through [method _migrate].
static func _read(slot: String) -> Dictionary:
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	# The text is parsed as data only, so a save file cannot run code.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("SaveGame: %s is not a valid save file." % path)
		return {}
	var save: Dictionary = parsed
	var problem := _check_save(save)
	if problem != "":
		push_error("SaveGame: %s is damaged: %s." % [path, problem])
		return {}
	save["version"] = int(save["version"])
	if save["version"] > VERSION:
		push_error("SaveGame: %s was made by a newer version of the game." % path)
		return {}
	save["nodes"] = JSON.to_native(save["nodes"])
	if save["version"] < VERSION:
		save = _migrate(save)
	return save


## What is wrong with a parsed save, or an empty string if nothing is.
static func _check_save(save: Dictionary) -> String:
	var types := {
		"version": [TYPE_INT, TYPE_FLOAT],
		"scene": [TYPE_STRING],
		"saved_at": [TYPE_STRING],
		"nodes": [TYPE_DICTIONARY],
	}
	for key: String in types:
		if not save.has(key):
			return "'%s' is missing" % key
		if typeof(save[key]) not in types[key]:
			return "'%s' has the wrong type" % key
	var version: float = save["version"]
	if version < 0.0 or version != floorf(version):
		return "'version' is not a whole number"
	var nodes: Variant = JSON.to_native(save["nodes"])
	if not nodes is Dictionary:
		return "'nodes' is not a dictionary"
	for key: Variant in nodes:
		if not key is String or not nodes[key] is Dictionary:
			return "the entry for '%s' is not a dictionary" % [key]
	return ""


## Converts a save from an older [constant VERSION] to the current layout.
## [code]save["nodes"][/code] maps node paths to their data. Keep
## [code]save["version"][/code] as it is: an older save may predate saveable
## nodes added since, so nodes it has no entry for are kept, not removed.
## [codeblock]
## if save["version"] < 2:
##     for path: String in save["nodes"]:
##         var data: Dictionary = save["nodes"][path]
##         if data.has("hp"):
##             data["current"] = data["hp"]
## [/codeblock]
static func _migrate(save: Dictionary) -> Dictionary:
	return save


## Holds the signals of [member SaveGame.events].
class Events:
	extends RefCounted

	## Emitted after a load has replaced the scene and applied the saved data.
	signal loaded(slot: String)
