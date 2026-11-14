extends ThirdPersonControllerState

func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	tpc.animation_state.travel("Jump")
	tpc.velocity.y = tpc.jump_velocity

func _physics_update(_delta: float) -> void:
	tpc.move_and_slide()
	transition_to(FALL)