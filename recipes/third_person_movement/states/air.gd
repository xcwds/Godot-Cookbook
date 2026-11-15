extends ThirdPersonCharacterState
## Rising or falling. Entered by jumping, walking off a ledge, wall jumping
## or leaving a wall.
##
## Data accepted on enter:
## [code]coyote[/code] (bool): the character left the ground without jumping.
## [code]control_lock[/code] (float): seconds to ignore steering.

var _coyote_left := 0.0
var _control_lock_left := 0.0


func _enter(_previous_state: StringName, data: Dictionary) -> void:
	_coyote_left = character.coyote_time if data.get("coyote", false) else 0.0
	_control_lock_left = data.get("control_lock", 0.0)


func _physics_update(delta: float) -> void:
	if character.wants_dash():
		hand_off_to(DASH)
		return
	if _coyote_left > 0.0 and character.consume_jump():
		_coyote_left = 0.0
		character.jump()
	_coyote_left -= delta
	_control_lock_left -= delta

	character.apply_gravity(delta)
	if character.air_control and _control_lock_left <= 0.0:
		character.steer(delta)
	character.move_and_slide()

	if character.is_on_floor():
		character.landed.emit()
		transition_to(GROUND)
	elif character.can_wall_slide():
		transition_to(WALL_SLIDE)
