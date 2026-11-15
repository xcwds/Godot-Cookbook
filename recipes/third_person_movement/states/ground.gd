extends ThirdPersonCharacterState
## On the floor: idle, walk and run. Jumps and dashes start here.


func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	character.velocity.y = 0.0


func _physics_update(delta: float) -> void:
	if character.wants_dash():
		hand_off_to(DASH)
		return
	if not character.is_on_floor():
		# Walked off a ledge: allow a late jump for a moment.
		hand_off_to(AIR, {"coyote": true})
		return
	if character.consume_jump():
		character.jump()
		hand_off_to(AIR)
		return

	character.steer(delta)
	character.move_and_slide()
