extends SceneTree
## Headless test for recipes/third_person_movement. It plays the character
## with simulated input in the shared demo level. Run with:
##   godot --headless --path . -s tests/test_third_person_movement.gd

const LEVEL := preload("res://shared/demo_level.tscn")
const CHARACTER := preload("res://recipes/third_person_movement/third_person_character.tscn")
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"dash"
]
## Height of the character's origin when standing on the floor.
const STANDING_Y := 1.09

var _failures := 0
var _character: ThirdPersonCharacter
var _jumps := 0
var _dashes := 0


func _initialize() -> void:
	# Nodes only become ready once the tree is running.
	await process_frame
	root.add_child(LEVEL.instantiate())
	_character = CHARACTER.instantiate()
	root.add_child(_character)
	_character.jumped.connect(func() -> void: _jumps += 1)
	_character.dashed.connect(func() -> void: _dashes += 1)

	await _test_walks_relative_to_view()
	await _test_holding_jump_jumps_once()
	await _test_jump_is_buffered_before_landing()
	await _test_coyote_time()
	await _test_dash_goes_where_the_character_faces()
	await _test_one_air_dash_per_jump()
	await _test_wall_jump()
	if _failures == 0:
		print("test_third_person_movement: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _wait(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _wait(0.05)
	Input.action_release(action)


func _state() -> StringName:
	return _character.state_machine.state.name


## Puts the character somewhere, standing still with no input held.
func _reset(at: Vector3, facing_yaw := 0.0) -> void:
	for action in ACTIONS:
		Input.action_release(action)
	_character.position = at
	_character.velocity = Vector3.ZERO
	_character.model.rotation.y = facing_yaw
	await _wait(0.6)
	_jumps = 0
	_dashes = 0


func _test_walks_relative_to_view() -> void:
	await _reset(Vector3(0, 1.2, 0))
	_check(_state() == &"Ground", "settles on the ground")
	Input.action_press(&"move_up")
	await _wait(0.5)
	_check(_character.position.z < -2.0, "move_up walks along -Z with the default view")
	_check(absf(_character.position.x) < 0.01, "and not sideways")

	var view := Node3D.new()
	view.rotation.y = PI / 2.0
	root.add_child(view)
	_character.view = view
	var x_before := _character.position.x
	await _wait(0.5)
	_check(_character.position.x < x_before - 2.0, "turning the view turns the movement")
	_character.view = null
	view.free()


func _test_holding_jump_jumps_once() -> void:
	await _reset(Vector3(0, 1.2, 0))
	Input.action_press(&"jump")
	await _wait(2.5)
	_check(_jumps == 1, "holding jump jumps once, got %d" % _jumps)


func _test_jump_is_buffered_before_landing() -> void:
	await _reset(Vector3(0, 1.2, 0))
	await _tap(&"jump")
	await _wait(0.4)
	await _tap(&"jump")
	await _wait(0.8)
	_check(_jumps == 1, "a press in mid-air is forgotten, got %d jumps" % _jumps)

	await _reset(Vector3(0, 1.2, 0))
	await _tap(&"jump")
	# Wait until just above the floor on the way down.
	while not (_character.velocity.y < 0.0 and _character.position.y < STANDING_Y + 0.25):
		await physics_frame
	_check(_state() == &"Air", "still in the air when pressing again")
	await _tap(&"jump")
	await _wait(0.3)
	_check(_jumps == 2, "a press just before landing jumps on landing, got %d" % _jumps)


func _test_coyote_time() -> void:
	# Top of a pillar in the demo level: 2 m square, 10 m high.
	var pillar_top := Vector3(8, 10.0 + STANDING_Y + 0.1, 8)
	await _reset(pillar_top)
	Input.action_press(&"move_up")
	while _state() != &"Air":
		await physics_frame
	await _wait(0.05)
	await _tap(&"jump")
	_check(_jumps == 1 and _character.velocity.y > 0.0, "can jump just after leaving a ledge")

	await _reset(pillar_top)
	Input.action_press(&"move_up")
	while _state() != &"Air":
		await physics_frame
	await _wait(0.3)
	await _tap(&"jump")
	_check(_jumps == 0, "but not once coyote time has passed")


func _test_dash_goes_where_the_character_faces() -> void:
	# Facing -X: the old controller ended this dash moving toward +X.
	await _reset(Vector3(0, 1.2, 0), PI / 2.0)
	var start := _character.position
	var max_x := start.x
	await _tap(&"dash")
	_check(_dashes == 1 and _state() == &"Dash", "dash starts")
	for i in 30:
		await physics_frame
		max_x = maxf(max_x, _character.position.x)
	_check(_character.position.x < start.x - 4.0, "dash covers its distance toward -X")
	_check(max_x <= start.x + 0.01, "and never moves the other way")
	_check(_state() == &"Ground", "dash returns to the ground state")


func _test_one_air_dash_per_jump() -> void:
	await _reset(Vector3(0, 1.2, 0))
	# A short cooldown, so that only the air-dash rule can block the second dash.
	var cooldown := _character.dash_cooldown
	_character.dash_cooldown = 0.05
	await _tap(&"jump")
	await _wait(0.1)
	await _tap(&"dash")
	await _wait(0.25)
	_check(_state() == &"Air", "airborne again after the first dash")
	await _tap(&"dash")
	_check(_dashes == 1, "only one dash in the air, got %d" % _dashes)
	await _wait(1.0)
	await _tap(&"dash")
	_check(_dashes == 2, "dash is available again after landing")
	_character.dash_cooldown = cooldown


func _test_wall_jump() -> void:
	# The room's wall is at z = -25, facing +Z.
	await _reset(Vector3(0, 1.2, -24))
	Input.action_press(&"move_up")
	await _wait(0.5)
	_check(_state() == &"Ground" and _character.is_on_wall(), "pressed against the wall")

	await _tap(&"jump")
	var peak := _character.position.y
	while _state() == &"Air":
		await physics_frame
		peak = maxf(peak, _character.position.y)
	_check(peak > STANDING_Y + 0.8, "jumping against a wall still rises, peak %.2f" % peak)
	_check(_state() == &"WallSlide", "then slides once it starts falling")

	var y_before := _character.position.y
	await _wait(0.4)
	var slid := y_before - _character.position.y
	_check(_state() == &"WallSlide", "keeps sliding while held against the wall")
	_check(slid > 0.1 and slid < 0.4, "slides slowly, moved %.2f" % slid)

	_jumps = 0
	await _tap(&"jump")
	await _wait(0.1)
	_check(_jumps == 1 and _state() == &"Air", "jump pushes off the wall")
	_check(_character.velocity.z > 0.0 and _character.position.y > y_before - slid, "up and away")
