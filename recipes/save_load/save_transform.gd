class_name SaveTransform
extends Node
## Saves and restores where its parent is. Add it as a child of anything
## that moves: the player, a crate, a door.


func _ready() -> void:
	add_to_group(SaveGame.GROUP)


func save_data() -> Dictionary:
	var parent: Node3D = get_parent()
	return {"transform": parent.global_transform}


func load_data(data: Dictionary) -> void:
	var parent: Node3D = get_parent()
	parent.global_transform = data["transform"]
	if parent is CharacterBody3D:
		parent.velocity = Vector3.ZERO
