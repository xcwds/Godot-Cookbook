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
	var transform: Transform3D = data["transform"]
	if parent.has_method(&"teleport"):
		# The cookbook's characters stop what they were doing and clear their
		# timers. Their own load_data() restores where they look or face.
		parent.teleport(transform)
		parent.global_transform = transform
	else:
		parent.global_transform = transform
		if parent is CharacterBody3D:
			parent.velocity = Vector3.ZERO
	if parent is CharacterBody3D or parent is AnimatableBody3D:
		_place_kinematic_body_now(parent)
	# A teleport, not a move: do not draw a slide between the two places.
	parent.reset_physics_interpolation()


## The parent was gone when the game was saved.
func load_missing() -> void:
	get_parent().queue_free()


## The physics server moves a kinematic body to a new transform only during
## its next step, so for that one step areas still see it where the scene put
## it, and a pickup or checkpoint at the level's start would fire on load.
## Switching the body to static for a moment moves it at once.
func _place_kinematic_body_now(body: PhysicsBody3D) -> void:
	var rid := body.get_rid()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_KINEMATIC)
