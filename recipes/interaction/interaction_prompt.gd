class_name InteractionPrompt
extends Control
## Shows "[E] Open" while an [Interactor] has something in reach.

## The interactor to follow.
@export var interactor: Interactor

@onready var _label: Label = %Label


func _ready() -> void:
	hide()
	if interactor != null:
		interactor.focus_changed.connect(_on_focus_changed)


func _process(_delta: float) -> void:
	# Refreshed every frame so a prompt that changes while focused shows up.
	var interactable := interactor.focused if interactor != null else null
	if is_instance_valid(interactable):
		_label.text = "[%s] %s" % [_action_hint(interactor.interact_action), interactable.prompt]


func _on_focus_changed(interactable: Interactable) -> void:
	visible = interactable != null


## Name of the first key or button bound to an action.
func _action_hint(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code := key.physical_keycode if key.keycode == KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return action
