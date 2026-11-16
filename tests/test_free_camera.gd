extends "res://tests/support/test_case.gd"
## Headless test for recipes/free_camera. Run with:
##   godot --headless --path . -s tests/test_free_camera.gd

const FREE_CAMERA := preload("res://recipes/free_camera/free_camera.tscn")
const PAUSE_MENU := preload("res://recipes/pause_menu/pause_menu.tscn")
const ACTIONS: Array[StringName] = [&"move_up", &"move_right", &"camera_up", &"sprint"]


func _after_each() -> void:
	for action in ACTIONS:
		Input.action_release(action)
	paused = false


func _make(pause_game := false) -> FreeCamera:
	var rig: FreeCamera = FREE_CAMERA.instantiate()
	rig.pause_game = pause_game
	rig.acceleration = 0.0
	_spawn(rig)
	return rig


func _make_game_camera(at: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_spawn(camera)
	camera.global_position = at
	camera.make_current()
	return camera


## Flies forward for a second in steps of 1 / fps and returns where it ended.
func _fly_for_a_second(fps: int, acceleration: float) -> Vector3:
	var rig := _make()
	rig.acceleration = acceleration
	rig.activate()
	Input.action_press(&"move_up")
	for i in fps:
		rig._process(1.0 / fps)
	Input.action_release(&"move_up")
	var end := rig.global_position
	rig.deactivate()
	return end


func test_starts_at_the_previous_camera_and_gives_the_view_back() -> void:
	var game_camera := _make_game_camera(Vector3(3, 2, 5))
	game_camera.rotation = Vector3(-0.4, 1.2, 0.0)
	game_camera.fov = 50.0
	var rig := _make()
	var events: Array = []
	rig.activated.connect(func() -> void: events.append("on"))
	rig.deactivated.connect(func() -> void: events.append("off"))
	_check(game_camera.current and not rig.active, "does nothing until activated")
	rig.activate()
	rig.activate()
	_check(rig.get_camera().current and not game_camera.current, "takes the view")
	_check(rig.global_position.is_equal_approx(Vector3(3, 2, 5)), "starts where the view was")
	_check(is_equal_approx(rig.yaw, 1.2) and is_equal_approx(rig.pitch, -0.4), "looks the same way")
	var same_view := rig.get_camera().global_basis.is_equal_approx(game_camera.global_basis)
	_check(same_view, "camera basis matches the previous camera")
	_check_eq(rig.get_camera().fov, 50.0, "copies the field of view")
	rig.global_position = Vector3(50, 50, 50)
	rig.deactivate()
	rig.deactivate()
	_check(game_camera.current and not rig.get_camera().current, "gives the view back")
	_check(game_camera.global_position.is_equal_approx(Vector3(3, 2, 5)), "game camera not moved")
	_check_eq(events, ["on", "off"], "signals are emitted once each")


func test_works_without_a_previous_camera() -> void:
	var rig := _make()
	rig.position = Vector3(1, 2, 3)
	rig.activate()
	_check(rig.get_camera().current, "takes the view")
	_check(rig.global_position.is_equal_approx(Vector3(1, 2, 3)), "stays where it was placed")
	rig.deactivate()
	_check(not rig.get_camera().current, "lets go of the view")


func test_previous_camera_freed_while_flying() -> void:
	var game_camera := _make_game_camera(Vector3.ZERO)
	var rig := _make()
	rig.activate()
	game_camera.free()
	rig.deactivate()
	_check(not rig.active, "deactivates without the camera it took the view from")


func test_moves_where_it_looks() -> void:
	var rig := _make()
	rig.speed = 10.0
	rig.activate()
	rig.set_look(PI / 2.0, 0.0)
	Input.action_press(&"move_up")
	rig._process(0.1)
	_check(rig.global_position.is_equal_approx(Vector3(-1, 0, 0)), "forward follows the yaw")
	Input.action_release(&"move_up")
	Input.action_press(&"camera_up")
	rig._process(0.1)
	_check(rig.global_position.is_equal_approx(Vector3(-1, 1, 0)), "camera_up rises")
	Input.action_press(&"sprint")
	rig.fast_multiplier = 3.0
	rig._process(0.1)
	_check(rig.global_position.is_equal_approx(Vector3(-1, 4, 0)), "sprint multiplies the speed")
	Input.action_release(&"sprint")
	Input.action_release(&"camera_up")
	rig.deactivate()
	Input.action_press(&"move_up")
	rig._process(0.1)
	_check(rig.global_position.is_equal_approx(Vector3(-1, 4, 0)), "does not move when inactive")


func test_movement_does_not_depend_on_frame_rate() -> void:
	for acceleration: float in [0.0, 10.0]:
		var slow := _fly_for_a_second(60, acceleration)
		var fast := _fly_for_a_second(144, acceleration)
		_check(slow.z < -6.0, "flies forward with acceleration %s (at %s)" % [acceleration, slow])
		_check(
			slow.distance_to(fast) < 0.001,
			"60 and 144 fps end together with acceleration %s: %s, %s" % [acceleration, slow, fast]
		)


func test_mouse_wheel_changes_speed() -> void:
	var rig := _make()
	rig.speed = 8.0
	rig.speed_step = 2.0
	rig.speed_max = 20.0
	rig.activate()
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	rig._unhandled_input(wheel)
	_check_eq(rig.speed, 16.0, "wheel up speeds up")
	rig._unhandled_input(wheel)
	_check_eq(rig.speed, 20.0, "speed stops at speed_max")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	rig._unhandled_input(wheel)
	_check_eq(rig.speed, 10.0, "wheel down slows down")
	rig.deactivate()
	rig._unhandled_input(wheel)
	_check_eq(rig.speed, 10.0, "wheel is ignored when inactive")


func test_pause_game_pauses_while_active() -> void:
	var rig := _make(true)
	rig.activate()
	_check(paused, "tree is paused while the camera is active")
	_check(rig.can_process(), "camera keeps processing while paused")
	paused = false
	rig._process(0.016)
	_check(paused, "pauses again if something else resumes the game")
	rig.deactivate()
	_check(not paused, "tree runs again afterwards")
	paused = true
	rig.activate()
	rig.deactivate()
	_check(paused, "a tree that was already paused stays paused")
	paused = false
	rig.pause_game = false
	rig.activate()
	_check(not paused, "spectator mode leaves the tree running")
	rig.deactivate()


func test_toggle_action() -> void:
	var rig := _make(true)
	await _press(&"free_camera")
	_check(rig.active and paused, "action turns the camera on")
	await _press(&"free_camera")
	_check(not rig.active and not paused, "action turns it off, also while paused")
	rig.toggle_action = &""
	await _press(&"free_camera")
	_check(not rig.active, "an empty toggle_action turns the action off")


func test_leaves_the_pause_menu_alone() -> void:
	var menu: PauseMenu = PAUSE_MENU.instantiate()
	menu.capture_mouse = false
	_spawn(menu)
	var rig := _make(true)
	menu.pause()
	await _press(&"free_camera")
	_check(not rig.active, "toggle is ignored while something else has paused the game")
	menu.resume()
	rig.pause_game = false
	rig.speed = 10.0
	rig.activate()
	menu.pause()
	Input.action_press(&"move_up")
	rig._process(0.1)
	_check(rig.global_position.is_zero_approx(), "spectator camera holds still under the menu")
	await _press(&"free_camera")
	_check(rig.active, "and cannot be toggled under the menu")
	menu.resume()
	rig._process(0.1)
	_check(rig.global_position.is_equal_approx(Vector3(0, 0, -1)), "flies again after resume")
	rig.deactivate()


func test_mouse_mode_is_restored() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("(mouse mode cannot be changed on this display; skipping that check)")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rig := _make()
	rig.activate()
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse is captured while flying")
	rig.deactivate()
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "previous mouse mode is restored")


