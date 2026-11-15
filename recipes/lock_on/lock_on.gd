class_name LockOn
extends Node
## Lock-on targeting. On the lock-on action it picks the [LockOnTarget]
## nearest the centre of the view, keeps the camera turned toward it, and
## lets go when the target is lost.

signal locked(target: LockOnTarget)
signal unlocked

## Where the player is. Distances are measured from here. Defaults to the
## parent.
@export var origin: Node3D
## The camera to turn toward the target. Optional: without it the lock is
## tracked and signalled, and you aim the view yourself.
@export var orbit_camera: OrbitCamera

@export_group("Input")
## Locks on, or lets go if already locked.
@export var lock_action := &"lock_on"
## While locked, these switch to the next target on that side.
@export var switch_left_action := &"look_left"
@export var switch_right_action := &"look_right"

@export_group("Selection")
## Targets further than this cannot be locked onto.
@export var max_distance := 20.0
## Targets further than this from the centre of the view are ignored.
@export_range(1.0, 180.0) var max_angle_degrees := 60.0
## Only lock onto targets with nothing on the world layer in the way.
@export var requires_line_of_sight := true

@export_group("While Locked")
## The lock is dropped when the target gets further away than this.
@export var break_distance := 25.0
## How quickly the camera turns toward the target.
@export var camera_turn_speed := 10.0

## The locked target, or null.
var target: LockOnTarget

## Tracked separately because a freed target already compares equal to null.
var _is_locked := false


func _ready() -> void:
	if origin == null:
		origin = get_parent() as Node3D
	# Run after the camera has applied the player's look input.
	process_priority = 100


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(lock_action):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_locked() and event.is_action_pressed(switch_left_action):
		switch_target(-1)
	elif is_locked() and event.is_action_pressed(switch_right_action):
		switch_target(1)


func _process(delta: float) -> void:
	if not is_locked():
		return
	# Checked first: a freed target cannot be passed to the typed helpers.
	if not is_instance_valid(target):
		unlock()
		return
	if not _is_valid(target) or _distance_to(target) > break_distance:
		unlock()
		return
	if orbit_camera != null:
		var direction := target.global_position - origin.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			var wanted := Vector3.FORWARD.signed_angle_to(direction, Vector3.UP)
			var weight := 1.0 - exp(-camera_turn_speed * delta)
			var yaw := lerp_angle(orbit_camera.yaw, wanted, weight)
			orbit_camera.set_look(yaw, orbit_camera.pitch)


func is_locked() -> bool:
	return _is_locked


func toggle() -> void:
	if is_locked():
		unlock()
	else:
		lock(find_best_target())


## Locks onto [param new_target]. Does nothing if it is null.
func lock(new_target: LockOnTarget) -> void:
	if new_target == null or new_target == target:
		return
	target = new_target
	_is_locked = true
	locked.emit(target)


func unlock() -> void:
	if not _is_locked:
		return
	target = null
	_is_locked = false
	unlocked.emit()


## Moves the lock to the nearest target to the left (-1) or right (1) of the
## current one, as seen on screen.
func switch_target(direction: int) -> void:
	if not is_locked():
		return
	var current := _screen_angle(target)
	var best: LockOnTarget = null
	var best_gap := INF
	for candidate in _candidates():
		var gap := (_screen_angle(candidate) - current) * signf(direction)
		if candidate != target and gap > 0.0 and gap < best_gap:
			best = candidate
			best_gap = gap
	lock(best)


## The lockable target nearest the centre of the view, or null.
func find_best_target() -> LockOnTarget:
	var best: LockOnTarget = null
	var best_angle := INF
	for candidate in _candidates():
		var angle := _view_angle(candidate)
		if angle < best_angle:
			best = candidate
			best_angle = angle
	return best


## Every target that could be locked onto right now.
func _candidates() -> Array[LockOnTarget]:
	var result: Array[LockOnTarget] = []
	for node in get_tree().get_nodes_in_group(LockOnTarget.GROUP):
		var candidate := node as LockOnTarget
		if (
			_is_valid(candidate)
			and _distance_to(candidate) <= max_distance
			and _view_angle(candidate) <= deg_to_rad(max_angle_degrees)
			and _has_line_of_sight(candidate)
		):
			result.append(candidate)
	return result


func _is_valid(candidate: LockOnTarget) -> bool:
	return is_instance_valid(candidate) and candidate.is_inside_tree() and candidate.enabled


func _distance_to(candidate: LockOnTarget) -> float:
	return origin.global_position.distance_to(candidate.global_position)


func _camera() -> Camera3D:
	return orbit_camera.get_camera() if orbit_camera != null else get_viewport().get_camera_3d()


## Angle between where the camera looks and the target, in radians.
func _view_angle(candidate: LockOnTarget) -> float:
	var camera := _camera()
	var to_target := candidate.global_position - camera.global_position
	return (-camera.global_basis.z).angle_to(to_target)


## Horizontal angle of the target as seen by the camera: negative is left.
func _screen_angle(candidate: LockOnTarget) -> float:
	var local := _camera().global_transform.affine_inverse() * candidate.global_position
	return atan2(local.x, -local.z)


func _has_line_of_sight(candidate: LockOnTarget) -> bool:
	if not requires_line_of_sight:
		return true
	var from := _camera().global_position
	var query := PhysicsRayQueryParameters3D.create(from, candidate.global_position, 1)
	return origin.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
