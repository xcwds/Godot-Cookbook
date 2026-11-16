extends "res://tests/support/test_case.gd"
## Headless test for recipes/pause_menu. Run with:
##   godot --headless --path . -s tests/test_pause_menu.gd

const PAUSE_MENU := preload("res://recipes/pause_menu/pause_menu.tscn")


func _after_all() -> void:
	paused = false


func _make(capture_mouse := false) -> PauseMenu:
	var menu: PauseMenu = PAUSE_MENU.instantiate()
	menu.capture_mouse = capture_mouse
	_spawn(menu)
	return menu


func test_starts_closed_and_unpaused() -> void:
	var menu := _make()
	_check(not menu.is_open() and not paused, "starts closed with the tree running")


func test_pause_and_resume() -> void:
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


func test_action_toggles() -> void:
	var menu := _make()
	await _press(&"pause")
	_check(menu.is_open() and paused, "pause action opens the menu")
	await _press(&"pause")
	_check(not menu.is_open() and not paused, "pause action closes it, also while paused")


func test_mouse_mode_is_restored() -> void:
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
