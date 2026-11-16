class_name GameSettings
extends RefCounted
## Player settings: audio bus volumes, fullscreen, v-sync and key bindings.
## They are stored in [code]user://settings.cfg[/code] and saved on every
## change.
##
## Call [method load_and_apply] once when the game starts, so saved settings
## take effect before any menu is opened.

## Where settings are stored. Change it before the first call if needed.
static var settings_path := "user://settings.cfg"

static var _config: ConfigFile
## The project's own bindings, kept so they can be restored.
static var _default_events: Dictionary[StringName, Array] = {}


## Loads the settings file, if there is one, and applies everything in it.
## Safe to call more than once; only the first call does anything.
static func load_and_apply() -> void:
	if _config != null:
		return
	_config = ConfigFile.new()
	_config.load(settings_path)
	for action in InputMap.get_actions():
		_default_events[action] = InputMap.action_get_events(action)

	for bus in _config.get_section_keys("audio") if _config.has_section("audio") else []:
		_apply_bus_volume(bus, _config.get_value("audio", bus))
	if _config.has_section_key("video", "fullscreen"):
		_apply_fullscreen(_config.get_value("video", "fullscreen"))
	if _config.has_section_key("video", "vsync"):
		_apply_vsync(_config.get_value("video", "vsync"))
	for action in _config.get_section_keys("input") if _config.has_section("input") else []:
		var event := _event_from_data(_config.get_value("input", action))
		if event != null and InputMap.has_action(action):
			_apply_binding(action, event)


## Forgets what was loaded and restores the project's bindings, so the next
## [method load_and_apply] starts from the file again.
static func unload() -> void:
	for action in _default_events:
		_restore_default(action)
	_default_events.clear()
	_config = null


# --- Audio -------------------------------------------------------------------


## Volume of an audio bus from 0 (silent) to 1 (full).
static func get_bus_volume(bus: StringName) -> float:
	load_and_apply()
	var index := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(index)) if index >= 0 else 0.0


static func set_bus_volume(bus: StringName, linear: float) -> void:
	load_and_apply()
	linear = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(bus, linear)
	_config.set_value("audio", bus, linear)
	_save()


# --- Video -------------------------------------------------------------------


static func is_fullscreen() -> bool:
	load_and_apply()
	return _config.get_value("video", "fullscreen", false)


static func set_fullscreen(enabled: bool) -> void:
	load_and_apply()
	_apply_fullscreen(enabled)
	_config.set_value("video", "fullscreen", enabled)
	_save()


static func is_vsync() -> bool:
	load_and_apply()
	return _config.get_value("video", "vsync", true)


static func set_vsync(enabled: bool) -> void:
	load_and_apply()
	_apply_vsync(enabled)
	_config.set_value("video", "vsync", enabled)
	_save()


# --- Key bindings ------------------------------------------------------------


## The key or mouse button bound to an action, or null. Gamepad bindings
## are not touched by this class.
static func get_binding(action: StringName) -> InputEvent:
	load_and_apply()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event
	return null


## Short name of an action's key or mouse button, such as "W" or "Mouse 2".
static func get_binding_text(action: StringName) -> String:
	return event_text(get_binding(action))


static func event_text(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		var code := key.keycode
		if code == KEY_NONE:
			# A physical key is a position on the keyboard, named after the US
			# layout. Ask what this player's layout has there, so an AZERTY
			# player reads "Z" for the key that is "W" on a US keyboard.
			# Platforms that cannot tell (headless, some consoles) report no
			# layouts and keep the US name.
			code = key.physical_keycode
			if DisplayServer.keyboard_get_layout_count() > 0:
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code)
	var button := event as InputEventMouseButton
	if button != null:
		return "Mouse %d" % button.button_index
	return "Unbound"


## Binds an action to a key or mouse button, replacing its current one.
## [param event] is the input event the player just produced.
static func set_binding(action: StringName, event: InputEvent) -> void:
	load_and_apply()
	var data := _event_to_data(event)
	if data.is_empty():
		return
	_apply_binding(action, _event_from_data(data))
	_config.set_value("input", action, data)
	_save()


## Another action that already uses this key or mouse button, or empty.
static func find_conflict(action: StringName, event: InputEvent) -> StringName:
	load_and_apply()
	var wanted := _event_to_data(event)
	for other in InputMap.get_actions():
		if other == action or String(other).begins_with("ui_"):
			continue
		var bound := get_binding(other)
		if bound != null and _event_to_data(bound) == wanted:
			return other
	return &""


## Puts every action back to the project's bindings.
static func reset_bindings() -> void:
	load_and_apply()
	for action in _default_events:
		_restore_default(action)
	if _config.has_section("input"):
		_config.erase_section("input")
	_save()


# --- Internals ---------------------------------------------------------------


static func _apply_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.0)


static func _apply_fullscreen(enabled: bool) -> void:
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)


static func _apply_vsync(enabled: bool) -> void:
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


static func _apply_binding(action: StringName, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey or existing is InputEventMouseButton:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)


static func _restore_default(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event: InputEvent in _default_events[action]:
		InputMap.action_add_event(action, event)


## Bindings are stored as plain numbers, not as objects, so the settings
## file stays readable and cannot carry anything but a key or a button.
static func _event_to_data(event: InputEvent) -> Dictionary:
	var key := event as InputEventKey
	if key != null:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return {"key": code}
	var button := event as InputEventMouseButton
	if button != null:
		return {"mouse_button": button.button_index}
	return {}


static func _event_from_data(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	if data.has("key"):
		var key := InputEventKey.new()
		key.physical_keycode = data["key"]
		return key
	if data.has("mouse_button"):
		var button := InputEventMouseButton.new()
		button.button_index = data["mouse_button"]
		return button
	return null


static func _save() -> void:
	var error := _config.save(settings_path)
	if error != OK:
		push_error("GameSettings: could not save %s: %s" % [settings_path, error_string(error)])
