extends "res://tests/support/test_case.gd"
## Headless test for recipes/hitbox. Run with:
##   godot --headless --path . -s tests/test_hitbox.gd

const HITBOX := preload("res://recipes/hitbox/hitbox.tscn")
const HURTBOX := preload("res://recipes/hitbox/hurtbox.tscn")
const FAR_AWAY := Vector3(100, 0, 0)


func _make_hitbox(at := Vector3.ZERO) -> Hitbox:
	var hitbox: Hitbox = HITBOX.instantiate()
	hitbox.position = at
	_spawn(hitbox)
	return hitbox


## A hurtbox at the origin wired to its own Health.
func _make_target(max_health := 10.0) -> Hurtbox:
	var health := Health.new()
	health.max_health = max_health
	var hurtbox: Hurtbox = HURTBOX.instantiate()
	hurtbox.health = health
	hurtbox.add_child(health)
	_spawn(hurtbox)
	return hurtbox


func test_hits_once_per_visit() -> void:
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


func test_interval_repeats_hits() -> void:
	var target := _make_target()
	var hitbox := _make_hitbox()
	hitbox.hit_interval = 0.2
	await _wait(0.75)
	var lost: float = 10.0 - target.health.current_health
	_check(lost >= 3.0 and lost <= 4.0, "repeats every interval while inside, lost %s" % lost)


func test_same_team_is_ignored() -> void:
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


func test_inactive_then_activated() -> void:
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


func test_invulnerability_time() -> void:
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

	# Two once-per-visit hitboxes arrive together: the second is refused at
	# first, and must still land once the invulnerability ends.
	target = _make_target()
	target.invulnerability_time = 0.3
	var first := _make_hitbox()
	var second := _make_hitbox()
	await _wait(0.15)
	_check(target.health.current_health == 9.0, "only one of two simultaneous hits lands")
	await _wait(0.4)
	_check(target.health.current_health == 8.0, "the refused one lands after invulnerability")
	await _wait(0.5)
	_check(target.health.current_health == 8.0, "and each still hits only once per visit")


func test_works_without_health() -> void:
	var hurtbox: Hurtbox = HURTBOX.instantiate()
	_spawn(hurtbox)
	var amounts: Array = []
	hurtbox.hit.connect(func(_from: Hitbox, amount: float) -> void: amounts.append(amount))
	var hitbox := _make_hitbox()
	hitbox.damage = 2.5
	await _wait(0.1)
	_check(amounts == [2.5], "a hurtbox without Health still reports the hit")
