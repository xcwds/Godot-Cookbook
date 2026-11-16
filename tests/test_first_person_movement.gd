extends "res://tests/support/test_case.gd"
## Headless test for recipes/first_person_movement. It plays the character
## with simulated input in the recipe's demo. Run with:
##   godot --headless --path . -s tests/test_first_person_movement.gd

const DEMO := "res://recipes/first_person_movement/demo.tscn"
const ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"look_left",
	&"look_right",
	&"look_up",
	&"look_down",
	&"jump",
	&"sprint",
	&"crouch",
]

var _character: FirstPersonCharacter
var _jumps := 0


func _before_all() -> void:
	change_scene_to_file(DEMO)
	await process_frame
	_character = current_scene.get_node("Player")
	_character.jumped.connect(func() -> void: _jumps += 1)


func _reset(at := Vector3(0, 0.1, 0)) -> void:
	for action in ACTIONS:
		Input.action_release(action)
	await _wait(0.5)
	_character.position = at
	_character.velocity = Vector3.ZERO
	_character.set_look(0.0, 0.0)
	await _wait(0.3)
	_jumps = 0


func _horizontal_speed() -> float:
	return Vector2(_character.velocity.x, _character.velocity.z).length()


## True when the horizontal speed is [param expected]. After move_and_slide()
## the speed on the floor varies from run to run by a few hundred-thousandths
## (floor contact is resolved slightly differently), which is_equal_approx()
## treats as a difference, so compare with a tolerance a player cannot see.
func _moves_at(expected: float) -> bool:
	return absf(_horizontal_speed() - expected) < 0.01


func test_walk_and_sprint() -> void:
	# Well back from the beam, so there is room to sprint.
	await _reset(Vector3(0, 0.1, 15))
	_check(_character.is_on_floor(), "stands on the floor")
	Input.action_press(&"move_up")
	await _wait(0.05)
	var early := _horizontal_speed()
	_check(early > 0.0 and early < _character.walk_speed, "speeds up over time, not at once")
	await _wait(0.5)
	_check(_moves_at(_character.walk_speed), "reaches walk speed")
	_check(_character.position.z < 13.5, "move_up walks forward along -Z")
	Input.action_press(&"sprint")
	await _wait(0.5)
	_check(_moves_at(_character.sprint_speed), "sprint is faster")
	_check(_character.is_sprinting(), "and reports sprinting")


func test_looking_turns_body_and_tilts_head() -> void:
	await _reset()
	Input.action_press(&"look_left")
	while _character.rotation.y < PI / 2.0:
		await process_frame
	Input.action_release(&"look_left")
	_check(
		is_equal_approx(_character.head.rotation.y, _character.yaw), "the head turns with the look"
	)
	Input.action_press(&"move_up")
	await _wait(0.6)
	_check(_character.position.x < -1.5, "forward follows where the body faces")
	Input.action_release(&"move_up")

	Input.action_press(&"look_up")
	await _wait(1.5)
	Input.action_release(&"look_up")
	var limit := deg_to_rad(_character.pitch_limit_degrees)
	_check(
		is_equal_approx(_character.head.rotation.x, limit), "looking up stops at the pitch limit"
	)
	_check(is_zero_approx(_character.rotation.x), "and never tilts the body")


func test_holding_jump_jumps_once() -> void:
	await _reset()
	Input.action_press(&"jump")
	await _wait(0.2)
	_check(_character.position.y > 0.3, "jump leaves the floor")
	await _wait(2.0)
	_check(_jumps == 1, "holding jump jumps once, got %d" % _jumps)


func test_crouch() -> void:
	await _reset()
	var shape: CapsuleShape3D = _character.get_node("CollisionShape3D").shape
	var standing_eye := _character.head.position.y
	var changes: Array = []
	_character.crouch_changed.connect(func(crouching: bool) -> void: changes.append(crouching))
	Input.action_press(&"crouch")
	await _wait(0.5)
	_check(_character.is_crouching, "crouch action crouches")
	_check(is_equal_approx(shape.height, _character.crouch_height), "the capsule shrinks")
	_check(_character.head.position.y < standing_eye - 0.5, "the eyes come down")
	_check(_character.is_on_floor(), "feet stay on the floor")

	Input.action_press(&"move_up")
	Input.action_press(&"sprint")
	await _wait(0.5)
	_check(_moves_at(_character.crouch_speed), "crouching is slow")
	_check(not _character.is_sprinting(), "and cannot sprint")
	Input.action_release(&"move_up")
	Input.action_release(&"sprint")

	Input.action_release(&"crouch")
	await _wait(0.5)
	_check(not _character.is_crouching, "releasing stands up")
	_check(is_equal_approx(shape.height, _character.stand_height), "at full height")
	_check(changes == [true, false], "crouch_changed is emitted each way")


func test_cannot_stand_under_the_beam() -> void:
	# The demo's beam spans z = -5.5 to -8.5 with its underside at 1.2 m.
	await _reset(Vector3(0, 0.1, -4))
	Input.action_press(&"move_up")
	await _wait(0.6)
	_check(_character.position.z > -5.3, "the beam blocks a standing character")

	Input.action_press(&"crouch")
	await _wait(1.0)
	_check(_character.position.z < -6.0, "crouching gets under it")
	Input.action_release(&"move_up")
	Input.action_release(&"crouch")
	await _wait(0.5)
	_check(_character.is_crouching, "cannot stand up while under it")

	Input.action_press(&"move_up")
	await _wait(1.5)
	Input.action_release(&"move_up")
	await _wait(0.4)
	_check(_character.position.z < -8.9, "walks out the far side")
	_check(not _character.is_crouching, "and stands up once clear")


func test_look_direction_is_saveable() -> void:
	_check(_character.is_in_group(&"saveable"), "the character joins the saveable group")
	_character.set_look(1.0, 0.3)
	# Through JSON as the save_load recipe stores it.
	var stored: Variant = JSON.to_native(
		JSON.parse_string(JSON.stringify(JSON.from_native(_character.save_data())))
	)
	_character.set_look(0.0, 0.0)
	await physics_frame
	_character.load_data(stored)
	await physics_frame
	_check(is_equal_approx(_character.yaw, 1.0), "saved yaw is restored")
	_check(is_equal_approx(_character.pitch, 0.3), "saved pitch is restored")
	_check(is_equal_approx(_character.rotation.y, 1.0), "and the body turns to it")


func test_teleport() -> void:
	_character.set_look(0.0, 0.5)
	_character.velocity = Vector3(5, 3, 5)
	var spawn := Transform3D(
		Basis(Vector3.UP, PI / 2.0), _character.global_position + Vector3(2, 0, 0)
	)
	_character.teleport(spawn)
	_check(_character.velocity == Vector3.ZERO, "teleport stops the character")
	_check(_character.global_position.is_equal_approx(spawn.origin), "and moves it")
	_check(is_equal_approx(_character.yaw, PI / 2.0), "looking the way the spawn faces")
	_check(is_zero_approx(_character.pitch), "with the view level")
	await physics_frame
	_check(is_equal_approx(_character.rotation.y, PI / 2.0), "the body turns with it")
