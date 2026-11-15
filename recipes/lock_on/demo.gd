extends Node3D
## While locked on, the character faces the target and strafes around it.

@onready var _player: ThirdPersonCharacter = $Player
@onready var _lock_on: LockOn = $Player/LockOn
@onready var _status: Label = %Status


func _ready() -> void:
	_lock_on.locked.connect(_on_locked)
	_lock_on.unlocked.connect(_on_unlocked)


func _on_locked(target: LockOnTarget) -> void:
	_player.strafe = true
	_status.text = "Locked on: %s" % target.get_parent().name


func _on_unlocked() -> void:
	_player.strafe = false
	_status.text = "Not locked on."
