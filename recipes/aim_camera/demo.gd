extends Node3D

@onready var _walker: Node3D = $Walker
@onready var _aim_camera: AimCamera = $AimCamera


func _ready() -> void:
	# Mouse look only runs while the mouse is captured.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_aim_camera.aim_started.connect(func() -> void: _walker.auto_face = false)
	_aim_camera.aim_ended.connect(func() -> void: _walker.auto_face = true)


func _process(_delta: float) -> void:
	if _aim_camera.is_aiming():
		# While aiming, the character faces where the camera looks.
		_walker.rotation.y = _aim_camera.yaw
