extends ThirdPersonControllerState

func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	tpc.animation_state.travel("Jump")

func _physics_update(delta: float) -> void:
	if tpc.is_on_floor():
		hand_off_to(IWR)
		return
	elif tpc.is_on_wall():
		hand_off_to(WALL_SLIDE)
		return
	elif tpc.is_start_dash():
		hand_off_to(DASH)
		return
	
	tpc._do_fall(delta)
	tpc.move_and_slide()