extends Control
## Lists every recipe that has a demo.tscn, grouped by the category in its
## recipe.cfg, and launches it.

const RECIPES_DIR := "res://recipes"
## Categories in display order, with their headings. The recipe tables in the
## root README.md use the same groups and order; tools/check_recipes.py checks
## the README against each recipe.cfg.
const CATEGORIES: Dictionary[String, String] = {
	"movement": "Movement",
	"cameras": "Cameras",
	"combat": "Combat",
	"world": "World",
	"ui": "UI",
	"systems": "Systems",
}
## Heading for recipes whose category is missing or unknown.
const OTHER := "Other"

@onready var _list: VBoxContainer = %RecipeList


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var groups := _recipes_by_heading()
	var first_button: Button = null
	for heading: String in groups:
		var label := Label.new()
		label.text = heading
		label.theme_type_variation = &"HeaderMedium"
		_list.add_child(label)
		for recipe: Dictionary in groups[heading]:
			var button := Button.new()
			button.text = "%s\n%s" % [recipe.name, recipe.description]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(get_tree().change_scene_to_file.bind(recipe.demo))
			_list.add_child(button)
			if first_button == null:
				first_button = button
	if first_button != null:
		first_button.grab_focus()


## Maps each heading that has recipes to them, in display order. Within a
## heading the recipes are in folder-name order.
func _recipes_by_heading() -> Dictionary[String, Array]:
	var groups: Dictionary[String, Array] = {}
	for heading: String in CATEGORIES.values() + [OTHER]:
		groups[heading] = []
	var folders := DirAccess.get_directories_at(RECIPES_DIR)
	folders.sort()
	for folder in folders:
		var demo_path := "%s/%s/demo.tscn" % [RECIPES_DIR, folder]
		if not ResourceLoader.exists(demo_path):
			continue
		var config := ConfigFile.new()
		config.load("%s/%s/recipe.cfg" % [RECIPES_DIR, folder])
		var category: String = config.get_value("recipe", "category", "")
		(
			groups[CATEGORIES.get(category, OTHER)]
			. append(
				{
					"name": config.get_value("recipe", "name", folder),
					"description": config.get_value("recipe", "description", ""),
					"demo": demo_path,
				}
			)
		)
	for heading: String in groups.keys():
		if groups[heading].is_empty():
			groups.erase(heading)
	return groups
