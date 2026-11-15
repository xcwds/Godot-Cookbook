extends Node3D
## Dying on the spikes sends the player back to the last checkpoint.

@onready var _health: Health = $Player/Health
@onready var _respawner: Respawner = $Player/Respawner
@onready var _message: Label = %Message


func _ready() -> void:
	# The two lines that tie health to respawning.
	_health.died.connect(_respawner.respawn)
	_respawner.respawned.connect(func(_spawn: Transform3D) -> void: _health.reset())

	_respawner.checkpoint_changed.connect(
		func(checkpoint: Checkpoint) -> void: _message.text = "Checkpoint: %s" % checkpoint.name
	)
