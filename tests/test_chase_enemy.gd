extends SceneTree
## Headless test for recipes/chase_enemy. Run with:
##   godot --headless --path . -s tests/test_chase_enemy.gd

const LEVEL := preload("res://shared/demo_level.tscn")
const ENEMY := preload("res://recipes/chase_enemy/chase_enemy.tscn")

var _failures := 0
var _target: Node3D


func _initialize() -> void:
	await process_frame
	# The demo level inside a navigation region, baked like the demo does.
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_height = 1.75
	mesh.agent_radius = 0.5
	region.navigation_mesh = mesh
	region.add_child(LEVEL.instantiate())
	root.add_child(region)
	await _wait(0.1)
	region.bake_navigation_mesh(false)
	await _wait(0.2)

	_target = Node3D.new()
	_target.add_to_group(&"player")
	root.add_child(_target)

	await _test_ignores_a_distant_target()
	await _test_chases_and_stops_in_reach()
	await _test_needs_line_of_sight()
	await _test_walks_around_obstacles()
	await _test_gives_up_and_goes_home()
	if _failures == 0:
		print("test_chase_enemy: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _wait(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _make_enemy(at: Vector3) -> ChaseEnemy:
	var enemy: ChaseEnemy = ENEMY.instantiate()
	enemy.position = at
	root.add_child(enemy)
	return enemy


func _state(enemy: ChaseEnemy) -> StringName:
	return enemy.state_machine.state.name


func _test_ignores_a_distant_target() -> void:
	_target.position = Vector3(0, 0.5, 20)
	var enemy := _make_enemy(Vector3(0, 0.1, 0))
	await _wait(0.5)
	_check(_state(enemy) == &"Idle", "idle while the target is out of range")
	_check(enemy.position.distance_to(Vector3.ZERO) < 0.3, "and stays at its post")
	enemy.free()


func _test_chases_and_stops_in_reach() -> void:
	_target.position = Vector3(0, 0.5, 6)
	var enemy := _make_enemy(Vector3(0, 0.1, 0))
	var events: Array = []
	enemy.target_spotted.connect(func() -> void: events.append("spotted"))
	enemy.reached_target.connect(func() -> void: events.append("reached"))
	await _wait(0.3)
	_check(_state(enemy) == &"Chase", "chases a target it can see in range")
	await _wait(2.0)
	var distance := enemy.distance_to_target()
	_check(distance <= enemy.stop_distance + 0.1, "closes in, now %.2f m away" % distance)
	var settled := enemy.position
	await _wait(0.5)
	_check(enemy.position.distance_to(settled) < 0.05, "and stops there")
	_check(events == ["spotted", "reached"], "signals: %s" % [events])
	var to_target := (_target.position - enemy.position).normalized()
	_check((-enemy.global_basis.z).dot(to_target) > 0.9, "facing the target")
	enemy.free()


func _test_needs_line_of_sight() -> void:
	# A pillar stands at (8, 8), 2 m wide.
	_target.position = Vector3(8, 0.5, 11)
	var enemy := _make_enemy(Vector3(8, 0.1, 5))
	await _wait(0.5)
	_check(_state(enemy) == &"Idle", "does not notice a target behind a pillar")
	_target.position = Vector3(11, 0.5, 5)
	await _wait(0.3)
	_check(_state(enemy) == &"Chase", "notices it once it steps into view")
	enemy.free()


func _test_walks_around_obstacles() -> void:
	_target.position = Vector3(8, 0.5, 11)
	var enemy := _make_enemy(Vector3(8, 0.1, 5))
	enemy.requires_line_of_sight = false
	await _wait(4.0)
	var distance := enemy.distance_to_target()
	_check(
		distance <= enemy.stop_distance + 0.1, "paths around the pillar, now %.2f m away" % distance
	)
	enemy.free()


func _test_gives_up_and_goes_home() -> void:
	_target.position = Vector3(0, 0.5, 6)
	var enemy := _make_enemy(Vector3(0, 0.1, 0))
	var lost := [false]
	enemy.target_lost.connect(func() -> void: lost[0] = true)
	await _wait(1.0)
	_check(_state(enemy) == &"Chase" and enemy.position.z > 1.0, "chasing")
	_target.position = Vector3(0, 0.5, 40)
	await _wait(0.2)
	_check(_state(enemy) == &"Idle" and lost[0], "gives up when the target is out of range")
	await _wait(2.5)
	_check(enemy.position.distance_to(Vector3.ZERO) < 0.6, "and walks back to its post")
	enemy.free()
