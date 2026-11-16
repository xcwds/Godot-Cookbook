extends "res://tests/support/test_case.gd"
## Headless test for recipes/health and recipes/health_bar. Run with:
##   godot --headless --path . -s tests/test_health.gd


func _make(max_health := 10.0) -> Health:
	var health := Health.new()
	health.max_health = max_health
	_spawn(health)
	return health


func test_starts_full() -> void:
	var health := _make(25.0)
	_check(health.current_health == 25.0, "starts at max_health")
	_check(not health.is_dead(), "starts alive")


func test_damage_and_heal_are_clamped() -> void:
	var health := _make()
	var events: Array = []
	health.changed.connect(
		func(current: float, maximum: float) -> void: events.append([current, maximum])
	)
	_check(health.damage(4.0) == 4.0, "damage returns amount lost")
	_check(health.heal(100.0) == 4.0, "heal is clamped to max_health")
	_check(health.damage(-5.0) == 0.0, "negative damage is ignored")
	_check(events == [[6.0, 10.0], [10.0, 10.0]], "changed is emitted with current and max")


func test_died_is_emitted_once_and_dead_stays_dead() -> void:
	var health := _make()
	var deaths: Array = [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	_check(health.damage(50.0) == 10.0, "overkill only removes what is left")
	health.damage(1.0)
	_check(deaths[0] == 1, "died is emitted once")
	_check(health.heal(5.0) == 0.0 and health.is_dead(), "heal does not revive")
	health.reset()
	_check(health.current_health == 10.0, "reset revives at full health")


func test_invulnerable_ignores_damage() -> void:
	var health := _make()
	health.invulnerable = true
	_check(
		health.damage(3.0) == 0.0 and health.current_health == 10.0, "invulnerable takes no damage"
	)


func test_lowering_max_health_clamps_current() -> void:
	var health := _make()
	health.max_health = 4.0
	_check(health.current_health == 4.0, "current_health is clamped to a lower max_health")


func test_bar_follows_health() -> void:
	var health := _make(100.0)
	var bar := HealthBar2D.new()
	bar.health = health
	_spawn(bar)
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
