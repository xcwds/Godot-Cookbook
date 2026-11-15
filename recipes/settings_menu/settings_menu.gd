class_name SettingsMenu
extends Control
## A settings screen for [GameSettings]: a volume slider per audio bus,
## fullscreen and v-sync switches, and key rebinding.

## Emitted when the player presses Back.
signal closed

## Actions the player may rebind. Empty lists every action in the project
## except the built-in [code]ui_[/code] ones.
@export var remappable_actions: Array[StringName] = []

## The action waiting for a key press, or empty.
var _listening_action := &""
var _binding_buttons: Dictionary[StringName, Button] = {}

@onready var _audio_list: VBoxContainer = %AudioList
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _vsync: CheckButton = %VSync
@onready var _binding_list: VBoxContainer = %BindingList
@onready var _binding_hint: Label = %BindingHint


func _ready() -> void:
	GameSettings.load_and_apply()
	_build_audio()
	_fullscreen.button_pressed = GameSettings.is_fullscreen()
	_fullscreen.toggled.connect(GameSettings.set_fullscreen)
	_vsync.button_pressed = GameSettings.is_vsync()
	_vsync.toggled.connect(GameSettings.set_vsync)
	_build_bindings()
	%ResetBindings.pressed.connect(_on_reset_bindings)
	%Back.pressed.connect(func() -> void: closed.emit())


func _input(event: InputEvent) -> void:
	if _listening_action == &"":
		return
	var is_key: bool = event is InputEventKey and event.pressed and not event.echo
	var is_button: bool = event is InputEventMouseButton and event.pressed
	if not is_key and not is_button:
		return
	get_viewport().set_input_as_handled()
	var action := _listening_action
	_listening_action = &""
	if is_key and event.keycode == KEY_ESCAPE:
		_binding_hint.text = ""
	else:
		var conflict := GameSettings.find_conflict(action, event)
		GameSettings.set_binding(action, event)
		_binding_hint.text = (
			"" if conflict == &"" else "%s uses the same input." % _action_label(conflict)
		)
	_refresh_bindings()


func _build_audio() -> void:
	for index in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(index)
		var slider := HSlider.new()
		slider.name = bus
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = GameSettings.get_bus_volume(bus)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(
			func(value: float) -> void: GameSettings.set_bus_volume(bus, value)
		)
		_audio_list.add_child(_row(bus, slider))


func _build_bindings() -> void:
	var actions := remappable_actions
	if actions.is_empty():
		for action in InputMap.get_actions():
			if not String(action).begins_with("ui_"):
				actions.append(action)
	for action in actions:
		var button := Button.new()
		button.name = action
		button.custom_minimum_size.x = 160.0
		button.pressed.connect(_on_binding_pressed.bind(action))
		_binding_buttons[action] = button
		_binding_list.add_child(_row(_action_label(action), button))
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action in _binding_buttons:
		var listening := action == _listening_action
		_binding_buttons[action].text = (
			"Press a key..." if listening else GameSettings.get_binding_text(action)
		)


func _on_binding_pressed(action: StringName) -> void:
	_listening_action = action
	_binding_hint.text = "Press a key or mouse button. Esc cancels."
	_refresh_bindings()


func _on_reset_bindings() -> void:
	_listening_action = &""
	_binding_hint.text = ""
	GameSettings.reset_bindings()
	_refresh_bindings()


func _action_label(action: StringName) -> String:
	return String(action).capitalize()


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 160.0
	row.add_child(label)
	row.add_child(control)
	return row
