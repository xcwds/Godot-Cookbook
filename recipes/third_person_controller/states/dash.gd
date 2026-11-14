extends ThirdPersonControllerState

@onready var duration: Timer = $Duration
@onready var cooldown: Timer = $Cooldown

func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	tpc._do_dash()
	duration.start(tpc.dash_length / tpc.dash_speed)
	tpc.is_dash_ready = false
	tpc.look_forward(1.0)

func _exit() -> void:
	cooldown.start(tpc.dash_cooldown)
	tpc._end_dash()

func _physics_update(_delta: float) -> void:
	tpc.move_and_slide()

func _on_duration_timeout() -> void:
	transition_to(IWR)

func _on_cooldown_timeout() -> void:
	tpc.is_dash_ready = true
