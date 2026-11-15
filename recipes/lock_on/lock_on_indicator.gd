class_name LockOnIndicator
extends Control
## A marker drawn over the locked target.

## The lock-on to follow.
@export var lock_on: LockOn


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var target := lock_on.target if lock_on != null else null
	visible = (
		is_instance_valid(target)
		and camera != null
		and not camera.is_position_behind(target.global_position)
	)
	if visible:
		position = camera.unproject_position(target.global_position) - size / 2.0
