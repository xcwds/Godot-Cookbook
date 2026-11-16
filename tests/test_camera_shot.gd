extends "res://tests/support/test_case.gd"
## Headless test for recipes/camera_shot. Run with:
##   godot --headless --path . -s tests/test_camera_shot.gd

const DIRECTOR := preload("res://recipes/camera_shot/camera_director.tscn")
const STEP := 0.05

var _events: Array = []


func _before_each() -> void:
	_events = []


func _make_game_camera(at: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_spawn(camera)
	camera.global_position = at
	camera.fov = 70.0
	camera.make_current()
	return camera


func _make_shot(at: Vector3, yaw := 0.0, blend_time := 1.0, hold_time := 1.0) -> CameraShot:
	var shot := CameraShot.new()
	shot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	shot.blend_time = blend_time
	shot.hold_time = hold_time
	shot.fov = 40.0
	_spawn(shot)
	shot.global_position = at
	shot.rotation.y = yaw
	return shot


func _make_director() -> CameraDirector:
	var director: CameraDirector = DIRECTOR.instantiate()
	_spawn(director)
	director.shot_started.connect(func(shot: CameraShot) -> void: _events.append(["start", shot]))
	director.shot_finished.connect(func(shot: CameraShot) -> void: _events.append(["end", shot]))
	director.sequence_finished.connect(func() -> void: _events.append("finished"))
	director.input_locked.connect(func() -> void: _events.append("locked"))
	director.input_unlocked.connect(func() -> void: _events.append("unlocked"))
	return director


func _run(director: CameraDirector, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		director._process(STEP)


func test_blends_to_the_shot_within_the_blend_time() -> void:
	var game_camera := _make_game_camera(Vector3(0, 2, 10))
	var shot := _make_shot(Vector3(10, 4, 0), PI / 2.0)
	var director := _make_director()
	var camera := director.get_camera()
	_check(game_camera.current and not director.is_playing(), "idle until played")
	director.play(shot)
	_check(camera.current and director.is_playing(), "director's camera takes the view")
	_check(camera.global_position.is_equal_approx(Vector3(0, 2, 10)), "starts where the view was")
	_check_eq(camera.fov, 70.0, "starts with the previous field of view")
	_check_eq(director.get_current_shot(), shot, "current shot is reported")
	_run(director, 0.5)
	var halfway := camera.global_position
	_check(
		halfway.is_equal_approx(Vector3(5, 3, 5)), "halfway at half the blend time: %s" % halfway
	)
	_check(is_equal_approx(camera.global_rotation.y, PI / 4.0), "rotation is halfway too")
	_check(is_equal_approx(camera.fov, 55.0), "and so is the field of view")
	_run(director, 0.5)
	_check(camera.global_transform.is_equal_approx(shot.global_transform), "arrives on time")
	_check(is_equal_approx(camera.fov, 40.0), "with the shot's field of view")
	_check_eq(_events, ["locked", ["start", shot]], "locked input and started the shot")


func test_easing_shapes_the_blend() -> void:
	_make_game_camera(Vector3.ZERO)
	var shot := _make_shot(Vector3(10, 0, 0))
	var director := _make_director()
	director.easing = 1.0
	director.play(shot)
	_run(director, 0.25)
	_check(is_equal_approx(director.get_camera().global_position.x, 2.5), "linear at 1.0")
	director.stop()
	director.easing = -2.0
	director.play(shot)
	_run(director, 0.25)
	_check(director.get_camera().global_position.x < 2.0, "eases in below zero")


func test_returns_to_the_previous_camera_after_the_sequence() -> void:
	var game_camera := _make_game_camera(Vector3(0, 2, 10))
	var first := _make_shot(Vector3(10, 0, 0), 0.0, 1.0, 0.5)
	# A hold that does not end on a step, so rounding cannot move its end.
	var second := _make_shot(Vector3(20, 0, 0), 0.0, 0.5, 0.52)
	var director := _make_director()
	director.return_blend_time = 1.0
	var camera := director.get_camera()
	director.play_sequence([first, second])
	_run(director, 1.25)
	_check(camera.global_position.is_equal_approx(Vector3(10, 0, 0)), "holds the first shot")
	_run(director, 0.5)
	_check_eq(director.get_current_shot(), second, "moves on to the second shot")
	_check(camera.global_position.x > 10.0, "blending from the first shot, not from the start")
	_run(director, 0.7)
	_check(camera.global_position.is_equal_approx(Vector3(20, 0, 0)), "reaches the second shot")
	_run(director, 0.1)
	_check(director.is_playing() and camera.current, "returning is part of the sequence")
	# The gameplay camera moves while the director blends back to it.
	game_camera.global_position = Vector3(0, 2, 30)
	_run(director, 0.5)
	_check(camera.global_position.is_equal_approx(Vector3(10, 1, 15)), "returns to where it is now")
	_run(director, 0.55)
	_check(game_camera.current and not camera.current, "previous camera is current again")
	_check(not director.is_playing(), "no longer playing")
	var expected := ["locked", ["start", first], ["end", first], ["start", second], ["end", second]]
	_check_eq(_events, expected + ["unlocked", "finished"], "signals in order")


func test_stop_mid_blend_restores_the_previous_camera() -> void:
	var game_camera := _make_game_camera(Vector3(0, 2, 10))
	var director := _make_director()
	director.play_sequence([_make_shot(Vector3(10, 0, 0)), _make_shot(Vector3(20, 0, 0))])
	_run(director, 0.5)
	director.stop()
	director.stop()
	_check(game_camera.current and not director.is_playing(), "view is back at once")
	_run(director, 3.0)
	_check_eq(_events.count("finished"), 1, "sequence_finished is emitted once")
	_check_eq(_events.count("unlocked"), 1, "input_unlocked is emitted once")
	_check_eq(_events.size(), 4, "no shot was reported as finished: %s" % [_events])


func test_stop_with_a_blend() -> void:
	var game_camera := _make_game_camera(Vector3(0, 0, 0))
	var director := _make_director()
	director.easing = 1.0
	director.play(_make_shot(Vector3(10, 0, 0), 0.0, 1.0, -1.0))
	_run(director, 5.0)
	_check(director.is_playing(), "a negative hold time holds until stopped")
	director.stop(0.5)
	_check(director.is_playing() and not game_camera.current, "still blending back")
	_run(director, 0.25)
	_check(is_equal_approx(director.get_camera().global_position.x, 5.0), "halfway back")
	_run(director, 0.3)
	_check(game_camera.current and not director.is_playing(), "then the view is back")
	_check_eq(_events.count("finished"), 1, "sequence_finished is emitted once")


func test_playing_again_replaces_the_shots() -> void:
	var game_camera := _make_game_camera(Vector3.ZERO)
	var first := _make_shot(Vector3(10, 0, 0))
	var other := _make_shot(Vector3(0, 10, 0), 0.0, 0.0, 0.5)
	var director := _make_director()
	director.return_blend_time = 0.0
	director.play(first)
	_run(director, 0.5)
	director.play(other)
	_check_eq(_events.count("locked"), 1, "input is locked once")
	_check(not _events.has("finished"), "the first sequence does not finish")
	var at := director.get_camera().global_position
	_check(at.is_equal_approx(Vector3(0, 10, 0)), "a blend time of 0 cuts to the shot")
	_run(director, 0.55)
	_check(game_camera.current, "returns to the gameplay camera, not to the first shot")
	_check_eq(_events.count("finished"), 1, "one sequence_finished at the very end")


func test_look_at_target_is_tracked() -> void:
	_make_game_camera(Vector3.ZERO)
	var target := Node3D.new()
	target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_spawn(target)
	target.global_position = Vector3(10, 0, 0)
	var shot := _make_shot(Vector3.ZERO, 0.0, 0.0, -1.0)
	shot.look_at_target = target
	var director := _make_director()
	director.play(shot)
	var camera := director.get_camera()
	_check((-camera.global_basis.z).is_equal_approx(Vector3.RIGHT), "looks at the target")
	target.global_position = Vector3(0, 0, 10)
	_run(director, STEP)
	_check((-camera.global_basis.z).is_equal_approx(Vector3.BACK), "follows it when it moves")
	target.global_position = Vector3(0, 5, 0)
	_run(director, STEP)
	_check(camera.global_basis.is_finite(), "a target straight above does not break the view")
	target.free()
	_run(director, STEP)
	_check(director.is_playing(), "a freed target is ignored")
	director.stop()


func test_locks_input_can_be_turned_off() -> void:
	_make_game_camera(Vector3.ZERO)
	var director := _make_director()
	director.locks_input = false
	director.play(_make_shot(Vector3(1, 0, 0)))
	director.stop()
	_check_eq(_events.count("locked") + _events.count("unlocked"), 0, "no input signals")
	_check_eq(_events.count("finished"), 1, "sequence_finished still comes")


func test_freed_nodes_do_not_break_playback() -> void:
	var game_camera := _make_game_camera(Vector3.ZERO)
	var first := _make_shot(Vector3(10, 0, 0))
	var second := _make_shot(Vector3(20, 0, 0), 0.0, 0.0, 0.2)
	var director := _make_director()
	director.play_sequence([first, second])
	_run(director, 0.5)
	first.free()
	_run(director, STEP)
	_check_eq(director.get_current_shot(), second, "a freed shot is skipped")
	game_camera.free()
	_run(director, 1.0)
	_check(not director.is_playing(), "ends without the camera it took the view from")
	_check_eq(_events.count("finished"), 1, "and still reports the end")
	director.play_sequence([])
	_check(not director.is_playing(), "an empty sequence does nothing")


func test_freeing_the_director_gives_the_view_back() -> void:
	var game_camera := _make_game_camera(Vector3.ZERO)
	var director := _make_director()
	director.play(_make_shot(Vector3(1, 0, 0)))
	director.free()
	_check(game_camera.current, "previous camera is current again")
	_check_eq(_events.count("unlocked"), 1, "input is unlocked")
