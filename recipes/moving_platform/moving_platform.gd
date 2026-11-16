class_name MovingPlatform
extends AnimatableBody3D
## A platform that travels between waypoints and carries whatever stands on
## it. Characters ride it without any code of their own: a
## [CharacterBody3D] picks up the motion of an [AnimatableBody3D] floor.

## Emitted on arrival. Index 0 is where the platform started.
signal waypoint_reached(index: int)

enum LoopMode {
	## Go to the last waypoint, then back the way it came.
	PING_PONG,
	## Go to the last waypoint, then straight back to the start.
	LOOP,
	## Go to the last waypoint and stop, with [member active] off. Turning
	## [member active] back on sends it back the way it came, where it stops
	## again: a lift or a door worked by a switch.
	ONCE,
}

## Where to go, as offsets from the starting position. The start is always
## the first stop.
@export var waypoints: Array[Vector3] = [Vector3(0, 0, -6)]
## Metres per second, averaged over each leg.
@export var speed := 2.0
## Seconds to wait at each stop.
@export var wait_time := 1.0
@export var loop_mode := LoopMode.PING_PONG
## Speed up and slow down at each end instead of moving at a constant rate.
@export var ease_in_out := true
## Whether the platform is moving. Turn it on from a switch or a trigger.
@export var active := true

var _stops: Array[Vector3] = []
var _from := 0
var _to := 1
var _direction := 1
var _progress := 0.0
var _wait_left := 0.0


func _ready() -> void:
	_stops = [global_position]
	for offset in waypoints:
		_stops.append(global_position + offset)


func _physics_process(delta: float) -> void:
	if not active or _stops.size() < 2:
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		return

	var from := _stops[_from]
	var to := _stops[_to]
	var distance := from.distance_to(to)
	_progress = 1.0 if distance < 0.001 else _progress + speed * delta / distance
	if _progress < 1.0:
		var weight := smoothstep(0.0, 1.0, _progress) if ease_in_out else _progress
		global_position = from.lerp(to, weight)
	else:
		global_position = to
		_arrive()


## The stop the platform is heading for, or resting at.
func get_target_index() -> int:
	return _to


func _arrive() -> void:
	var arrived := _to
	_progress = 0.0
	_wait_left = wait_time
	_from = arrived
	var last := _stops.size() - 1
	match loop_mode:
		LoopMode.PING_PONG:
			if arrived == last:
				_direction = -1
			elif arrived == 0:
				_direction = 1
			_to = arrived + _direction
		LoopMode.LOOP:
			_to = (arrived + 1) % _stops.size()
		LoopMode.ONCE:
			if arrived == (last if _direction == 1 else 0):
				# Finished. Ready to go back the other way when activated
				# again, without waiting first.
				active = false
				_direction = -_direction
				_wait_left = 0.0
			_to = arrived + _direction
	waypoint_reached.emit(arrived)
