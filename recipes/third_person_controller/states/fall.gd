extends ThirdPersonControllerState

func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	tpc.animation_state.travel("Fall_Idle")

func _physics_update(delta: float) -> void:
	if tpc.is_start_dash():
		hand_off_to(DASH)
		return
	elif tpc.is_on_floor():
		hand_off_to(IWR)
		return
	elif tpc.is_wall_slide and tpc.is_on_wall():
		hand_off_to(WALL_SLIDE)
		return
	
	tpc._do_fall(delta)

	if tpc.is_mid_air_movement:
		tpc._do_iwr(delta)
	tpc.move_and_slide()