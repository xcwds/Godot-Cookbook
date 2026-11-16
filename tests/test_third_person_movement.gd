extends "res://tests/support/test_case.gd"
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

var _character: ThirdPersonCharacter
var _jumps := 0
var _dashes := 0


func _before_all() -> void:
	root.add_child(LEVEL.instantiate())
	_character = CHARACTER.instantiate()
	root.add_child(_character)
	_character.jumped.connect(func() -> void: _jumps += 1)
	_character.dashed.connect(func() -> void: _dashes += 1)


func _state() -> StringName:
	return _character.state_machine.state.name


## Puts the character somewhere, standing still with no input held.
func _reset(at: Vector3, facing_yaw := 0.0) -> void:
	for action in ACTIONS:
		Input.action_release(action)
	_character.position = at
	_character.velocity = Vector3.ZERO
	_character.model.global_rotation.y = facing_yaw
	await _wait(0.6)
	_jumps = 0
	_dashes = 0


## Where the model faces in world space, on the ground plane.
func _model_forward() -> Vector3:
	var forward := -_character.model.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _horizontal_velocity() -> Vector3:
	return Vector3(_character.velocity.x, 0.0, _character.velocity.z).normalized()


func test_walks_relative_to_view() -> void:
	await _reset(Vector3(0, 1.2, 0))
	_check(_state() == &"Ground", "settles on the ground")
	Input.action_press(&"move_up")
	await _wait(0.5)
	_check(_character.position.z < -2.0, "move_up walks along -Z with the default view")
	_check(absf(_character.position.x) < 0.01, "and not sideways")

	var view := Node3D.new()
	view.rotation.y = PI / 2.0
	_spawn(view)
	_character.view = view
	var x_before := _character.position.x
	await _wait(0.5)
	_check(_character.position.x < x_before - 2.0, "turning the view turns the movement")
	_character.view = null


func test_holding_jump_jumps_once() -> void:
	await _reset(Vector3(0, 1.2, 0))
	Input.action_press(&"jump")
	await _wait(2.5)
	_check(_jumps == 1, "holding jump jumps once, got %d" % _jumps)


func test_jump_is_buffered_before_landing() -> void:
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


func test_coyote_time() -> void:
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


func test_dash_goes_where_the_character_faces() -> void:
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


func test_one_air_dash_per_jump() -> void:
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


func test_wall_jump() -> void:
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


## A level that spawns the player facing another way rotates the root. The
## model must still face the world-space direction it moves in.
func test_rotated_root_faces_where_it_goes() -> void:
	_character.rotation.y = PI / 2.0

	await _reset(Vector3(0, 1.2, 0))
	Input.action_press(&"move_up")
	await _wait(0.5)
	var travel := _horizontal_velocity()
	_check(travel.dot(Vector3.FORWARD) > 0.99, "a rotated root still walks along -Z")
	_check(
		_model_forward().dot(travel) > 0.99,
		"and its model faces that way, faces %s" % _model_forward()
	)

	await _reset(Vector3(0, 1.2, 0), PI / 2.0)
	await _tap(&"dash")
	_check(_state() == &"Dash", "a rotated root dashes")
	_check(
		_horizontal_velocity().dot(Vector3.LEFT) > 0.99,
		"a dash with no input goes where the model faces (-X), goes %s" % _horizontal_velocity()
	)
	_check(_model_forward().dot(Vector3.LEFT) > 0.99, "and the model keeps facing -X")

	await _reset(Vector3(0, 1.2, 0))
	var view := Node3D.new()
	view.rotation.y = -PI / 2.0
	_spawn(view)
	_character.view = view
	_character.strafe = true
	await _wait(0.1)
	_check(
		_model_forward().dot(Vector3.RIGHT) > 0.99,
		"strafing faces the view (+X), faces %s" % _model_forward()
	)
	_character.strafe = false
	_character.view = null
	view.free()
	_character.rotation.y = 0.0


## A respawn or load in the middle of a dash must not finish the dash from the
## new place.
func test_teleport_stops_a_dash() -> void:
	await _reset(Vector3(0, 1.2, 0))
	await _tap(&"dash")
	_check(_state() == &"Dash", "dashing before the teleport")
	var spawn := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-10, 1.2, 10))
	_character.teleport(spawn)
	_check(_state() == &"Ground", "teleport returns to the initial state")
	_check(_character.velocity == Vector3.ZERO, "and clears the velocity the dash left")
	await _wait(0.5)
	var moved := Vector2(
		_character.position.x - spawn.origin.x, _character.position.z - spawn.origin.z
	)
	_check(moved.length() < 0.05, "the character stays at the spawn, moved %.2f" % moved.length())
	_check(_state() == &"Ground", "standing on the ground")
	_check(
		_model_forward().dot(Vector3.LEFT) > 0.99,
		"facing the way the spawn faces (-X), faces %s" % _model_forward()
	)
	await _tap(&"dash")
	_check(_state() == &"Dash", "the dash cooldown was cleared")

	# A jump pressed in mid-air just before the teleport is forgotten.
	await _reset(Vector3(0, 1.2, 0))
	await _tap(&"jump")
	await _wait(0.4)
	Input.action_press(&"jump")
	await _wait(0.03)
	_check(_state() == &"Air", "still in the air when pressing jump again")
	_jumps = 0
	_character.teleport(Transform3D(Basis(), Vector3(0, STANDING_Y, 0)))
	await _wait(0.5)
	Input.action_release(&"jump")
	_check(_jumps == 0, "a jump buffered before the teleport is not used after it, got %d" % _jumps)


func test_respawner_teleports_the_character() -> void:
	var respawner := Respawner.new()
	_character.add_child(respawner)
	await _reset(Vector3(3, 1.2, 3))
	await _tap(&"dash")
	_check(_state() == &"Dash", "dashing before the respawn")
	respawner.respawn()
	await _wait(0.5)
	var start := Vector3(0, STANDING_Y, 0)
	_check(
		Vector2(_character.position.x, _character.position.z).length() < 0.05,
		"a respawn mid-dash leaves the character at the spawn, at %s" % _character.position
	)
	_check(_state() == &"Ground", "in the ground state, got %s" % _state())
	respawner.free()
