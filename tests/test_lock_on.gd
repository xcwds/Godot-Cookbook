extends "res://tests/support/test_case.gd"
## Headless test for recipes/lock_on. Run with:
##   godot --headless --path . -s tests/test_lock_on.gd

const ORBIT_CAMERA := preload("res://recipes/orbit_camera/orbit_camera.tscn")

var _player: Node3D
var _camera: OrbitCamera
var _lock_on: LockOn


func _before_all() -> void:
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
	await _wait_frames(3)


func _make_target(at: Vector3) -> LockOnTarget:
	var target := LockOnTarget.new()
	target.position = at
	_spawn(target)
	return target


func _reset() -> void:
	_lock_on.unlock()
	_camera.set_look(0.0, 0.0)
	await _wait_frames(2)


func test_picks_the_target_nearest_the_view_centre() -> void:
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


func test_action_toggles_and_signals() -> void:
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


func test_camera_turns_toward_the_target() -> void:
	await _reset()
	# Directly to the left of the player.
	var target := _make_target(Vector3(-10, 1, 0))
	_lock_on.max_angle_degrees = 180.0
	_lock_on.lock(target)
	await _wait_frames(60)
	_check(absf(angle_difference(_camera.yaw, PI / 2.0)) < 0.05, "camera yaw ends up facing it")
	target.position = Vector3(0, 1, 10)
	await _wait_frames(60)
	_check(absf(angle_difference(_camera.yaw, PI)) < 0.05, "and follows it when it moves")
	_lock_on.max_angle_degrees = 60.0


func test_switching_targets() -> void:
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


func test_switching_from_a_freed_target_drops_the_lock() -> void:
	await _reset()
	var doomed := _make_target(Vector3(0, 1, -10))
	_make_target(Vector3(5, 1, -10))
	_lock_on.lock(doomed)
	var unlocks: Array = [0]
	var count := func() -> void: unlocks[0] += 1
	_lock_on.unlocked.connect(count)
	# Freed and switched in the same frame, before _process() can notice.
	doomed.free()
	_lock_on.switch_target(1)
	_check(not _lock_on.is_locked(), "switching with a freed target drops the lock")
	_check_eq(unlocks[0], 1, "and unlocked is emitted once")
	_lock_on.unlocked.disconnect(count)


func test_lock_is_dropped() -> void:
	await _reset()
	var target := _make_target(Vector3(0, 1, -8))
	_lock_on.lock(target)
	target.position = Vector3(0, 1, -30)
	await _wait_frames(2)
	_check(not _lock_on.is_locked(), "dropped when the target goes beyond break_distance")

	target.position = Vector3(0, 1, -8)
	_lock_on.lock(target)
	target.enabled = false
	await _wait_frames(2)
	_check(not _lock_on.is_locked(), "dropped when the target is disabled")

	target.enabled = true
	_lock_on.lock(target)
	var unlocks := [0]
	var count := func() -> void: unlocks[0] += 1
	_lock_on.unlocked.connect(count)
	target.free()
	await _wait_frames(2)
	_check(not _lock_on.is_locked() and unlocks[0] == 1, "dropped when the target is freed")
	_lock_on.unlocked.disconnect(count)


func test_line_of_sight() -> void:
	await _reset()
	var target := _make_target(Vector3(0, 1, -10))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 6, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1, -5)
	_spawn(wall)
	await _wait_frames(3)
	_check(_lock_on.find_best_target() == null, "a target behind a wall cannot be locked")
	_lock_on.requires_line_of_sight = false
	_check(_lock_on.find_best_target() == target, "unless line of sight is not required")
	_lock_on.requires_line_of_sight = true
