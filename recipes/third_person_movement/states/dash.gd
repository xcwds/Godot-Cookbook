extends ThirdPersonCharacterState
## A short burst in the input direction, or the facing direction with no
## input. Gravity is ignored for its duration.

var _direction := Vector3.FORWARD
var _distance_left := 0.0


func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	var input := character.get_move_direction()
	if input.length_squared() > 0.0001:
		_direction = input.normalized()
	else:
		_direction = character.get_facing_direction()
	_distance_left = character.dash_distance
	character.face(_direction)
	character.begin_dash()


func _exit() -> void:
	# Carry on at normal speed in the dash direction.
	character.velocity = _direction * character.speed
	character.end_dash()


func _physics_update(delta: float) -> void:
	# Counting distance rather than time, and shortening the last step, makes
	# the dash end exactly at dash_distance. A countdown in seconds drifts by
	# a whole tick when rounding leaves a sliver of time over.
	var step := minf(character.dash_speed * delta, _distance_left)
	character.velocity = _direction * (step / delta)
	character.move_and_slide()
	_distance_left -= step
	if _distance_left <= 0.0001:
		transition_to(GROUND if character.is_on_floor() else AIR)
