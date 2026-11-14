extends ThirdPersonControllerState

var last_input_direction := Vector2.ZERO

func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	tpc.animation_state.travel("IWR_Strafe" if tpc.is_aiming() else "IWR")

func _physics_update(delta: float) -> void:
	if tpc.is_start_dash():
		hand_off_to(DASH)
		return
	elif not tpc.is_on_floor():
		hand_off_to(FALL)
		return
	elif Input.is_action_pressed("jump"):
		hand_off_to(JUMP)
		return

	tpc._do_iwr(delta)
	tpc.move_and_slide()

	var horizontal_speed := Vector2(tpc.velocity.x, tpc.velocity.z).length()
	tpc.animation_tree.set("parameters/IWR/blend_position", minf(horizontal_speed / tpc.speed, 1.0))

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != last_input_direction:
		input_direction = lerp(last_input_direction, input_direction, tpc.rotation_speed * delta)
		last_input_direction = input_direction
	tpc.animation_tree.set("parameters/IWR_Strafe/blend_position", input_direction)
