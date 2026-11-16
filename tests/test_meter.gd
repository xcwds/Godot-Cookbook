extends "res://tests/support/test_case.gd"
## Headless test for recipes/meter. Run with:
##   godot --headless --path . -s tests/test_meter.gd

const BAR_ALIAS_FIXTURE := "res://tests/health_bar_alias_fixture.tscn"


## A meter in the tree, with every signal it emits recorded in order.
func _make(maximum := 10.0, start_full := true) -> Meter:
	var meter := Meter.new()
	meter.maximum = maximum
	meter.start_full = start_full
	_spawn(meter)
	return meter


func _record(meter: Meter) -> Array:
	var events: Array = []
	meter.changed.connect(
		func(current: float, maximum: float) -> void: events.append([current, maximum])
	)
	meter.depleted.connect(func() -> void: events.append("depleted"))
	meter.filled.connect(func() -> void: events.append("filled"))
	return events


func test_starts_full_or_empty() -> void:
	var full := _make(25.0)
	_check_eq(full.current, 25.0, "starts at maximum")
	_check(full.is_full() and not full.is_empty(), "and is full")
	var empty := _make(25.0, false)
	_check_eq(empty.current, 0.0, "start_full off starts at zero")
	_check(empty.is_empty() and not empty.is_full(), "and is empty")


func test_starting_full_does_not_emit_filled() -> void:
	var meter := Meter.new()
	var events := _record(meter)
	_spawn(meter)
	_check_eq(events, [[10.0, 10.0]], "entering the tree emits changed only")


func test_add_and_drain_are_clamped() -> void:
	var meter := _make()
	_check_eq(meter.drain(4.0), 4.0, "drain returns the amount removed")
	_check_eq(meter.add(100.0), 4.0, "add is clamped to the maximum")
	_check_eq(meter.drain(100.0), 10.0, "drain is clamped at zero")
	_check_eq(meter.current, 0.0, "and leaves zero")
	_check_eq(meter.add(-5.0), 0.0, "a negative add is ignored")
	_check_eq(meter.drain(-5.0), 0.0, "a negative drain is ignored")
	meter.current = 99.0
	_check_eq(meter.current, 10.0, "setting current clamps to the maximum")
	meter.current = -1.0
	_check_eq(meter.current, 0.0, "and to zero")


func test_spend_is_all_or_nothing() -> void:
	var meter := _make()
	_check(meter.spend(6.0), "spend succeeds when there is enough")
	_check_eq(meter.current, 4.0, "and removes the amount")
	var events := _record(meter)
	_check(not meter.spend(5.0), "spend fails when there is not enough")
	_check_eq(meter.current, 4.0, "and removes nothing")
	_check_eq(events, [], "a failed spend emits nothing")
	_check(meter.spend(4.0), "spending exactly what is left succeeds")
	_check(meter.is_empty(), "and empties the meter")
	_check(meter.spend(0.0), "a cost of nothing can always be paid")


func test_each_signal_fires_once() -> void:
	var meter := _make()
	var events := _record(meter)
	meter.drain(4.0)
	meter.drain(100.0)
	meter.drain(1.0)
	meter.empty()
	_check_eq(events, [[6.0, 10.0], [0.0, 10.0], "depleted"], "depleted once, on reaching zero")
	events.clear()
	meter.add(3.0)
	meter.fill()
	meter.fill()
	meter.add(1.0)
	_check_eq(events, [[3.0, 10.0], [10.0, 10.0], "filled"], "filled once, on reaching the maximum")
	events.clear()
	meter.add(0.0)
	meter.current = 10.0
	meter.maximum = 10.0
	_check_eq(events, [], "calls that change nothing emit nothing")


func test_changing_the_maximum() -> void:
	var meter := _make()
	var events := _record(meter)
	meter.maximum = 4.0
	_check_eq(meter.current, 4.0, "lowering the maximum clamps current")
	_check_eq(events, [[4.0, 4.0]], "and emits changed; it was full and still is")
	meter.maximum = 8.0
	_check_eq(meter.current, 4.0, "raising the maximum leaves current")
	_check_eq(meter.get_fraction(), 0.5, "fraction is current over maximum")
	events.clear()
	meter.maximum = 4.0
	_check_eq(events, [[4.0, 4.0], "filled"], "lowering the maximum onto current fills it")
	events.clear()
	meter.maximum = 0.0
	_check_eq(events, [[0.0, 0.0], "depleted"], "a maximum of zero depletes it")
	_check_eq(meter.get_fraction(), 0.0, "fraction is zero with no maximum")
	meter.maximum = -5.0
	_check_eq(meter.maximum, 0.0, "the maximum is never negative")


func test_save_data_round_trip() -> void:
	var meter := _make(20.0)
	meter.drain(20.0)
	var data := meter.save_data()
	var other := _make(5.0)
	var events := _record(other)
	other.load_data(data)
	_check(other.maximum == 20.0 and other.current == 0.0, "both values are restored")
	_check_eq(events, [[0.0, 20.0]], "loading emits changed, not depleted")
	other.load_data({})
	_check(other.maximum == 20.0 and other.current == 20.0, "an empty save fills it")
	_check(meter.is_in_group(&"saveable"), "a meter is saveable")


func test_health_is_a_meter() -> void:
	var health := Health.new()
	health.max_health = 8.0
	_spawn(health)
	var as_meter: Meter = health
	_check(as_meter.maximum == 8.0 and as_meter.current == 8.0, "max_health is maximum")
	var events: Array = []
	health.damaged.connect(func(_amount: float) -> void: events.append("damaged"))
	health.died.connect(func() -> void: events.append("died"))
	health.depleted.connect(func() -> void: events.append("depleted"))
	health.damage(8.0)
	_check_eq(events, ["depleted", "damaged", "died"], "died still follows damaged")
	health.reset()
	events.clear()
	as_meter.drain(8.0)
	_check_eq(events.count("died"), 1, "draining it as a meter kills too, once")
	_check_eq(health.save_data(), {"current": 0.0, "max": 8.0}, "health keeps its save keys")
	health.load_data({"current": 3.0, "max": 6.0})
	_check(health.current_health == 3.0 and health.max_health == 6.0, "and loads them")


func test_a_bar_shows_any_meter() -> void:
	var meter := _make(40.0)
	var bar := HealthBar2D.new()
	bar.meter = meter
	_spawn(bar)
	_check(bar.max_value == 40.0 and bar.value == 40.0, "the bar shows a plain meter")
	meter.spend(30.0)
	_check(bar.value == 10.0 and bar.tint_progress == bar.low_color, "and follows it")
	bar.meter = null
	meter.fill()
	_check_eq(bar.value, 10.0, "and stops following when cleared")


func test_the_old_health_property_still_works() -> void:
	var meter := _make(40.0)
	var bar := HealthBar2D.new()
	bar.health = meter
	_spawn(bar)
	_check(bar.meter == meter and bar.health == meter, "health is another name for meter")
	_check_eq(bar.max_value, 40.0, "and the bar follows it")
	# A scene saved before the rename sets `health`, with a node path.
	var scene: Node = _spawn((load(BAR_ALIAS_FIXTURE) as PackedScene).instantiate())
	var health: Health = scene.get_node("Health")
	health.damage(1.0)
	for bar_name: String in ["Bar2d", "Bar3d"]:
		_check(scene.get_node(bar_name).meter == health, "%s is bound through health" % bar_name)
	_check_eq(scene.get_node("Bar2d").value, 2.0, "the 2D bar follows")
	_check_eq(scene.get_node("Bar3d/SubViewport/HealthBar2d").value, 2.0, "the 3D bar follows")
