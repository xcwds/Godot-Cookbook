extends SceneTree
## Headless test for recipes/health and recipes/health_bar. Run with:
##   godot --headless --path . -s tests/test_health.gd

var _failures := 0


func _initialize() -> void:
	# Nodes only become ready once the tree is running.
	await process_frame
	_test_starts_full()
	_test_damage_and_heal_are_clamped()
	_test_died_is_emitted_once_and_dead_stays_dead()
	_test_invulnerable_ignores_damage()
	_test_lowering_max_health_clamps_current()
	_test_bar_follows_health()
	if _failures == 0:
		print("test_health: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _make(max_health := 10.0) -> Health:
	var health := Health.new()
	health.max_health = max_health
	root.add_child(health)
	return health


func _test_starts_full() -> void:
	var health := _make(25.0)
	_check(health.current_health == 25.0, "starts at max_health")
	_check(not health.is_dead(), "starts alive")
	health.free()


func _test_damage_and_heal_are_clamped() -> void:
	var health := _make()
	var events: Array = []
	health.changed.connect(
		func(current: float, maximum: float) -> void: events.append([current, maximum])
	)
	_check(health.damage(4.0) == 4.0, "damage returns amount lost")
	_check(health.heal(100.0) == 4.0, "heal is clamped to max_health")
	_check(health.damage(-5.0) == 0.0, "negative damage is ignored")
	_check(events == [[6.0, 10.0], [10.0, 10.0]], "changed is emitted with current and max")
	health.free()


func _test_died_is_emitted_once_and_dead_stays_dead() -> void:
	var health := _make()
	var deaths: Array = [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	_check(health.damage(50.0) == 10.0, "overkill only removes what is left")
	health.damage(1.0)
	_check(deaths[0] == 1, "died is emitted once")
	_check(health.heal(5.0) == 0.0 and health.is_dead(), "heal does not revive")
	health.reset()
	_check(health.current_health == 10.0, "reset revives at full health")
	health.free()


func _test_invulnerable_ignores_damage() -> void:
	var health := _make()
	health.invulnerable = true
	_check(
		health.damage(3.0) == 0.0 and health.current_health == 10.0, "invulnerable takes no damage"
	)
	health.free()


func _test_lowering_max_health_clamps_current() -> void:
	var health := _make()
	health.max_health = 4.0
	_check(health.current_health == 4.0, "current_health is clamped to a lower max_health")
	health.free()


func _test_bar_follows_health() -> void:
	var health := _make(100.0)
	var bar := HealthBar2D.new()
	bar.health = health
	root.add_child(bar)
	_check(bar.max_value == 100.0 and bar.value == 100.0, "bar shows initial values")
	_check(bar.tint_progress == bar.high_color, "full bar uses high_color")
	health.damage(50.0)
	_check(
		bar.value == 50.0 and bar.tint_progress == bar.mid_color, "bar follows damage, mid_color"
	)
	health.damage(30.0)
	_check(bar.value == 20.0 and bar.tint_progress == bar.low_color, "low_color below threshold")
	bar.health = null
	health.reset()
	_check(bar.value == 20.0, "bar stops following after health is cleared")
	bar.free()
	health.free()
