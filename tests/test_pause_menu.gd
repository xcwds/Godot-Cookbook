extends SceneTree
## Headless test for recipes/pause_menu. Run with:
##   godot --headless --path . -s tests/test_pause_menu.gd

const PAUSE_MENU := preload("res://recipes/pause_menu/pause_menu.tscn")

var _failures := 0


func _initialize() -> void:
	# Nodes only become ready once the tree is running.
	await process_frame
	_test_starts_closed_and_unpaused()
	_test_pause_and_resume()
	await _test_action_toggles()
	_test_mouse_mode_is_restored()
	if _failures == 0:
		print("test_pause_menu: OK")
	paused = false
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _make(capture_mouse := false) -> PauseMenu:
	var menu: PauseMenu = PAUSE_MENU.instantiate()
	menu.capture_mouse = capture_mouse
	root.add_child(menu)
	return menu


func _test_starts_closed_and_unpaused() -> void:
	var menu := _make()
	_check(not menu.is_open() and not paused, "starts closed with the tree running")
	menu.free()


func _test_pause_and_resume() -> void:
	var menu := _make()
	var events: Array = []
	menu.paused.connect(func() -> void: events.append("paused"))
	menu.resumed.connect(func() -> void: events.append("resumed"))
	menu.pause()
	menu.pause()
	_check(menu.is_open() and paused, "pause opens the menu and pauses the tree")
	_check(menu.get_node("%ResumeButton").has_focus(), "Resume is focused when opened")
	menu.resume()
	menu.resume()
	_check(not menu.is_open() and not paused, "resume closes the menu and unpauses")
	_check(events == ["paused", "resumed"], "signals are emitted once each")
	menu.free()


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _test_action_toggles() -> void:
	var menu := _make()
	await _press(&"pause")
	_check(menu.is_open() and paused, "pause action opens the menu")
	await _press(&"pause")
	_check(not menu.is_open() and not paused, "pause action closes it, also while paused")
	menu.free()


func _test_mouse_mode_is_restored() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("(mouse mode cannot be changed on this display; skipping that check)")
		return
	var menu := _make()
	menu.pause()
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse is released while paused")
	menu.resume()
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "previous mouse mode is restored")
	menu.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
