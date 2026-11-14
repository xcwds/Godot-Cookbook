extends SceneTree
## Headless test for recipes/hitbox. Run with:
##   godot --headless --path . -s tests/test_hitbox.gd

const HITBOX := preload("res://recipes/hitbox/hitbox.tscn")
const HURTBOX := preload("res://recipes/hitbox/hurtbox.tscn")
const FAR_AWAY := Vector3(100, 0, 0)

var _failures := 0


func _initialize() -> void:
	# Nodes only become ready once the tree is running.
	await process_frame
	await _test_hits_once_per_visit()
	await _test_interval_repeats_hits()
	await _test_same_team_is_ignored()
	await _test_inactive_then_activated()
	await _test_invulnerability_time()
	await _test_works_without_health()
	if _failures == 0:
		print("test_hitbox: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _wait(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _make_hitbox(at := Vector3.ZERO) -> Hitbox:
	var hitbox: Hitbox = HITBOX.instantiate()
	hitbox.position = at
	root.add_child(hitbox)
	return hitbox


## A hurtbox at the origin wired to its own Health.
func _make_target(max_health := 10.0) -> Hurtbox:
	var health := Health.new()
	health.max_health = max_health
	var hurtbox: Hurtbox = HURTBOX.instantiate()
	hurtbox.health = health
	hurtbox.add_child(health)
	root.add_child(hurtbox)
	return hurtbox


func _test_hits_once_per_visit() -> void:
	var target := _make_target()
	var hitbox := _make_hitbox(FAR_AWAY)
	var landed: Array = []
	var received: Array = []
	hitbox.hit_landed.connect(func(hurtbox: Hurtbox) -> void: landed.append(hurtbox))
	target.hit.connect(func(from: Hitbox, amount: float) -> void: received.append([from, amount]))
	await _wait(0.1)
	_check(target.health.current_health == 10.0, "no damage while apart")

	hitbox.position = Vector3.ZERO
	await _wait(0.5)
	_check(target.health.current_health == 9.0, "one hit on overlap, not one per tick")
	_check(landed == [target] and received == [[hitbox, 1.0]], "both sides are told once")

	hitbox.position = FAR_AWAY
	await _wait(0.1)
	hitbox.position = Vector3.ZERO
	await _wait(0.1)
	_check(target.health.current_health == 8.0, "coming back hits again")
	target.free()
	hitbox.free()


func _test_interval_repeats_hits() -> void:
	var target := _make_target()
	var hitbox := _make_hitbox()
	hitbox.hit_interval = 0.2
	await _wait(0.75)
	var lost: float = 10.0 - target.health.current_health
	_check(lost >= 3.0 and lost <= 4.0, "repeats every interval while inside, lost %s" % lost)
	target.free()
	hitbox.free()


func _test_same_team_is_ignored() -> void:
	var target := _make_target()
	target.team = &"player"
	var friendly := _make_hitbox()
	friendly.team = &"player"
	await _wait(0.1)
	_check(target.health.current_health == 10.0, "same team does no damage")
	var hostile := _make_hitbox()
	hostile.team = &"enemy"
	await _wait(0.1)
	_check(target.health.current_health == 9.0, "another team does")
	for node: Node in [target, friendly, hostile]:
		node.free()


func _test_inactive_then_activated() -> void:
	var target := _make_target()
	var hitbox := _make_hitbox()
	hitbox.active = false
	await _wait(0.2)
	_check(target.health.current_health == 10.0, "an inactive hitbox does nothing")
	hitbox.active = true
	await _wait(0.2)
	_check(target.health.current_health == 9.0, "activating hits what is already inside, once")
	hitbox.active = false
	hitbox.active = true
	await _wait(0.2)
	_check(target.health.current_health == 8.0, "each activation can hit again")
	target.free()
	hitbox.free()


func _test_invulnerability_time() -> void:
	var target := _make_target()
	target.invulnerability_time = 0.5
	var hitbox := _make_hitbox()
	hitbox.hit_interval = 0.1
	await _wait(0.4)
	_check(target.health.current_health == 9.0, "hits are ignored during invulnerability")
	await _wait(0.4)
	_check(target.health.current_health == 8.0, "and get through again afterwards")
	target.free()
	hitbox.free()


func _test_works_without_health() -> void:
	var hurtbox: Hurtbox = HURTBOX.instantiate()
	root.add_child(hurtbox)
	var amounts: Array = []
	hurtbox.hit.connect(func(_from: Hitbox, amount: float) -> void: amounts.append(amount))
	var hitbox := _make_hitbox()
	hitbox.damage = 2.5
	await _wait(0.1)
	_check(amounts == [2.5], "a hurtbox without Health still reports the hit")
	hurtbox.free()
	hitbox.free()
