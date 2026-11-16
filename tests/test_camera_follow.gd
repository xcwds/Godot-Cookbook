extends "res://tests/support/test_case.gd"
## Headless test that what the camera follows does not jitter against it,
## and that teleports do not slide, at a render rate above the physics rate.
## godot-args: --fixed-fps 120
##
## Run with:
##   godot --headless --path . --fixed-fps 120 -s tests/test_camera_follow.gd

const THIRD_PERSON_DEMO := "res://recipes/third_person_movement/demo.tscn"
const FIRST_PERSON_DEMO := "res://recipes/first_person_movement/demo.tscn"
const CHECKPOINT_DEMO := "res://recipes/checkpoint/demo.tscn"
const PROJECTILE := preload("res://recipes/projectile/projectile.tscn")
## Largest frame-to-frame wobble that counts as steady, in metres.
const TOLERANCE := 0.001


func _before_all() -> void:
	if not OS.get_cmdline_args().has("--fixed-fps"):
		print("(run with --fixed-fps 120: this only tests anything above the physics rate)")


func _open(scene: String) -> void:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)
	change_scene_to_file(scene)
	await process_frame
	await process_frame


## Runs forward and returns how much the distance between where the body is
## drawn and [param follower] varies from frame to frame.
func _measure_spread(body: Node3D, follower: Node3D) -> float:
	Input.action_press(&"move_up")
	for i in 120:
		await process_frame
	var lowest := INF
	var highest := -INF
	for i in 48:
		await process_frame
		var drawn_at := body.get_global_transform_interpolated().origin
		var distance := drawn_at.z - follower.global_position.z
		lowest = minf(lowest, distance)
		highest = maxf(highest, distance)
	Input.action_release(&"move_up")
	return highest - lowest


func test_third_person_is_steady_with_interpolation() -> void:
	await _third_person_is_steady(true)


func test_third_person_is_steady_without_interpolation() -> void:
	await _third_person_is_steady(false)


func _third_person_is_steady(interpolation: bool) -> void:
	physics_interpolation = interpolation
	await _open(THIRD_PERSON_DEMO)
	var label := "physics interpolation %s" % ("on" if interpolation else "off")
	var player: Node3D = current_scene.get_node("Player")
	var rig: Node3D = current_scene.get_node("OrbitCamera")
	var spread := await _measure_spread(player, rig)
	_check(player.global_position.z < -3.0, "the character ran (%s)" % label)
	_check(
		spread < TOLERANCE, "character is steady against the camera, %s: %.4f m" % [label, spread]
	)
	physics_interpolation = true


func test_first_person_view_is_steady() -> void:
	await _open(FIRST_PERSON_DEMO)
	var player: FirstPersonCharacter = current_scene.get_node("Player")
	# Start well back from the demo's beam so there is room to run.
	player.position = Vector3(0, 0.1, 20)
	player.reset_physics_interpolation()
	var spread := await _measure_spread(player, player.head)
	_check(spread < TOLERANCE, "first-person head stays on the drawn body: %.4f m" % spread)

	# The view answers the look input in the same frame, not a tick later.
	var before := player.head.global_rotation.y
	Input.action_press(&"look_left")
	await process_frame
	Input.action_release(&"look_left")
	_check(player.head.global_rotation.y > before, "looking turns the view within one frame")


func test_respawn_does_not_slide() -> void:
	await _open(CHECKPOINT_DEMO)
	var player: Node3D = current_scene.get_node("Player")
	var respawner: Respawner = player.get_node("Respawner")
	for i in 30:
		await physics_frame
	var start := respawner.get_spawn_transform().origin
	player.global_position = start + Vector3(0, 0, 12)
	player.reset_physics_interpolation()
	for i in 4:
		await physics_frame
	respawner.respawn()
	# On the very next frames the body must already be drawn at the spawn.
	var worst := 0.0
	for i in 3:
		await process_frame
		var drawn_at := player.get_global_transform_interpolated().origin
		worst = maxf(worst, Vector2(drawn_at.x - start.x, drawn_at.z - start.z).length())
	_check(worst < 0.05, "a respawn is drawn at the spawn at once, off by %.2f m" % worst)


func test_projectile_does_not_streak_from_its_last_position() -> void:
	var projectile: Projectile = PROJECTILE.instantiate()
	projectile.speed = 1.0
	_spawn(projectile)
	projectile.global_position = Vector3(50, 0, 0)
	for i in 4:
		await physics_frame
	projectile.launch(Transform3D(Basis.IDENTITY, Vector3(0, 5, 0)))
	var worst := 0.0
	for i in 3:
		await process_frame
		var drawn_at := projectile.get_global_transform_interpolated().origin
		worst = maxf(worst, drawn_at.distance_to(Vector3(0, 5, 0)))
	_check(worst < 0.1, "a launched projectile is drawn at the muzzle, off by %.2f m" % worst)
