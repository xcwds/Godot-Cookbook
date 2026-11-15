class_name Projectile
extends Node3D
## Flies straight ahead (along its -Z axis) until it hits something or its
## lifetime runs out. Each physics tick it checks the whole distance it
## travels, so it cannot pass through a thin wall however fast it goes.

## Emitted when it is put into the world.
signal launched
## Emitted when it hits something on [member collision_mask], just before
## it despawns. [param collision] is the result of the ray query, with
## [code]collider[/code], [code]position[/code] and [code]normal[/code].
signal hit(collision: Dictionary)
## Emitted when it leaves the world, by hitting or by timing out.
signal despawned

@export var speed := 30.0
## Seconds before it disappears by itself.
@export var lifetime := 3.0
## 0 flies level; 1 falls like everything else.
@export var gravity_scale := 0.0
## Physics layers that stop it.
@export_flags_3d_physics var collision_mask := 1

var velocity := Vector3.ZERO

var _age := 0.0
var _is_flying := false


func _physics_process(delta: float) -> void:
	if not _is_flying:
		return
	_age += delta
	if _age >= lifetime:
		despawn()
		return

	velocity += get_gravity() * gravity_scale * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	var collision := get_world_3d().direct_space_state.intersect_ray(query)
	if collision.is_empty():
		global_position = to
		# look_at() cannot point straight up or down.
		var is_vertical := absf(velocity.normalized().dot(Vector3.UP)) > 0.999
		if velocity.length_squared() > 0.0001 and not is_vertical:
			look_at(to + velocity)
	else:
		global_position = collision["position"]
		hit.emit(collision)
		despawn()


## Starts the projectile at [param from], flying along its -Z axis.
func launch(from: Transform3D) -> void:
	global_transform = from
	velocity = -from.basis.z.normalized() * speed
	_age = 0.0
	_is_flying = true
	launched.emit()


## Takes the projectile out of the world: back to its pool if it came from
## one, otherwise freed.
func despawn() -> void:
	if not _is_flying:
		return
	_is_flying = false
	despawned.emit()
	ObjectPool.release_or_free(self)


func get_gravity() -> Vector3:
	return (
		ProjectSettings.get_setting("physics/3d/default_gravity")
		* ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	)
