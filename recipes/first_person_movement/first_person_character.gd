class_name FirstPersonCharacter
extends CharacterBody3D
## First-person character in one script: mouse and stick look, walking with
## acceleration, sprinting, crouching and jumping.
##
## The body turns left and right; only the head tilts up and down.

signal jumped
signal landed
signal crouch_changed(crouching: bool)

const ACTION_MOVE_LEFT := &"move_left"
const ACTION_MOVE_RIGHT := &"move_right"
const ACTION_MOVE_FORWARD := &"move_up"
const ACTION_MOVE_BACK := &"move_down"
const ACTION_LOOK_LEFT := &"look_left"
const ACTION_LOOK_RIGHT := &"look_right"
const ACTION_LOOK_UP := &"look_up"
const ACTION_LOOK_DOWN := &"look_down"
const ACTION_JUMP := &"jump"
const ACTION_SPRINT := &"sprint"
const ACTION_CROUCH := &"crouch"

@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var crouch_speed := 2.5
## How quickly speed changes on the ground, in metres per second squared.
@export var ground_acceleration := 50.0
## The same in the air. Lower values give less control while airborne.
@export var air_acceleration := 10.0
@export var jump_velocity := 4.5

@export_group("Jump Assists")
## Seconds after walking off a ledge during which a jump still works.
@export var coyote_time := 0.1
## Seconds a jump press is remembered, so pressing just before landing works.
@export var jump_buffer_time := 0.12

@export_group("Look")
## Radians of rotation per pixel of mouse movement.
@export var mouse_sensitivity := 0.003
## Radians per second at full stick or key deflection.
@export var stick_speed := 2.5
@export var invert_y := false
## How far up and down the head can tilt.
@export_range(0.0, 89.0) var pitch_limit_degrees := 85.0
## Capture the mouse when the character enters the scene. Mouse look only
## works while the mouse is captured.
@export var capture_mouse := true

@export_group("Crouch")
@export var stand_height := 1.8
@export var crouch_height := 1.0
## How far the eyes are below the top of the head.
@export var eye_offset := 0.2
## How quickly the character changes height, in metres per second.
@export var crouch_transition_speed := 5.0

var is_crouching := false

var _height := 0.0
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _was_on_floor := true

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D


func _ready() -> void:
	# The capsule changes height, so this character needs its own copy.
	_capsule = _collision.shape.duplicate()
	_collision.shape = _capsule
	_height = stand_height
	_apply_height()
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(-event.screen_relative * mouse_sensitivity)


func _process(delta: float) -> void:
	var stick := Input.get_vector(
		ACTION_LOOK_LEFT, ACTION_LOOK_RIGHT, ACTION_LOOK_UP, ACTION_LOOK_DOWN
	)
	_look(-stick * stick_speed * delta)


func _physics_process(delta: float) -> void:
	_update_crouch(delta)
	_update_jump(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector(
		ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_FORWARD, ACTION_MOVE_BACK
	)
	var target := global_basis * Vector3(input.x, 0.0, input.y) * get_target_speed()
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		landed.emit()
	_was_on_floor = is_on_floor()


func is_sprinting() -> bool:
	return Input.is_action_pressed(ACTION_SPRINT) and not is_crouching


## The speed the character is trying to reach right now.
func get_target_speed() -> float:
	if is_crouching:
		return crouch_speed
	return sprint_speed if is_sprinting() else walk_speed


## Turns the body by [code]amount.x[/code] and tilts the head by
## [code]amount.y[/code], in radians. Positive is left and up.
func _look(amount: Vector2) -> void:
	rotate_y(amount.x)
	var limit := deg_to_rad(pitch_limit_degrees)
	var pitch := amount.y if not invert_y else -amount.y
	head.rotation.x = clampf(head.rotation.x + pitch, -limit, limit)


func _update_jump(delta: float) -> void:
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	_coyote_left = coyote_time if is_on_floor() else maxf(_coyote_left - delta, 0.0)
	if Input.is_action_just_pressed(ACTION_JUMP):
		_jump_buffer_left = jump_buffer_time
	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		velocity.y = jump_velocity
		jumped.emit()


func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed(ACTION_CROUCH)
	if wants_crouch != is_crouching and (wants_crouch or _can_stand()):
		is_crouching = wants_crouch
		crouch_changed.emit(is_crouching)
	var target := crouch_height if is_crouching else stand_height
	if not is_equal_approx(_height, target):
		_height = move_toward(_height, target, crouch_transition_speed * delta)
		_apply_height()


## True if there is room above to stand up.
func _can_stand() -> bool:
	return not test_move(global_transform, Vector3.UP * (stand_height - _height))


## The character's origin is at its feet, so only the top moves.
func _apply_height() -> void:
	_capsule.height = _height
	_collision.position.y = _height / 2.0
	head.position.y = _height - eye_offset
