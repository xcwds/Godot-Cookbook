extends ThirdPersonControllerState

func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	tpc.velocity.y = tpc.wall_slide_velocity
	tpc.animation_state.travel("Wall_Slide_Idle")

func _physics_update(delta: float) -> void:
	if tpc.is_on_floor():
		hand_off_to(IWR)
		return
	elif !tpc.is_on_wall():
		hand_off_to(FALL)
		return
	elif Input.is_action_pressed("jump"):
		tpc.last_movement_direction = tpc.get_wall_normal() * tpc.speed
		tpc.look_forward(1.0)
		tpc.velocity = tpc.get_wall_normal() * tpc.speed
		tpc.velocity.y = tpc.jump_velocity
		tpc.move_and_slide()
		transition_to(WALL_JUMP)
		return
	
	tpc.move_and_slide()
