extends "res://tests/support/test_case.gd"
## Headless test for recipes/projectile. Run with:
##   godot --headless --path . -s tests/test_projectile.gd

const PROJECTILE := preload("res://recipes/projectile/projectile.tscn")


func _before_all() -> void:
	# Launchers put their pool beside the current scene, so there must be one.
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene


func _make_pool(size: int, can_grow := true) -> ObjectPool:
	var pool := ObjectPool.new()
	pool.scene = PROJECTILE
	pool.initial_size = size
	pool.can_grow = can_grow
	current_scene.add_child(pool)
	return pool


func _make_wall(z: float, thickness := 0.5) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, thickness)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 0, z)
	current_scene.add_child(wall)
	return wall


func test_pool_reuses_instances() -> void:
	var pool := _make_pool(2)
	_check(pool.get_total_count() == 2 and pool.get_active_count() == 0, "pool is filled up front")
	var first := pool.acquire()
	_check(first.visible and first.process_mode == Node.PROCESS_MODE_INHERIT, "acquired is active")
	_check(pool.get_active_count() == 1, "and counted as active")
	pool.release(first)
	pool.release(first)
	_check(pool.get_active_count() == 0, "release puts it back, once")
	_check(
		not first.visible and first.process_mode == Node.PROCESS_MODE_DISABLED, "and disables it"
	)
	_check(pool.acquire() == first, "the same instance is handed out again")

	pool.acquire()
	var third := pool.acquire()
	_check(third != null and pool.get_total_count() == 3, "the pool grows when it runs out")
	ObjectPool.release_or_free(third)
	_check(pool.get_active_count() == 2, "release_or_free returns a pooled node to its pool")


func test_pool_that_cannot_grow() -> void:
	var pool := _make_pool(1, false)
	_check(pool.acquire() != null, "hands out what it has")
	_check(pool.acquire() == null, "then returns null when it cannot grow")


func test_projectile_flies_and_times_out() -> void:
	var pool := _make_pool(1)
	var projectile: Projectile = pool.acquire()
	projectile.speed = 10.0
	projectile.lifetime = 0.5
	var events: Array = []
	projectile.launched.connect(func() -> void: events.append("launched"))
	projectile.despawned.connect(func() -> void: events.append("despawned"))
	# Facing +X.
	projectile.launch(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(0, 2, 0)))
	await _wait(0.25)
	var travelled := projectile.global_position.x
	_check(
		travelled > 2.0 and travelled < 3.0, "flies along its -Z axis at speed, at %.2f" % travelled
	)
	_check(is_equal_approx(projectile.global_position.y, 2.0), "level, with no gravity by default")
	await _wait(0.4)
	_check(pool.get_active_count() == 0, "returns to the pool when its lifetime ends")
	_check(events == ["launched", "despawned"], "signals: %s" % [events])


func test_projectile_stops_at_a_wall() -> void:
	var pool := _make_pool(1)
	var wall := _make_wall(-5.0)
	await _wait(0.1)
	var projectile: Projectile = pool.acquire()
	var hits: Array = []
	projectile.hit.connect(func(collision: Dictionary) -> void: hits.append(collision))
	projectile.launch(Transform3D(Basis.IDENTITY, Vector3.ZERO))
	await _wait(0.5)
	_check(hits.size() == 1 and hits[0]["collider"] == wall, "hit is emitted with the collider")
	_check(is_equal_approx(hits[0]["position"].z, -4.75), "at the wall's surface")
	_check(pool.get_active_count() == 0, "and it returns to the pool")


func test_fast_projectile_does_not_tunnel() -> void:
	var pool := _make_pool(1)
	var wall := _make_wall(-5.0, 0.05)
	await _wait(0.1)
	var projectile: Projectile = pool.acquire()
	# 10 m per physics tick, through a 5 cm wall.
	projectile.speed = 600.0
	var hits := [0]
	projectile.hit.connect(func(_collision: Dictionary) -> void: hits[0] += 1)
	projectile.launch(Transform3D(Basis.IDENTITY, Vector3.ZERO))
	await _wait(0.2)
	_check(hits[0] == 1, "a very fast projectile still hits a thin wall")


func test_launcher() -> void:
	var launcher := ProjectileLauncher.new()
	launcher.projectile_scene = PROJECTILE
	launcher.fire_rate = 10.0
	launcher.position = Vector3(0, 1, 0)
	launcher.rotation.y = PI / 2.0
	current_scene.add_child(launcher)
	await _wait(0.1)
	_check(launcher.pool != null and launcher.pool.is_inside_tree(), "makes its own pool")

	var shot := launcher.fire()
	_check(shot != null, "fires")
	_check(shot.global_position.is_equal_approx(Vector3(0, 1, 0)), "from where the launcher is")
	_check(shot.velocity.normalized().is_equal_approx(Vector3.LEFT), "along the launcher's -Z axis")
	_check(launcher.fire() == null, "not again before the cooldown")
	await _wait(0.15)
	_check(launcher.fire() != null, "again after it")

	# Sustained fire: short-lived shots are reused, so the pool stays small.
	var fired := [0]
	launcher.fired.connect(func(_projectile: Projectile) -> void: fired[0] += 1)
	launcher.pool.free()
	launcher.pool = _make_pool(0)
	for i in 90:
		var projectile := launcher.fire()
		if projectile != null:
			projectile.lifetime = 0.3
		await physics_frame
	_check(fired[0] >= 10, "kept firing, %d shots" % fired[0])
	_check(
		launcher.pool.get_total_count() <= 4,
		"reusing %d instances" % launcher.pool.get_total_count()
	)
	launcher.pool.free()
	launcher.free()
