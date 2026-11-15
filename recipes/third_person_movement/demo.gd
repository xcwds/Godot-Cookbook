extends Node3D
## Wires the character to the other recipes it is shown with.

@onready var _player: ThirdPersonCharacter = $Player
@onready var _aim_camera: AimCamera = $AimCamera


func _ready() -> void:
	# While aiming, the character faces where the camera looks and strafes.
	_aim_camera.aim_started.connect(func() -> void: _player.strafe = true)
	_aim_camera.aim_ended.connect(func() -> void: _player.strafe = false)
