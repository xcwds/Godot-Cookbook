extends SceneTree
## Headless test for recipes/orbit_camera and recipes/aim_camera. Run with:
##   godot --headless --path . -s tests/test_cameras.gd

const ORBIT_CAMERA := preload("res://recipes/orbit_camera/orbit_camera.tscn")
const AIM_CAMERA := preload("res://recipes/aim_camera/aim_camera.tscn")

var _failures := 0


func _initialize() -> void:
	# Nodes only become ready once the tree is running.
	await process_frame
	_test_follows_target_and_ignores_parent_rotation()
	_test_pitch_is_clamped_and_yaw_wraps()
	_test_look_actions_turn_the_camera()
	_test_zoom_is_clamped()
	_test_inactive_rig_does_nothing()
	_test_aim_takes_over_and_hands_back()
	if _failures == 0:
		print("test_cameras: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _make_target() -> Node3D:
	var target := Node3D.new()
	root.add_child(target)
	return target


func _make_orbit(target: Node3D) -> OrbitCamera:
	var rig: OrbitCamera = ORBIT_CAMERA.instantiate()
	rig.target = target
	target.add_child(rig)
	return rig


func _test_follows_target_and_ignores_parent_rotation() -> void:
	var target := _make_target()
	target.position = Vector3(3, 0, 4)
	var rig := _make_orbit(target)
	_check(rig.global_position.is_equal_approx(Vector3(3, 1.2, 4)), "starts at target + offset")
	_check(rig.get_camera().current, "active rig owns the view")
	target.position = Vector3(10, 0, 0)
	target.rotation.y = 1.0
	rig.follow_speed = 0.0
	rig._process(0.016)
	_check(rig.global_position.is_equal_approx(Vector3(10, 1.2, 0)), "rigid follow reaches target")
	_check(is_zero_approx(rig.global_rotation.y), "parent rotation does not turn the rig")
	rig.follow_speed = 12.0
	target.position = Vector3(20, 0, 0)
	rig._process(0.016)
	_check(rig.global_position.x > 10.0 and rig.global_position.x < 20.0, "smoothed follow lags")
	target.free()


func _test_pitch_is_clamped_and_yaw_wraps() -> void:
	var target := _make_target()
	var rig := _make_orbit(target)
	rig.set_look(0.0, 5.0)
	_check(is_equal_approx(rig.pitch, deg_to_rad(rig.pitch_max_degrees)), "pitch clamps at max")
	rig.set_look(0.0, -5.0)
	_check(is_equal_approx(rig.pitch, deg_to_rad(rig.pitch_min_degrees)), "pitch clamps at min")
	rig.set_look(TAU + 0.5, 0.0)
	_check(is_equal_approx(rig.yaw, 0.5), "yaw wraps")
	target.free()


func _test_look_actions_turn_the_camera() -> void:
	var target := _make_target()
	var rig := _make_orbit(target)
	rig.set_look(0.0, 0.0)
	Input.action_press(&"look_right")
	rig._process(0.1)
	Input.action_release(&"look_right")
	_check(rig.yaw < 0.0, "look_right turns the camera right (negative yaw)")
	Input.action_press(&"look_up")
	rig._process(0.1)
	Input.action_release(&"look_up")
	_check(rig.pitch > 0.0, "look_up tilts the camera up")
	rig.invert_y = true
	rig.set_look(0.0, 0.0)
	Input.action_press(&"look_up")
	rig._process(0.1)
	Input.action_release(&"look_up")
	_check(rig.pitch < 0.0, "invert_y flips it")
	target.free()


func _test_zoom_is_clamped() -> void:
	var target := _make_target()
	var rig := _make_orbit(target)
	rig.set_distance(100.0)
	_check(rig.distance == rig.zoom_max, "distance clamps at zoom_max")
	rig.set_distance(0.0)
	_check(rig.distance == rig.zoom_min, "distance clamps at zoom_min")
	_check(rig.get_node("Pitch/SpringArm").spring_length == rig.zoom_min, "spring arm follows")
	target.free()


func _test_inactive_rig_does_nothing() -> void:
	var target := _make_target()
	var rig := _make_orbit(target)
	rig.deactivate()
	rig.set_look(0.0, 0.0)
	var before := rig.global_position
	target.position = Vector3(5, 0, 5)
	Input.action_press(&"look_right")
	rig._process(0.1)
	Input.action_release(&"look_right")
	_check(
		rig.yaw == 0.0 and rig.global_position == before, "inactive rig ignores input and target"
	)
	target.free()


func _test_aim_takes_over_and_hands_back() -> void:
	var target := _make_target()
	var orbit := _make_orbit(target)
	var aim: AimCamera = AIM_CAMERA.instantiate()
	aim.target = target
	aim.orbit_camera = orbit
	target.add_child(aim)
	var events: Array = []
	aim.aim_started.connect(func() -> void: events.append("started"))
	aim.aim_ended.connect(func() -> void: events.append("ended"))
	_check(orbit.get_camera().current and not aim.is_aiming(), "orbit camera starts in charge")

	orbit.set_look(1.0, -0.2)
	Input.action_press(&"aim")
	aim._process(0.016)
	_check(aim.is_aiming() and not orbit.active, "aim action switches to the aim camera")
	_check(aim.get_camera().current, "aim camera owns the view")
	_check(
		is_equal_approx(aim.yaw, 1.0) and is_equal_approx(aim.pitch, -0.2),
		"aim starts at orbit look"
	)

	aim.set_look(2.0, 0.1)
	Input.action_release(&"aim")
	aim._process(0.016)
	_check(not aim.is_aiming() and orbit.active, "releasing hands back to the orbit camera")
	_check(orbit.get_camera().current, "orbit camera owns the view again")
	_check(
		is_equal_approx(orbit.yaw, 2.0) and is_equal_approx(orbit.pitch, 0.1),
		"orbit keeps the aim look"
	)
	_check(events == ["started", "ended"], "signals are emitted once each")
	target.free()
