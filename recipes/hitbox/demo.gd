extends Node3D
## The player takes damage from the spikes, and deals damage by dashing
## through the dummies.

const SPAWN := Vector3(0, 1.1, 0)

@onready var _player: ThirdPersonCharacter = $Player
@onready var _player_health: Health = $Player/Health
@onready var _dash_hitbox: Hitbox = $Player/DashHitbox
@onready var _message: Label = %Message


func _ready() -> void:
	# The player's hitbox only connects while dashing.
	_player.state_machine.state_changed.connect(
		func(_previous: StringName, current: StringName) -> void:
			_dash_hitbox.active = current == &"Dash"
	)
	_player_health.died.connect(_on_player_died)
	for dummy in $Dummies.get_children():
		dummy.get_node("Health").died.connect(dummy.queue_free)


func _on_player_died() -> void:
	_message.text = "You died. Back to the start."
	_player.position = SPAWN
	_player.velocity = Vector3.ZERO
	_player_health.reset()
