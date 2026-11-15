extends ThirdPersonCharacterState
## Sliding slowly down a wall. Jump to push off it; steer away to let go.

## Speed pressed into the wall each tick so contact is not lost.
const STICK_SPEED := 1.0

var _wall_normal := Vector3.ZERO


func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	_wall_normal = character.get_wall_normal()
	character.restore_air_dash()


func _physics_update(_delta: float) -> void:
	if character.wants_dash():
		hand_off_to(DASH)
		return
	if character.consume_jump():
		character.velocity = _wall_normal * character.wall_jump_push
		character.jump()
		character.face(_wall_normal)
		transition_to(AIR, {"control_lock": character.wall_jump_control_lock})
		return
	if character.get_move_direction().dot(_wall_normal) > 0.5:
		transition_to(AIR)
		return

	character.velocity = -_wall_normal * STICK_SPEED + Vector3.DOWN * character.wall_slide_speed
	character.move_and_slide()

	if character.is_on_floor():
		transition_to(GROUND)
	elif not character.is_on_wall():
		transition_to(AIR)
	else:
		_wall_normal = character.get_wall_normal()
