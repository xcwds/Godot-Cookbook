extends SceneTree
## Headless test for recipes/lock_on. Run with:
##   godot --headless --path . -s tests/test_lock_on.gd

const ORBIT_CAMERA := preload("res://recipes/orbit_camera/orbit_camera.tscn")

var _failures := 0
var _player: Node3D
var _camera: OrbitCamera
var _lock_on: LockOn


func _initialize() -> void:
	await process_frame
	# A player at the origin, with a camera behind it looking along -Z.
	_player = Node3D.new()
	root.add_child(_player)
	_camera = ORBIT_CAMERA.instantiate()
	_camera.target = _player
	_camera.follow_speed = 0.0
	root.add_child(_camera)
	_lock_on = LockOn.new()
	_lock_on.orbit_camera = _camera
	_player.add_child(_lock_on)
	await _frames(3)

	await _test_picks_the_target_nearest_the_view_centre()
	await _test_action_toggles_and_signals()
	await _test_camera_turns_toward_the_target()
	await _test_switching_targets()
	await _test_lock_is_dropped()
	await _test_line_of_sight()
	if _failures == 0:
		print("test_lock_on: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame


func _make_target(at: Vector3) -> LockOnTarget:
	var target := LockOnTarget.new()
	target.position = at
	root.add_child(target)
	return target


func _reset() -> void:
	_lock_on.unlock()
	_camera.set_look(0.0, 0.0)
	await _frames(2)


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _test_picks_the_target_nearest_the_view_centre() -> void:
	await _reset()
	_check(_lock_on.find_best_target() == null, "nothing to lock onto in an empty scene")
	var centre := _make_target(Vector3(1, 1, -10))
	var side := _make_target(Vector3(6, 1, -8))
	var close_but_off_centre := _make_target(Vector3(3, 1, -3))
	var too_far := _make_target(Vector3(0, 1, -40))
	var behind := _make_target(Vector3(0, 1, 30))
	_check(_lock_on.find_best_target() == centre, "prefers the target nearest the view centre")
	centre.enabled = false
	_check(_lock_on.find_best_target() != centre, "skips a disabled target")
	centre.enabled = true
	too_far.position = Vector3(0, 1, -5)
	_check(_lock_on.find_best_target() == too_far, "a target that comes into range can be picked")
	for node: Node in [centre, side, close_but_off_centre, too_far, behind]:
		node.free()


func _test_action_toggles_and_signals() -> void:
	await _reset()
	var target := _make_target(Vector3(0, 1, -8))
	var events: Array = []
	_lock_on.locked.connect(func(t: LockOnTarget) -> void: events.append(t))
	_lock_on.unlocked.connect(func() -> void: events.append("unlocked"))
	await _press(&"lock_on")
	_check(_lock_on.is_locked() and _lock_on.target == target, "the action locks on")
	await _press(&"lock_on")
	_check(not _lock_on.is_locked(), "pressing again lets go")
	_check(events == [target, "unlocked"], "locked and unlocked are emitted")
	target.free()


func _test_camera_turns_toward_the_target() -> void:
	await _reset()
	# Directly to the left of the player.
	var target := _make_target(Vector3(-10, 1, 0))
	_lock_on.max_angle_degrees = 180.0
	_lock_on.lock(target)
	await _frames(60)
	_check(absf(angle_difference(_camera.yaw, PI / 2.0)) < 0.05, "camera yaw ends up facing it")
	target.position = Vector3(0, 1, 10)
	await _frames(60)
	_check(absf(angle_difference(_camera.yaw, PI)) < 0.05, "and follows it when it moves")
	_lock_on.max_angle_degrees = 60.0
	target.free()


func _test_switching_targets() -> void:
	await _reset()
	var left := _make_target(Vector3(-5, 1, -10))
	var middle := _make_target(Vector3(0, 1, -10))
	var right := _make_target(Vector3(5, 1, -10))
	_lock_on.camera_turn_speed = 0.0
	_lock_on.lock(middle)
	_lock_on.switch_target(1)
	_check(_lock_on.target == right, "switching right picks the next target on the right")
	_lock_on.switch_target(1)
	_check(_lock_on.target == right, "and stays put when there is none further right")
	_lock_on.switch_target(-1)
	_lock_on.switch_target(-1)
	_check(_lock_on.target == left, "switching left twice reaches the leftmost")
	await _press(&"look_right")
	_check(_lock_on.target == middle, "the look actions switch while locked")
	_lock_on.camera_turn_speed = 10.0
	for node: Node in [left, middle, right]:
		node.free()


func _test_lock_is_dropped() -> void:
	await _reset()
	var target := _make_target(Vector3(0, 1, -8))
	_lock_on.lock(target)
	target.position = Vector3(0, 1, -30)
	await _frames(2)
	_check(not _lock_on.is_locked(), "dropped when the target goes beyond break_distance")

	target.position = Vector3(0, 1, -8)
	_lock_on.lock(target)
	target.enabled = false
	await _frames(2)
	_check(not _lock_on.is_locked(), "dropped when the target is disabled")

	target.enabled = true
	_lock_on.lock(target)
	var unlocks := [0]
	var count := func() -> void: unlocks[0] += 1
	_lock_on.unlocked.connect(count)
	target.free()
	await _frames(2)
	_check(not _lock_on.is_locked() and unlocks[0] == 1, "dropped when the target is freed")
	_lock_on.unlocked.disconnect(count)


func _test_line_of_sight() -> void:
	await _reset()
	var target := _make_target(Vector3(0, 1, -10))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 6, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1, -5)
	root.add_child(wall)
	await _frames(3)
	_check(_lock_on.find_best_target() == null, "a target behind a wall cannot be locked")
	_lock_on.requires_line_of_sight = false
	_check(_lock_on.find_best_target() == target, "unless line of sight is not required")
	_lock_on.requires_line_of_sight = true
	wall.free()
	target.free()
