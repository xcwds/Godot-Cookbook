class_name AimCamera
extends OrbitCamera
## Over-the-shoulder camera that takes over from an [OrbitCamera] while the
## aim action is held, and hands the view back on release. Both cameras keep
## pointing the same way, so switching does not jump.

signal aim_started
signal aim_ended

## The normal camera to take over from and hand back to.
@export var orbit_camera: OrbitCamera
## Input action that is held to aim.
@export var aim_action := &"aim"


func _ready() -> void:
	active = false
	super()


func _process(delta: float) -> void:
	var wants_aim := Input.is_action_pressed(aim_action)
	if wants_aim and not active:
		start_aim()
	elif active and not wants_aim:
		end_aim()
	super(delta)


func is_aiming() -> bool:
	return active


func start_aim() -> void:
	if active:
		return
	if orbit_camera != null:
		set_look(orbit_camera.yaw, orbit_camera.pitch)
		orbit_camera.deactivate()
	activate()
	aim_started.emit()


func end_aim() -> void:
	if not active:
		return
	deactivate()
	if orbit_camera != null:
		orbit_camera.set_look(yaw, pitch)
		orbit_camera.activate()
	aim_ended.emit()
