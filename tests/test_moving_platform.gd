extends "res://tests/support/test_case.gd"
## Headless test for recipes/moving_platform. Run with:
##   godot --headless --path . -s tests/test_moving_platform.gd

const PLATFORM := preload("res://recipes/moving_platform/moving_platform.tscn")
const CHARACTER := preload("res://recipes/third_person_movement/third_person_character.tscn")
const FIRST_PERSON := preload("res://recipes/first_person_movement/first_person_character.tscn")


func _make(
	at: Vector3, waypoints: Array[Vector3], speed := 4.0, wait_time := 0.0
) -> MovingPlatform:
	var platform: MovingPlatform = PLATFORM.instantiate()
	platform.position = at
	platform.waypoints = waypoints
	platform.speed = speed
	platform.wait_time = wait_time
	_spawn(platform)
	return platform


func test_ping_pong() -> void:
	var platform := _make(Vector3(0, 0, 0), [Vector3(4, 0, 0)], 4.0, 0.5)
	var reached: Array = []
	platform.waypoint_reached.connect(func(index: int) -> void: reached.append(index))
	await _wait(0.5)
	var halfway := platform.position.x
	_check(
		halfway > 1.5 and halfway < 2.5, "half way after half the travel time, at %.2f" % halfway
	)
	await _wait(0.6)
	_check(platform.position.is_equal_approx(Vector3(4, 0, 0)), "arrives at the waypoint")
	_check(reached == [1], "and says so")
	await _wait(0.3)
	_check(platform.position.is_equal_approx(Vector3(4, 0, 0)), "waits there")
	await _wait(1.4)
	_check(platform.position.is_equal_approx(Vector3.ZERO), "then returns to the start")
	_check(reached == [1, 0], "reporting stop 0")


func test_loop_and_once() -> void:
	var legs: Array[Vector3] = [Vector3(2, 0, 0), Vector3(2, 0, 2)]
	var loop := _make(Vector3(0, 0, 0), legs)
	loop.loop_mode = MovingPlatform.LoopMode.LOOP
	var once := _make(Vector3(0, 5, 0), legs)
	once.loop_mode = MovingPlatform.LoopMode.ONCE
	var loop_stops: Array = []
	loop.waypoint_reached.connect(func(index: int) -> void: loop_stops.append(index))
	await _wait(2.6)
	_check(
		loop_stops.slice(0, 4) == [1, 2, 0, 1],
		"loop visits 1, 2, back to 0, then 1: %s" % [loop_stops]
	)
	_check(once.position.is_equal_approx(Vector3(2, 5, 2)), "once stops at the last waypoint")
	_check(not once.active, "and switches itself off")

	# Activated again, it returns the way it came and stops at the start.
	var once_stops: Array = []
	once.waypoint_reached.connect(func(index: int) -> void: once_stops.append(index))
	once.active = true
	await _wait(0.1)
	_check(once.active and once_stops.is_empty(), "activating again starts it moving")
	_check(once.position.z < 2.0, "back toward the previous waypoint: %s" % once.position)
	await _wait(2.6)
	_check_eq(once_stops, [1, 0], "it visits the waypoints in reverse")
	_check(once.position.is_equal_approx(Vector3(0, 5, 0)), "and stops at the start")
	_check(not once.active, "switched off again")
	once.active = true
	await _wait(2.6)
	_check(once.position.is_equal_approx(Vector3(2, 5, 2)), "a third run goes out again")


func test_inactive_platform_stays_put() -> void:
	var platform := _make(Vector3(0, 0, 0), [Vector3(4, 0, 0)])
	platform.active = false
	await _wait(0.5)
	_check(platform.position == Vector3.ZERO, "an inactive platform does not move")
	platform.active = true
	await _wait(0.5)
	_check(platform.position.x > 1.0, "and moves once activated")
	platform.free()


## Puts a character on top of a platform and lets it settle.
func _stand_on(
	platform: MovingPlatform, scene: PackedScene, origin_height: float
) -> CharacterBody3D:
	var character: CharacterBody3D = scene.instantiate()
	character.position = platform.position + Vector3(0, 0.2 + origin_height + 0.05, 0)
	_spawn(character)
	await _wait(0.5)
	return character


func test_carries_a_character_sideways() -> void:
	for case: Array in [[CHARACTER, 1.09, "third-person"], [FIRST_PERSON, 0.0, "first-person"]]:
		var platform := _make(Vector3(0, 0, 0), [Vector3(8, 0, 0)], 2.0)
		platform.active = false
		var character := await _stand_on(platform, case[0], case[1])
		_check(character.is_on_floor(), "%s character stands on the platform" % case[2])
		platform.active = true
		await _wait(3.0)
		var offset := character.position.x - platform.position.x
		_check(platform.position.x > 5.0, "platform has travelled")
		_check(absf(offset) < 0.3, "%s character rode along, %.2f m off centre" % [case[2], offset])
		_check(character.is_on_floor(), "and is still standing on it")
		character.free()
		platform.free()


func test_carries_a_character_up_and_down() -> void:
	var platform := _make(Vector3(0, 0, 0), [Vector3(0, 5, 0)], 2.0)
	platform.active = false
	var character := await _stand_on(platform, CHARACTER, 1.09)
	var height: float = character.position.y - platform.position.y
	platform.active = true
	await _wait(1.5)
	_check(platform.position.y > 2.0, "platform is rising")
	var rising: float = character.position.y - platform.position.y
	_check(absf(rising - height) < 0.1, "character rises with it, %.2f vs %.2f" % [rising, height])
	await _wait(2.5)
	_check(platform.position.y < 4.5, "platform is coming down")
	var falling: float = character.position.y - platform.position.y
	_check(absf(falling - height) < 0.15, "character comes down with it, %.2f" % falling)
	character.free()
