extends Node3D
## Walking onto the pad plays two shots of the door, which opens during the
## second one. The player and the orbit camera stand still meanwhile.

const DOOR_OPEN_HEIGHT := 3.2

var _played := false

@onready var _player: ThirdPersonCharacter = $Player
@onready var _orbit_camera: OrbitCamera = $OrbitCamera
@onready var _director: CameraDirector = $CameraDirector
@onready var _wide_shot: CameraShot = $Shots/Wide
@onready var _close_shot: CameraShot = $Shots/Close
@onready var _door: Node3D = $Doorway/Door
@onready var _status: Label = %Status


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$Trigger.body_entered.connect(_on_trigger_entered)
	_director.input_locked.connect(_on_input_locked)
	_director.input_unlocked.connect(_on_input_unlocked)
	_director.shot_started.connect(_on_shot_started)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") and _director.is_playing():
		_director.stop(0.3)


func _on_trigger_entered(body: Node3D) -> void:
	if body == _player and not _played:
		_played = true
		_director.play_sequence([_wide_shot, _close_shot])


func _on_input_locked() -> void:
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_orbit_camera.deactivate()
	_status.text = "Playing. Press Enter or the bottom face button to skip."


func _on_input_unlocked() -> void:
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_orbit_camera.activate()
	_status.text = "Done. The door is open."


func _on_shot_started(shot: CameraShot) -> void:
	if shot == _close_shot:
		var tween := create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_interval(shot.blend_time)
		tween.tween_property(_door, "position:y", DOOR_OPEN_HEIGHT, 1.5).as_relative()
