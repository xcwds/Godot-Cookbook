extends Control
## Lists every recipe that has a demo.tscn and launches it.

const RECIPES_DIR := "res://recipes"

@onready var _list: VBoxContainer = %RecipeList


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for recipe in DirAccess.get_directories_at(RECIPES_DIR):
		var demo_path := "%s/%s/demo.tscn" % [RECIPES_DIR, recipe]
		if not ResourceLoader.exists(demo_path):
			continue
		var config := ConfigFile.new()
		config.load("%s/%s/recipe.cfg" % [RECIPES_DIR, recipe])
		var button := Button.new()
		button.text = (
			"%s\n%s"
			% [
				config.get_value("recipe", "name", recipe),
				config.get_value("recipe", "description", ""),
			]
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(get_tree().change_scene_to_file.bind(demo_path))
		_list.add_child(button)
	if _list.get_child_count() > 0:
		_list.get_child(0).grab_focus()
