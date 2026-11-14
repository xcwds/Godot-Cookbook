extends SceneTree
## Loads every scene and script under a folder of the current project and
## fails if any does not load. Used to check recipes copied into an empty
## project. Run with:
##   godot --headless --path <project> -s <cookbook>/tools/load_all.gd -- addons/cookbook


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := "res://" + (args[0] if args.size() > 0 else "")
	var failures := 0
	var count := 0
	for path in _files(folder):
		if path.get_extension() in ["tscn", "gd"]:
			count += 1
			if ResourceLoader.load(path) == null:
				printerr("FAIL: could not load " + path)
				failures += 1
	if count == 0:
		printerr("FAIL: nothing to load under " + folder)
		failures += 1
	if failures == 0:
		print("loaded %d scenes and scripts" % count)
	quit(1 if failures > 0 else 0)


func _files(folder: String) -> PackedStringArray:
	var result := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		result.append(folder.path_join(file))
	for directory in DirAccess.get_directories_at(folder):
		result.append_array(_files(folder.path_join(directory)))
	return result
