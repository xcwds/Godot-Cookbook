extends Node3D


func _ready() -> void:
	# Mouse look only runs while the mouse is captured.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
