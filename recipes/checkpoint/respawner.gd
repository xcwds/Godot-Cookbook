class_name Respawner
extends Node
## Remembers the last [Checkpoint] a body reached and puts the body back
## there. Add it as a child of the character. Call [method respawn] when the
## character dies; it also respawns by itself below [member fall_limit_y].

## Emitted after the body has been moved. [param spawn] is where it was put,
## including the direction the spawn point faces.
signal respawned(spawn: Transform3D)
signal checkpoint_changed(checkpoint: Checkpoint)

const GROUP := &"respawners"

## The body to move. Defaults to the parent.
@export var body: Node3D
## Respawn when the body falls below this height.
@export var fall_limit_y := -20.0

## The checkpoint to respawn at, or null to use the starting position.
var current_checkpoint: Checkpoint

var _start: Transform3D


## The respawner that moves [param for_body], or null.
static func find_for(for_body: Node) -> Respawner:
	if not for_body.is_inside_tree():
		return null
	for node in for_body.get_tree().get_nodes_in_group(GROUP):
		var respawner := node as Respawner
		if respawner != null and respawner.body == for_body:
			return respawner
	return null


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	_start = body.global_transform
	add_to_group(GROUP)


func _physics_process(_delta: float) -> void:
	if body.global_position.y < fall_limit_y:
		respawn()


func set_checkpoint(checkpoint: Checkpoint) -> void:
	if checkpoint == current_checkpoint:
		return
	if is_instance_valid(current_checkpoint):
		current_checkpoint.set_active(false)
	current_checkpoint = checkpoint
	if current_checkpoint != null:
		current_checkpoint.set_active(true)
	checkpoint_changed.emit(current_checkpoint)


## Where the body would respawn right now.
func get_spawn_transform() -> Transform3D:
	if is_instance_valid(current_checkpoint):
		return current_checkpoint.get_spawn_transform()
	return _start


func respawn() -> void:
	var spawn := get_spawn_transform()
	body.global_position = spawn.origin
	if body is CharacterBody3D:
		body.velocity = Vector3.ZERO
	respawned.emit(spawn)
