extends Node
## Cookbook-only autoload: press F1 in any demo to return to the recipe browser.
## Not part of any recipe.

const BROWSER_SCENE := "res://browser/recipe_browser.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(BROWSER_SCENE)
