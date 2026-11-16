extends "res://tests/support/test_case.gd"
## Headless test for recipes/settings_menu. Run with:
##   godot --headless --path . -s tests/test_settings_menu.gd

const MENU := preload("res://recipes/settings_menu/settings_menu.tscn")
const TEST_PATH := "user://test_settings.cfg"


func _before_all() -> void:
	GameSettings.settings_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)


func _after_all() -> void:
	GameSettings.unload()
	DirAccess.remove_absolute(TEST_PATH)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _has_joypad_binding(action: StringName) -> bool:
	return InputMap.action_get_events(action).any(
		func(event: InputEvent) -> bool: return event is InputEventJoypadMotion
	)


func test_volume_is_applied_and_saved() -> void:
	var sfx := AudioServer.get_bus_index(&"SFX")
	_check(sfx >= 0, "the project has an SFX bus")
	GameSettings.set_bus_volume(&"SFX", 0.5)
	_check(
		is_equal_approx(GameSettings.get_bus_volume(&"SFX"), 0.5), "volume is applied to the bus"
	)
	GameSettings.set_bus_volume(&"SFX", 0.0)
	_check(AudioServer.is_bus_mute(sfx), "zero volume mutes the bus")
	GameSettings.set_bus_volume(&"SFX", 0.25)
	_check(not AudioServer.is_bus_mute(sfx), "and raising it unmutes")
	_check(FileAccess.file_exists(TEST_PATH), "changes are saved straight away")


func test_video_settings_are_saved() -> void:
	_check(not GameSettings.is_fullscreen() and GameSettings.is_vsync(), "video defaults")
	GameSettings.set_fullscreen(true)
	GameSettings.set_vsync(false)
	_check(GameSettings.is_fullscreen() and not GameSettings.is_vsync(), "video settings are kept")
	GameSettings.set_fullscreen(false)


func test_rebinding() -> void:
	_check(
		GameSettings.get_binding_text(&"move_up") == "W", "default binding is read from the project"
	)
	GameSettings.set_binding(&"move_up", _key(KEY_T))
	_check(GameSettings.get_binding_text(&"move_up") == "T", "the new key is bound")
	_check(InputMap.action_has_event(&"move_up", _key(KEY_T)), "in the input map")
	_check(not InputMap.action_has_event(&"move_up", _key(KEY_W)), "and the old key is not")
	_check(_has_joypad_binding(&"move_up"), "gamepad bindings are left alone")
	_check(GameSettings.find_conflict(&"jump", _key(KEY_T)) == &"move_up", "conflicts are found")
	_check(GameSettings.find_conflict(&"move_up", _key(KEY_T)) == &"", "not with itself")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_MIDDLE
	GameSettings.set_binding(&"dash", click)
	_check(GameSettings.get_binding_text(&"dash") == "Mouse 3", "mouse buttons can be bound")


func test_settings_survive_a_restart() -> void:
	# Forget everything, as if the game had been closed.
	GameSettings.unload()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), 0.0)
	_check(InputMap.action_has_event(&"move_up", _key(KEY_W)), "unload restores project bindings")

	GameSettings.load_and_apply()
	_check(is_equal_approx(GameSettings.get_bus_volume(&"SFX"), 0.25), "volume is restored")
	_check(not GameSettings.is_vsync(), "video settings are restored")
	_check(GameSettings.get_binding_text(&"move_up") == "T", "key bindings are restored")
	_check(GameSettings.get_binding_text(&"dash") == "Mouse 3", "mouse bindings are restored")


func test_reset_bindings() -> void:
	GameSettings.reset_bindings()
	_check(GameSettings.get_binding_text(&"move_up") == "W", "reset restores the project bindings")
	_check(_has_joypad_binding(&"move_up"), "including gamepad ones")
	GameSettings.unload()
	GameSettings.load_and_apply()
	_check(GameSettings.get_binding_text(&"move_up") == "W", "and the reset is saved")
	_check(is_equal_approx(GameSettings.get_bus_volume(&"SFX"), 0.25), "other settings are kept")


func test_menu() -> void:
	var menu: SettingsMenu = MENU.instantiate()
	_spawn(menu)
	var sliders := menu.get_node("%AudioList").get_children()
	_check(sliders.size() == AudioServer.bus_count, "one slider per audio bus")
	var sfx_slider: HSlider = menu.get_node("%AudioList").find_child("SFX", true, false)
	_check(is_equal_approx(sfx_slider.value, 0.25), "sliders start at the saved volume")
	sfx_slider.value = 0.8
	_check(
		is_equal_approx(GameSettings.get_bus_volume(&"SFX"), 0.8), "moving a slider sets the volume"
	)

	var bindings := menu.get_node("%BindingList")
	_check(bindings.find_child("jump", true, false) != null, "project actions are listed")
	_check(bindings.find_child("ui_accept", true, false) == null, "built-in ui actions are not")

	var jump_button: Button = bindings.find_child("jump", true, false)
	_check(jump_button.text == "Space", "buttons show the current key")
	jump_button.pressed.emit()
	_check(jump_button.text == "Press a key...", "pressing one waits for a key")
	Input.parse_input_event(_key(KEY_ESCAPE))
	await process_frame
	await process_frame
	_check(jump_button.text == "Space", "Esc cancels")

	jump_button.pressed.emit()
	Input.parse_input_event(_key(KEY_J))
	await process_frame
	await process_frame
	_check(jump_button.text == "J", "the next key press becomes the binding")
	_check(GameSettings.get_binding_text(&"jump") == "J", "in the settings too")

	menu.get_node("%ResetBindings").pressed.emit()
	_check(jump_button.text == "Space", "Reset controls restores the buttons")

	var closed := [false]
	menu.closed.connect(func() -> void: closed[0] = true)
	menu.get_node("%Back").pressed.emit()
	_check(closed[0], "Back emits closed")
