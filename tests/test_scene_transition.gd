extends "res://tests/support/test_case.gd"
## Headless test for recipes/scene_transition. Run with:
##   godot --headless --path . -s tests/test_scene_transition.gd

const ROOM_A := "res://recipes/scene_transition/demo.tscn"
const ROOM_B := "res://recipes/scene_transition/demo_room_b.tscn"


func _before_all() -> void:
	change_scene_to_file(ROOM_A)
	await process_frame


func test_changes_scene_and_cleans_up() -> void:
	paused = true
	var transition := SceneTransition.change_scene(self, ROOM_B)
	_check(current_scene.scene_file_path == ROOM_A, "the old scene stays during the fade out")
	await transition.finished
	_check(current_scene.scene_file_path == ROOM_B, "the new scene is current afterwards")
	_check(not paused, "the tree is unpaused")
	await process_frame
	_check(not root.has_node("SceneTransition"), "the transition removes itself")


func test_second_call_is_ignored_while_running() -> void:
	var first := SceneTransition.change_scene(self, ROOM_A)
	var second := SceneTransition.change_scene(self, ROOM_B)
	_check(first == second, "a call during a transition returns the running one")
	await first.finished
	_check(current_scene.scene_file_path == ROOM_A, "and the first destination wins")
	await process_frame


func test_minimum_load_time_shows_progress() -> void:
	var started := Time.get_ticks_msec()
	var transition := SceneTransition.change_scene(self, ROOM_B, 0.6)
	var saw_progress := [false]
	var watch := func() -> void:
		if is_instance_valid(transition) and transition.get_node("%Progress").visible:
			saw_progress[0] = true
	process_frame.connect(watch)
	await transition.finished
	process_frame.disconnect(watch)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	_check(seconds >= 0.6, "waits at least the minimum load time, took %.2f s" % seconds)
	_check(saw_progress[0], "the progress bar appears on a slow load")
	await process_frame


func test_missing_scene_fails_and_keeps_the_old_one() -> void:
	print("(errors about a missing scene are expected below)")
	var before := current_scene
	var transition := SceneTransition.change_scene(self, "res://does_not_exist.tscn")
	await transition.failed
	_check(current_scene == before, "a scene that cannot be loaded leaves the old one in place")
	await process_frame
	_check(not root.has_node("SceneTransition"), "and the transition still removes itself")
