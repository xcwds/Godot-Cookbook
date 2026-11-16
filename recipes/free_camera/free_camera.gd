class_name FreeCamera
extends Node3D
## Detached camera that flies anywhere, for a photo mode or for looking around
## a level while debugging. It takes the view from whichever camera is
## current, starts where that camera is, and gives the view back afterwards.
##
## It pauses the game while it is active unless [member pause_game] is off,
## and keeps working while the scene tree is paused.

## Emitted when the camera takes the view.
signal activated
## Emitted when the view has gone back to the previous camera.
signal deactivated

const ACTION_MOVE_LEFT := &"move_left"
const ACTION_MOVE_RIGHT := &"move_right"
const ACTION_MOVE_FORWARD := &"move_up"
const ACTION_MOVE_BACK := &"move_down"
const ACTION_UP := &"camera_up"
const ACTION_DOWN := &"camera_down"
const ACTION_FAST := &"sprint"
const PITCH_LIMIT := deg_to_rad(89.0)
# How far from a wall the collision sphere stops, in metres.
const COLLISION_GAP := 0.01

## Input action that turns the camera on and off. Leave empty to only use
## [method activate] and [method deactivate].
@export var toggle_action := &"free_camera"
## Pause the scene tree while the camera is active: a photo mode. When off the
## game keeps running: a spectator or debug camera.
@export var pause_game := true
## Capture the mouse while the camera is active. The mouse mode from before is
## put back afterwards.
@export var capture_mouse := true

@export_group("Movement")
## Metres per second. The mouse wheel changes it while flying.
@export var speed := 8.0
@export var speed_min := 1.0
@export var speed_max := 60.0
## Each mouse wheel step multiplies or divides the speed by this. 1 disables it.
@export var speed_step := 1.25
## Speed multiplier while the sprint action is held.
@export var fast_multiplier := 3.0
## How quickly the camera reaches its speed and stops. 0 is instant.
@export var acceleration := 10.0

@export_group("Look")
## Radians of rotation per pixel of mouse movement.
@export var mouse_sensitivity := 0.003
## Radians per second at full stick or key deflection.
@export var stick_speed := 2.0
@export var invert_y := false
## Start with the field of view of the camera the view was taken from.
@export var copy_fov := true

@export_group("Collision")
## Physics layers the camera cannot fly through. 0 lets it go anywhere.
@export_flags_3d_physics var collision_mask := 0
## Radius of the sphere that is swept through the world when
## [member collision_mask] is set.
@export var collision_radius := 0.3

## Whether the camera has the view. Change it with [method activate] and
## [method deactivate].
var active := false
## Rotation around the vertical axis, in radians.
var yaw := 0.0
## Rotation up and down, in radians.
var pitch := 0.0

var _velocity := Vector3.ZERO
var _mouse_motion := Vector2.ZERO
var _previous_camera: Camera3D
var _was_paused := false
var _mouse_mode_before := Input.MOUSE_MODE_VISIBLE
var _mouse_mode_active := Input.MOUSE_MODE_VISIBLE
var _collision_shape := SphereShape3D.new()
var _touch_shape := SphereShape3D.new()

@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	# Keep flying and listening for the toggle while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	# Moved every frame, so it must not be interpolated between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_look(global_rotation.y, global_rotation.x)


func _exit_tree() -> void:
	# Do not leave the tree paused or the mouse captured when the scene goes.
	if active:
		deactivate()


