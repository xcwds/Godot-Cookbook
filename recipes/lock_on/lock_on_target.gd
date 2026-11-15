class_name LockOnTarget
extends Node3D
## Marks something that can be locked onto. Put it where the camera should
## aim, such as the chest of an enemy.

const GROUP := &"lock_on_targets"

## Turn off to make this impossible to lock onto, for example when dead.
@export var enabled := true


func _ready() -> void:
	add_to_group(GROUP)
