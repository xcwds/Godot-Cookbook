class_name CameraDirector
extends Node
## Plays scripted camera shots: takes the view from the current camera, blends
## to one [CameraShot] after another, then blends back and returns the view.
## For cutscenes and for showing the player a point of interest.
##
## It knows nothing about the gameplay camera or the character. It takes over
## with [method Camera3D.make_current] and tells the game through signals
## when to stop and resume player input.

## Emitted when the camera starts moving to a shot.
signal shot_started(shot: CameraShot)
## Emitted when a shot's hold time is over. Not emitted for a shot that was
## cut short by [method stop] or by playing something else.
signal shot_finished(shot: CameraShot)
## Emitted once when the view is back with the camera it was taken from.
signal sequence_finished
## Emitted when shots start playing, if [member locks_input] is on. Stop
## reading player input here.
signal input_locked
## Emitted together with [signal sequence_finished], if [signal input_locked]
## was emitted before.
signal input_unlocked

enum Phase { IDLE, BLEND, HOLD, RETURN }

## Ask the game to stop player input while shots play, through
## [signal input_locked] and [signal input_unlocked].
@export var locks_input := true
## Seconds to blend back to the gameplay camera after the last shot.
@export var return_blend_time := 1.0
## Shape of every blend. Below zero eases in and out, 1 is linear.
@export_exp_easing("inout") var easing := -2.0

var _phase := Phase.IDLE
var _queue: Array[CameraShot] = []
var _shot: CameraShot
var _previous_camera: Camera3D
var _input_is_locked := false
var _time := 0.0
var _duration := 0.0
var _from_view := Transform3D.IDENTITY
var _from_fov := 75.0

@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	# Moved every frame, so it must not be interpolated between physics ticks.
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _exit_tree() -> void:
	if is_playing():
		stop()


func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_time += delta
	match _phase:
		Phase.BLEND:
			if not is_instance_valid(_shot):
				_next_shot()
			elif _time >= _duration:
				# Time left over from the blend counts toward the hold.
				_time -= _duration
				_phase = Phase.HOLD
				_show(_shot.get_view(), _shot.fov)
			else:
				_blend_toward(_shot.get_view(), _shot.fov)
		Phase.HOLD:
			if not is_instance_valid(_shot):
				_next_shot()
			else:
				_show(_shot.get_view(), _shot.fov)
				if _shot.hold_time >= 0.0 and _time >= _shot.hold_time:
					shot_finished.emit(_shot)
					# A handler of the signal may have played or stopped.
					if _phase == Phase.HOLD:
						_next_shot()
		Phase.RETURN:
			if _time >= _duration or not _can_return_to_previous():
				_finish()
			else:
				var view := _previous_camera.get_global_transform_interpolated()
				_blend_toward(view, _previous_camera.fov)


## Plays one shot and then returns to the gameplay camera.
func play(shot: CameraShot) -> void:
	play_sequence([shot])


## Plays shots one after the other and then returns to the gameplay camera.
## Called while shots are playing, it replaces them: the camera goes on from
## where it is, and [signal sequence_finished] comes once, at the very end.
func play_sequence(shots: Array[CameraShot]) -> void:
	_queue.clear()
	for shot in shots:
		if is_instance_valid(shot):
			_queue.append(shot)
	if _queue.is_empty():
		return
	if _phase == Phase.IDLE:
		_previous_camera = get_viewport().get_camera_3d()
		if _previous_camera == _camera:
			_previous_camera = null
		if _previous_camera != null:
			# Start from what the player sees this frame.
			_show(_previous_camera.get_global_transform_interpolated(), _previous_camera.fov)
		_camera.make_current()
		if locks_input:
			_input_is_locked = true
			input_locked.emit()
	_next_shot()


## Ends the shots early and returns to the gameplay camera: at once, or with
## a blend of the given length.
func stop(blend_time := 0.0) -> void:
	if _phase == Phase.IDLE:
		return
	_queue.clear()
	_shot = null
	if blend_time <= 0.0 or not _can_return_to_previous():
		_finish()
	elif _phase != Phase.RETURN:
		_start_return(blend_time)


func is_playing() -> bool:
	return _phase != Phase.IDLE


## The shot the camera is moving to or holding, or null.
func get_current_shot() -> CameraShot:
	return _shot if is_instance_valid(_shot) else null


func get_camera() -> Camera3D:
	return _camera


func _next_shot() -> void:
	_shot = null
	while _shot == null and not _queue.is_empty():
		var next: CameraShot = _queue.pop_front()
		if is_instance_valid(next):
			_shot = next
	if _shot == null:
		_start_return(return_blend_time)
		return
	_start_blend(_shot.blend_time)
	_phase = Phase.BLEND
	if _duration <= 0.0:
		_phase = Phase.HOLD
		_show(_shot.get_view(), _shot.fov)
	shot_started.emit(_shot)


func _start_return(blend_time: float) -> void:
	if blend_time <= 0.0 or not _can_return_to_previous():
		_finish()
		return
	_start_blend(blend_time)
	_phase = Phase.RETURN


func _start_blend(duration: float) -> void:
	_from_view = _camera.global_transform
	_from_fov = _camera.fov
	_time = 0.0
	_duration = duration


func _finish() -> void:
	_phase = Phase.IDLE
	_queue.clear()
	_shot = null
	if _can_return_to_previous():
		_previous_camera.make_current()
	elif _camera.is_inside_tree():
		_camera.clear_current()
	_previous_camera = null
	if _input_is_locked:
		_input_is_locked = false
		input_unlocked.emit()
	sequence_finished.emit()


func _can_return_to_previous() -> bool:
	return is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree()


func _blend_toward(view: Transform3D, fov: float) -> void:
	var weight := ease(clampf(_time / _duration, 0.0, 1.0), easing)
	var from_rotation := _from_view.basis.get_rotation_quaternion()
	var rotation := from_rotation.slerp(view.basis.get_rotation_quaternion(), weight)
	var origin := _from_view.origin.lerp(view.origin, weight)
	_show(Transform3D(Basis(rotation), origin), lerpf(_from_fov, fov, weight))


func _show(view: Transform3D, fov: float) -> void:
	_camera.global_transform = view
	_camera.fov = fov
