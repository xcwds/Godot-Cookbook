class_name OrbitCamera
extends Node3D
## Third-person camera rig that follows a target and orbits it with the mouse
## or a stick. A spring arm pulls the camera in when something is in the way.
##
## The rig ignores its parent's transform, so it can be a child of the
## character it follows or live anywhere else in the scene.

## Node to follow.
@export var target: Node3D
## Point the camera orbits, relative to the target's origin.
@export var target_offset := Vector3(0.0, 1.2, 0.0)
## Sideways and vertical shift of the camera, for an over-the-shoulder view.
@export var shoulder_offset := Vector3.ZERO
## Whether this rig reads input, follows the target and owns the view.
## Use [method activate] and [method deactivate] to switch between rigs.
@export var active := true

@export_group("Look")
## Radians of rotation per pixel of mouse movement.
@export var mouse_sensitivity := 0.003
## Radians per second at full stick or key deflection.
@export var stick_speed := 2.0
@export var invert_x := false
@export var invert_y := false
## Lowest pitch in degrees. Negative looks down at the target from above.
@export_range(-89.0, 0.0) var pitch_min_degrees := -60.0
## Highest pitch in degrees. Positive looks up from below.
@export_range(0.0, 89.0) var pitch_max_degrees := 30.0
@export_range(-89.0, 89.0) var initial_pitch_degrees := -15.0

@export_group("Follow")
## How quickly the rig catches up with the target. 0 follows rigidly.
@export var follow_speed := 12.0

@export_group("Zoom")
## Camera distance from the orbit point.
@export var distance := 5.0
@export var zoom_min := 1.5
@export var zoom_max := 8.0
## Distance change per mouse wheel step. 0 disables zooming.
@export var zoom_step := 0.5

## Rotation around the vertical axis, in radians. The camera looks along -Z
## when this is 0. Use it to make movement relative to the camera.
var yaw := 0.0
## Rotation up and down, in radians.
var pitch := 0.0

var _mouse_motion := Vector2.ZERO

@onready var _pitch_pivot: Node3D = $Pitch
@onready var _spring_arm: SpringArm3D = $Pitch/SpringArm
@onready var _camera: Camera3D = $Pitch/SpringArm/Camera


func _ready() -> void:
	top_level = true
	_spring_arm.position = shoulder_offset
	_spring_arm.spring_length = distance
	if target is CollisionObject3D:
		_spring_arm.add_excluded_object(target.get_rid())
	set_look(global_rotation.y, deg_to_rad(initial_pitch_degrees))
	if active:
		activate()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_motion += event.screen_relative
	elif event is InputEventMouseButton and event.pressed and zoom_step > 0.0:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_distance(distance - zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_distance(distance + zoom_step)


func _process(delta: float) -> void:
	if not active:
		return
	var look := -_mouse_motion * mouse_sensitivity
	_mouse_motion = Vector2.ZERO
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_down", &"look_up")
	look += Vector2(-stick.x, stick.y) * stick_speed * delta
	if invert_x:
		look.x = -look.x
	if invert_y:
		look.y = -look.y
	set_look(yaw + look.x, pitch + look.y)
	_follow(delta)


## Makes this rig the active one: it takes the view, jumps to its target and
## starts reading input.
func activate() -> void:
	active = true
	_mouse_motion = Vector2.ZERO
	_follow(0.0)
	_camera.make_current()


## Stops this rig reading input and following. Activate another camera to
## take over the view.
func deactivate() -> void:
	active = false


## Points the rig in a direction, in radians. Pitch is clamped to the limits.
func set_look(new_yaw: float, new_pitch: float) -> void:
	yaw = wrapf(new_yaw, -PI, PI)
	pitch = clampf(new_pitch, deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch_pivot.rotation = Vector3(pitch, 0.0, 0.0)


func set_distance(new_distance: float) -> void:
	distance = clampf(new_distance, zoom_min, zoom_max)
	_spring_arm.spring_length = distance


func get_camera() -> Camera3D:
	return _camera


func _follow(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + target_offset
	if follow_speed <= 0.0 or delta <= 0.0:
		global_position = goal
	else:
		# Exponential smoothing, so the feel does not depend on frame rate.
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
