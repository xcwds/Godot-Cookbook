class_name SceneTransition
extends CanvasLayer
## Changes scene with a fade, loading the next scene in the background and
## showing a progress bar if that takes a while.
##
## No setup is needed. From anywhere:
## [codeblock]
## SceneTransition.change_scene(get_tree(), "res://levels/level_2.tscn")
## [/codeblock]

## Emitted when the new scene is showing and the fade has finished.
signal finished
## Emitted if the scene could not be loaded. The old scene stays.
signal failed

## The transition scene, next to this script wherever the recipe was copied.
const SCENE_FILE := "scene_transition.tscn"
const NODE_NAME := "SceneTransition"

## Seconds for each fade.
@export var fade_duration := 0.3
## The progress bar only appears if loading takes longer than this.
@export var show_progress_after := 0.3

@onready var _cover: ColorRect = %Cover
@onready var _progress: ProgressBar = %Progress


## Fades out, switches to the scene at [param path] and fades in. Returns
## the transition so you can await [signal finished]. A call made while a
## transition is running is ignored and returns the running one.
## [param minimum_load_time] keeps the loading screen up for at least that
## many seconds.
static func change_scene(
	tree: SceneTree, path: String, minimum_load_time := 0.0
) -> SceneTransition:
	var running := tree.root.get_node_or_null(NODE_NAME) as SceneTransition
	if running != null:
		return running
	var transition: SceneTransition = load(get_scene_path()).instantiate()
	transition.name = NODE_NAME
	tree.root.add_child(transition)
	transition._run(path, minimum_load_time)
	return transition


## Where [constant SCENE_FILE] is: in the folder of this script, so the recipe
## keeps working when its folder is moved or copied by hand.
static func get_scene_path() -> String:
	var script: Script = SceneTransition
	return script.resource_path.get_base_dir().path_join(SCENE_FILE)


func _ready() -> void:
	# Keep going if the game is paused, for example from a pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover.modulate.a = 0.0
	_progress.hide()


func _run(path: String, minimum_load_time: float) -> void:
	await _fade(1.0)

	var packed := await _load(path, minimum_load_time)
	if packed == null:
		push_error("SceneTransition: could not load '%s'." % path)
		await _fade(0.0)
		failed.emit()
		queue_free()
		return

	var tree := get_tree()
	tree.paused = false
	if tree.change_scene_to_packed(packed) != OK:
		push_error("SceneTransition: could not open '%s'." % path)
		await _fade(0.0)
		failed.emit()
		queue_free()
		return
	# Emitted once the new scene is the current one and is ready.
	await tree.scene_changed

	_progress.hide()
	await _fade(0.0)
	finished.emit()
	queue_free()


func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_cover, "modulate:a", alpha, fade_duration)
	await tween.finished


func _load(path: String, minimum_load_time: float) -> PackedScene:
	if ResourceLoader.load_threaded_request(path) != OK:
		return null
	var elapsed := 0.0
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if (
			status != ResourceLoader.THREAD_LOAD_IN_PROGRESS
			and status != ResourceLoader.THREAD_LOAD_LOADED
		):
			return null
		var loaded := status == ResourceLoader.THREAD_LOAD_LOADED
		var fraction: float = 1.0 if loaded else progress[0]
		if minimum_load_time > 0.0:
			fraction = minf(fraction, elapsed / minimum_load_time)
		_progress.value = fraction
		_progress.visible = elapsed >= show_progress_after
		if loaded and elapsed >= minimum_load_time:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return ResourceLoader.load_threaded_get(path) as PackedScene
