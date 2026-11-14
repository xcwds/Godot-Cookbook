class_name ThirdPersonCharacter
extends CharacterBody3D
## Third-person character movement: walk and run, jump, dash, wall slide and
## wall jump. The logic of each move lives in a state under [code]StateMachine[/code];
## this script holds the settings and the helpers the states share.
##
## Movement is relative to the active camera. The character knows nothing
## else about cameras, health or UI.

signal jumped
signal landed
signal dashed

const ACTION_MOVE_LEFT := &"move_left"
const ACTION_MOVE_RIGHT := &"move_right"
const ACTION_MOVE_FORWARD := &"move_up"
const ACTION_MOVE_BACK := &"move_down"
const ACTION_JUMP := &"jump"
const ACTION_DASH := &"dash"

## Node whose yaw decides which way "forward" is. Leave empty to use the
## viewport's current camera.
@export var view: Node3D
## Face the view direction instead of the movement direction, for aiming.
@export var strafe := false

@export_group("Movement")
@export var speed := 5.0
## How quickly the model turns to face its movement direction.
@export var rotation_speed := 12.0
@export var jump_velocity := 4.5
## Allow steering while in the air.
@export var air_control := true

@export_group("Jump Assists")
## Seconds after walking off a ledge during which a jump still works.
@export var coyote_time := 0.1
## Seconds a jump press is remembered, so pressing just before landing works.
@export var jump_buffer_time := 0.12

@export_group("Dash")
@export var dash_enabled := true
@export var dash_speed := 30.0
@export var dash_distance := 5.0
@export var dash_cooldown := 0.3

@export_group("Wall")
@export var wall_slide_enabled := true
## Downward speed while sliding on a wall.
@export var wall_slide_speed := 0.5
## Horizontal speed away from the wall on a wall jump.
@export var wall_jump_push := 5.0
## Seconds after a wall jump during which steering is ignored.
@export var wall_jump_control_lock := 0.25

var _jump_buffer_left := 0.0
var _dash_cooldown_left := 0.0
var _air_dash_available := true

@onready var model: Node3D = $Model
@onready var state_machine: StateMachine = $StateMachine


func _physics_process(delta: float) -> void:
	# Runs before the state machine, which is a child of this node.
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	if Input.is_action_just_pressed(ACTION_JUMP):
		_jump_buffer_left = jump_buffer_time
	if is_on_floor():
		_air_dash_available = true


func _process(_delta: float) -> void:
	if strafe:
		model.rotation.y = get_view_yaw()


## Yaw of the view in radians. Input is rotated by this.
func get_view_yaw() -> float:
	var source: Node3D = view if view != null else get_viewport().get_camera_3d()
	return source.global_rotation.y if source != null else 0.0


## Movement input as a world-space direction on the ground plane, relative
## to the view. Its length is how far the stick is pushed, at most 1.
func get_move_direction() -> Vector3:
	var input := Input.get_vector(
		ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_FORWARD, ACTION_MOVE_BACK
	)
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, get_view_yaw())


## The direction the model is facing, on the ground plane.
func get_facing_direction() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, model.rotation.y)


## Sets horizontal velocity from the movement input and turns the model.
func steer(delta: float) -> void:
	var direction := get_move_direction()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	face(direction, delta)


## Turns the model toward [param direction]. Pass no [param delta] to snap.
func face(direction: Vector3, delta := -1.0) -> void:
	direction.y = 0.0
	if strafe or direction.length_squared() < 0.0001:
		return
	var target := Vector3.FORWARD.signed_angle_to(direction, Vector3.UP)
	if delta < 0.0:
		model.rotation.y = target
	else:
		var weight := 1.0 - exp(-rotation_speed * delta)
		model.rotation.y = lerp_angle(model.rotation.y, target, weight)


func apply_gravity(delta: float) -> void:
	velocity += get_gravity() * delta


## True once per jump press, within the buffer window.
func consume_jump() -> bool:
	if _jump_buffer_left <= 0.0:
		return false
	_jump_buffer_left = 0.0
	return true


func jump() -> void:
	velocity.y = jump_velocity
	jumped.emit()


func wants_dash() -> bool:
	return (
		dash_enabled
		and _dash_cooldown_left <= 0.0
		and (is_on_floor() or _air_dash_available)
		and Input.is_action_just_pressed(ACTION_DASH)
	)


## Called by the dash state: one air dash until the next landing or wall.
func begin_dash() -> void:
	if not is_on_floor():
		_air_dash_available = false
	dashed.emit()


func end_dash() -> void:
	_dash_cooldown_left = dash_cooldown


func restore_air_dash() -> void:
	_air_dash_available = true


## True when touching a wall while falling, with wall sliding enabled.
func can_wall_slide() -> bool:
	return wall_slide_enabled and is_on_wall_only() and velocity.y <= 0.0
