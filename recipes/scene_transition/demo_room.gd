extends Control
## Demo-only: a room with buttons that lead to the other room.

@export_file("*.tscn") var other_room: String


func _ready() -> void:
	%Quick.pressed.connect(func() -> void: SceneTransition.change_scene(get_tree(), other_room))
	%Slow.pressed.connect(func() -> void: SceneTransition.change_scene(get_tree(), other_room, 2.0))
	%Quick.grab_focus()
