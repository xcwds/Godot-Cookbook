class_name PauseMenu
extends CanvasLayer
## Pauses the scene tree on an input action and shows Resume, Restart and
## Quit. Also the one place that changes the mouse mode around pausing.

signal paused
signal resumed

## Input action that opens and closes the menu.
@export var pause_action := &"pause"
## Capture the mouse while playing, for mouse-look games. When false the
## mouse mode is left alone while playing.
@export var capture_mouse := true

var _mouse_mode_before_pause := Input.MOUSE_MODE_VISIBLE

@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	# Keep receiving input while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	%ResumeButton.pressed.connect(resume)
	%RestartButton.pressed.connect(restart)
	%QuitButton.pressed.connect(quit)
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(pause_action):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func toggle() -> void:
	if is_open():
		resume()
	else:
		pause()


func pause() -> void:
	if is_open():
		return
	_mouse_mode_before_pause = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	show()
	_resume_button.grab_focus()
	paused.emit()


func resume() -> void:
	if not is_open():
		return
	hide()
	get_tree().paused = false
	Input.mouse_mode = _mouse_mode_before_pause
	resumed.emit()


func restart() -> void:
	resume()
	get_tree().reload_current_scene()


func quit() -> void:
	get_tree().quit()
