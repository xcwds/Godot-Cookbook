extends Node3D
## The free camera in both of its modes. In spectator mode the game keeps
## running, so this script takes the controls away from the player and the
## orbit camera while the free camera has them.

@onready var _player: ThirdPersonCharacter = $Player
@onready var _orbit_camera: OrbitCamera = $OrbitCamera
@onready var _free_camera: FreeCamera = $FreeCamera
@onready var _status: Label = %Status


func _ready() -> void:
	_free_camera.activated.connect(_on_activated)
	_free_camera.deactivated.connect(_on_deactivated)
	_show_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not _free_camera.active:
		_free_camera.pause_game = not _free_camera.pause_game
		_show_status()


func _on_activated() -> void:
	if not _free_camera.pause_game:
		_player.process_mode = Node.PROCESS_MODE_DISABLED
		_orbit_camera.deactivate()
	_show_status()


func _on_deactivated() -> void:
	if not _orbit_camera.active:
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		_orbit_camera.activate()
	_show_status()


func _show_status() -> void:
	var mode := (
		"Photo mode (game paused)" if _free_camera.pause_game else "Spectator (game running)"
	)
	var state := "flying" if _free_camera.active else "off"
	_status.text = "%s. Free camera: %s." % [mode, state]
