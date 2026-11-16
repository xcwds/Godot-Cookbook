extends "res://tests/support/test_case.gd"
## Headless test for recipes/object_pool. Run with:
##   godot --headless --path . -s tests/test_object_pool.gd


## A scene to pool that needs nothing from any other recipe.
func _make_scene() -> PackedScene:
	var node := Node3D.new()
	node.name = "Pooled"
	var scene := PackedScene.new()
	scene.pack(node)
	node.free()
	return scene


func _make_pool(size: int, can_grow := true) -> ObjectPool:
	var pool := ObjectPool.new()
	pool.scene = _make_scene()
	pool.initial_size = size
	pool.can_grow = can_grow
	_spawn(pool)
	return pool


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


func test_release_or_free_frees_what_has_no_pool() -> void:
	var loose := Node.new()
	root.add_child(loose)
	ObjectPool.release_or_free(loose)
	await process_frame
	_check(not is_instance_valid(loose), "a node from no pool is freed")


func test_instances_keep_their_state_and_connections() -> void:
	# The pitfall the README warns about: nothing is reset between uses.
	var pool := _make_pool(1)
	var first: Node3D = pool.acquire()
	first.position = Vector3(1, 2, 3)
	var calls: Array = [0]
	first.visibility_changed.connect(func() -> void: calls[0] += 1)
	pool.release(first)
	var again: Node3D = pool.acquire()
	_check(again == first and again.position == Vector3(1, 2, 3), "state survives reuse")
	_check_eq(calls[0], 2, "and so does the connection: hidden once, shown once")