func test_freeing_an_active_camera_unpauses() -> void:
	var rig := _make(true)
	rig.activate()
	rig.free()
	_check(not paused, "tree is not left paused")


func test_collision_stops_at_walls() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 1)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 0, -5)
	_spawn(wall)
	await _wait_physics_frames(2)
	var rig := _make()
	rig.speed = 10.0
	rig.collision_radius = 0.5
	rig.activate()
	Input.action_press(&"move_up")
	for i in 20:
		rig._process(0.1)
	_check(rig.global_position.z < -10.0, "flies through walls with collision_mask 0")
	rig.global_position = Vector3.ZERO
	rig.collision_mask = 1
	for i in 20:
		rig._process(0.1)
	var z := rig.global_position.z
	_check(z < -3.5 and z > -4.05, "stops a radius short of the wall (z = %s)" % z)
	Input.action_press(&"move_right")
	var x := rig.global_position.x
	for i in 5:
		rig._process(0.1)
	_check(rig.global_position.x > x + 2.0, "slides along the wall")
	_check(rig.global_position.z > -4.05, "and stays out of it")
	# Into the wall at a shallow angle, in many small steps.
	rig.set_look(-PI / 2.0 + 0.05, 0.0)
	Input.action_release(&"move_right")
	rig.global_position.x = -9.0
	x = rig.global_position.x
	for i in 300:
		rig._process(0.004)
	_check(rig.global_position.x > x + 5.0, "glides along the wall at a shallow angle")
	_check(
		rig.global_position.z > -4.05, "without getting through (z = %s)" % rig.global_position.z
	)
	rig.deactivate()