func _unhandled_input(event: InputEvent) -> void:
	if not toggle_action.is_empty() and event.is_action_pressed(toggle_action):
		if not is_blocked():
			toggle()
			get_viewport().set_input_as_handled()
		return
	if not active or is_blocked():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_motion += event.screen_relative
	elif event is InputEventMouseButton and event.pressed and speed_step > 1.0:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = clampf(speed * speed_step, speed_min, speed_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = clampf(speed / speed_step, speed_min, speed_max)


func _process(delta: float) -> void:
	if not active:
		return
	if is_blocked():
		_mouse_motion = Vector2.ZERO
		_velocity = Vector3.ZERO
		return
	if pause_game and not get_tree().paused:
		# Something else resumed the game, such as a pause menu closing.
		get_tree().paused = true
	_look(delta)
	_move(delta)


## Takes the view: remembers the current camera, starts from where it is,
## and pauses the game if [member pause_game] is on.
func activate() -> void:
	if active:
		return
	active = true
	_velocity = Vector3.ZERO
	_mouse_motion = Vector2.ZERO
	_previous_camera = get_viewport().get_camera_3d()
	if _previous_camera == _camera:
		_previous_camera = null
	if _previous_camera != null:
		# Where that camera is drawn this frame, which is what the player sees.
		var from := _previous_camera.get_global_transform_interpolated()
		global_position = from.origin
		var angles := from.basis.get_euler(EULER_ORDER_YXZ)
		set_look(angles.y, angles.x)
		if copy_fov:
			_camera.fov = _previous_camera.fov
	_camera.make_current()
	_mouse_mode_before = Input.mouse_mode
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_mode_active = Input.mouse_mode
	_was_paused = get_tree().paused
	if pause_game:
		get_tree().paused = true
	activated.emit()


## Gives the view back to the camera it was taken from, and puts the mouse
## mode and the pause state back as they were.
func deactivate() -> void:
	if not active:
		return
	active = false
	if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
		_previous_camera.make_current()
	else:
		_camera.clear_current()
	_previous_camera = null
	Input.mouse_mode = _mouse_mode_before
	if pause_game:
		get_tree().paused = _was_paused
	deactivated.emit()


func toggle() -> void:
	if active:
		deactivate()
	else:
		activate()


## Whether something else has the player's attention, such as a pause menu.
## The camera then ignores its toggle action and stops flying. That is the
## case when the tree is paused and this camera did not pause it, and when
## the mouse mode is no longer the one this camera set.
func is_blocked() -> bool:
	if not active:
		return get_tree().paused
	if not pause_game and get_tree().paused:
		return true
	return capture_mouse and Input.mouse_mode != _mouse_mode_active


## Points the camera in a direction, in radians.
func set_look(new_yaw: float, new_pitch: float) -> void:
	yaw = wrapf(new_yaw, -PI, PI)
	pitch = clampf(new_pitch, -PITCH_LIMIT, PITCH_LIMIT)
	rotation = Vector3(pitch, yaw, 0.0)


func get_camera() -> Camera3D:
	return _camera


func _look(delta: float) -> void:
	var look := -_mouse_motion * mouse_sensitivity
	_mouse_motion = Vector2.ZERO
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_down", &"look_up")
	look += Vector2(-stick.x, stick.y) * stick_speed * delta
	if invert_y:
		look.y = -look.y
	set_look(yaw + look.x, pitch + look.y)


func _move(delta: float) -> void:
	var input := Input.get_vector(
		ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_FORWARD, ACTION_MOVE_BACK
	)
	# Forward follows where the camera looks; up and down stay vertical.
	var direction := global_basis * Vector3(input.x, 0.0, input.y)
	direction += Vector3.UP * Input.get_axis(ACTION_DOWN, ACTION_UP)
	var wanted := direction.limit_length() * speed
	if Input.is_action_pressed(ACTION_FAST):
		wanted *= fast_multiplier
	var motion := wanted * delta
	if acceleration > 0.0:
		# The velocity eases toward the wanted one. This is the exact distance
		# covered meanwhile, so the flight is the same at any frame rate.
		var blend := 1.0 - exp(-acceleration * delta)
		motion += (_velocity - wanted) * blend / acceleration
		_velocity = _velocity.lerp(wanted, blend)
	else:
		_velocity = wanted
	if collision_mask != 0:
		motion = _stop_at_walls(motion)
	global_position += motion


# Shortens a motion so the collision sphere stops at what is in the way and
# slides along it instead.
func _stop_at_walls(motion: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	_collision_shape.radius = collision_radius
	# A slightly larger sphere finds the wall the camera is resting against.
	_touch_shape.radius = collision_radius + COLLISION_GAP * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = collision_mask
	var from := global_position
	var moved := Vector3.ZERO
	var left := motion
	for attempt in 3:
		query.shape = _touch_shape
		query.transform = Transform3D(Basis.IDENTITY, from + moved)
		query.motion = Vector3.ZERO
		var touching := space.get_rest_info(query)
		if not touching.is_empty():
			var normal: Vector3 = touching.normal
			if left.dot(normal) < 0.0:
				left = left.slide(normal)
				_velocity = _velocity.slide(normal)
		if left.is_zero_approx():
			break
		query.shape = _collision_shape
		query.motion = left
		var safe: float = space.cast_motion(query)[0]
		if safe >= 1.0:
			moved += left
			break
		# Stop a little short. A sphere that touches a wall counts as already
		# inside it, and the next cast would then pass straight through.
		var distance := maxf(left.length() * safe - COLLISION_GAP, 0.0)
		moved += left.normalized() * distance
		left -= left * safe
	return moved
