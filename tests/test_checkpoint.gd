extends "res://tests/support/test_case.gd"
## Headless test for recipes/checkpoint. Run with:
##   godot --headless --path . -s tests/test_checkpoint.gd

const CHECKPOINT := preload("res://recipes/checkpoint/checkpoint.tscn")


## A character on the player layer, optionally with a Respawner child.
func _make_body(at: Vector3, with_respawner := true) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	body.position = at
	if with_respawner:
		var respawner := Respawner.new()
		respawner.name = "Respawner"
		body.add_child(respawner)
	_spawn(body)
	return body


func _make_checkpoint(at: Vector3) -> Checkpoint:
	var checkpoint: Checkpoint = CHECKPOINT.instantiate()
	checkpoint.position = at
	_spawn(checkpoint)
	return checkpoint


func test_respawns_at_start_without_a_checkpoint() -> void:
	var body := _make_body(Vector3(1, 2, 3))
	var respawner: Respawner = body.get_node("Respawner")
	var spawns: Array = []
	respawner.respawned.connect(func(spawn: Transform3D) -> void: spawns.append(spawn.origin))
	body.position = Vector3(30, 5, 30)
	body.velocity = Vector3(9, 9, 9)
	respawner.respawn()
	_check(body.position.is_equal_approx(Vector3(1, 2, 3)), "returns to where it started")
	_check(body.velocity == Vector3.ZERO, "velocity is cleared")
	_check(
		spawns.size() == 1 and spawns[0].is_equal_approx(Vector3(1, 2, 3)), "respawned is emitted"
	)


func test_walking_in_activates_and_respawns_there() -> void:
	var body := _make_body(Vector3(50, 1, 0))
	var respawner: Respawner = body.get_node("Respawner")
	var first := _make_checkpoint(Vector3(0, 0, 0))
	var second := _make_checkpoint(Vector3(20, 0, 0))
	var changes: Array = []
	respawner.checkpoint_changed.connect(func(c: Checkpoint) -> void: changes.append(c))
	await _wait_physics_frames(4)
	_check(respawner.current_checkpoint == null, "no checkpoint to begin with")

	body.position = Vector3(0, 1, 0)
	await _wait_physics_frames(4)
	_check(respawner.current_checkpoint == first and first.is_active, "walking in activates it")

	body.position = Vector3(20, 1, 0)
	await _wait_physics_frames(4)
	_check(respawner.current_checkpoint == second, "the latest checkpoint wins")
	_check(second.is_active and not first.is_active, "the previous one is deactivated")
	_check(changes == [first, second], "checkpoint_changed is emitted for each")

	body.position = Vector3(-30, 1, 0)
	respawner.respawn()
	_check(body.position.is_equal_approx(Vector3(20, 1.2, 0)), "respawns at its spawn point")


func test_falling_below_the_limit_respawns() -> void:
	var body := _make_body(Vector3(0, 3, 0))
	var respawner: Respawner = body.get_node("Respawner")
	respawner.fall_limit_y = -5.0
	body.position = Vector3(4, -6, 4)
	await _wait_physics_frames(4)
	_check(body.position.is_equal_approx(Vector3(0, 3, 0)), "falling below fall_limit_y respawns")


func test_bodies_without_a_respawner_are_ignored() -> void:
	var checkpoint := _make_checkpoint(Vector3.ZERO)
	var body := _make_body(Vector3(0, 1, 0), false)
	await _wait_physics_frames(4)
	_check(not checkpoint.is_active, "a body without a Respawner does not activate it")
