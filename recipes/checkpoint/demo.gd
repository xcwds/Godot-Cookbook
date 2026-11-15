extends Node3D
## Dying on the spikes sends the player back to the last checkpoint.

@onready var _health: Health = $Player/Health
@onready var _respawner: Respawner = $Player/Respawner
@onready var _camera: OrbitCamera = $OrbitCamera
@onready var _message: Label = %Message


func _ready() -> void:
	# The two lines that tie health to respawning.
	_health.died.connect(_respawner.respawn)
	_respawner.respawned.connect(func(_spawn: Transform3D) -> void: _health.reset())
	# Without this the camera eases across the level to the checkpoint.
	_respawner.respawned.connect(func(_spawn: Transform3D) -> void: _camera.snap_to_target())

	_respawner.checkpoint_changed.connect(
		func(checkpoint: Checkpoint) -> void: _message.text = "Checkpoint: %s" % checkpoint.name
	)
