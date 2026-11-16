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
			var code := key.keycode
			if code == KEY_NONE:
				# A physical key is named after the US layout; show what the
				# player's own layout has in that position, where the platform
				# can tell (it reports no layouts otherwise).
				code = key.physical_keycode
				if DisplayServer.keyboard_get_layout_count() > 0:
					code = DisplayServer.keyboard_get_keycode_from_physical(code)
			return OS.get_keycode_string(code)
	return action
