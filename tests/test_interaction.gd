extends SceneTree
## Headless test for recipes/interaction. Run with:
##   godot --headless --path . -s tests/test_interaction.gd

const INTERACTOR := preload("res://recipes/interaction/interactor.tscn")
const INTERACTABLE := preload("res://recipes/interaction/interactable.tscn")
const PROMPT := preload("res://recipes/interaction/interaction_prompt.tscn")

var _failures := 0


func _initialize() -> void:
	# Nodes only become ready once the tree is running.
	await process_frame
	await _test_focuses_nearest_in_reach()
	await _test_interact_action_uses_the_focused_one()
	await _test_disabled_and_freed_are_skipped()
	await _test_facing_limits_what_can_be_focused()
	await _test_prompt_follows_focus()
	if _failures == 0:
		print("test_interaction: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


## Overlaps are updated by the physics server, a tick or two after a move.
func _settle() -> void:
	for i in 4:
		await physics_frame


func _make_actor() -> Node3D:
	var actor := Node3D.new()
	root.add_child(actor)
	actor.add_child(INTERACTOR.instantiate())
	return actor


func _make_interactable(at: Vector3, prompt := "Use") -> Interactable:
	var interactable: Interactable = INTERACTABLE.instantiate()
	interactable.prompt = prompt
	interactable.position = at
	root.add_child(interactable)
	return interactable


func _test_focuses_nearest_in_reach() -> void:
	var actor := _make_actor()
	var interactor: Interactor = actor.get_child(0)
	var near := _make_interactable(Vector3(0, 0, -1.5))
	var far := _make_interactable(Vector3(0, 0, -2.2))
	var out_of_reach := _make_interactable(Vector3(0, 0, -10))
	var changes: Array = []
	interactor.focus_changed.connect(func(i: Interactable) -> void: changes.append(i))
	var events: Array = []
	near.focused.connect(func() -> void: events.append("near focused"))
	near.unfocused.connect(func() -> void: events.append("near unfocused"))
	await _settle()
	_check(interactor.focused == near, "focuses the nearest interactable")

	actor.position = Vector3(0, 0, -2.5)
	await _settle()
	_check(interactor.focused == far, "focus moves when another becomes nearer")

	actor.position = Vector3(50, 0, 0)
	await _settle()
	_check(interactor.focused == null, "nothing is focused out of reach")
	# Teleporting away can refocus for one tick while overlaps catch up, so
	# only the start and the end of the sequence are fixed.
	_check(changes.slice(0, 2) == [near, far], "focus_changed reports each change")
	_check(changes.back() == null, "and ends with null")
	_check(events.slice(0, 2) == ["near focused", "near unfocused"], "interactables are told too")
	for node: Node in [actor, near, far, out_of_reach]:
		node.free()


func _test_interact_action_uses_the_focused_one() -> void:
	var actor := _make_actor()
	var interactor: Interactor = actor.get_child(0)
	var target := _make_interactable(Vector3(0, 0, -1))
	var used_by: Array = []
	target.interacted.connect(func(who: Node) -> void: used_by.append(who))
	_check(not interactor.interact(), "interact does nothing before anything is focused")
	await _settle()

	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	_check(used_by == [actor], "the interact action triggers it, passing the actor")
	actor.free()
	target.free()


func _test_disabled_and_freed_are_skipped() -> void:
	var actor := _make_actor()
	var interactor: Interactor = actor.get_child(0)
	var near := _make_interactable(Vector3(0, 0, -1))
	var far := _make_interactable(Vector3(0, 0, -2))
	await _settle()
	near.enabled = false
	await _settle()
	_check(interactor.focused == far, "a disabled interactable loses focus")
	far.free()
	await _settle()
	_check(interactor.focused == null and not interactor.interact(), "a freed one is forgotten")
	actor.free()
	near.free()


func _test_facing_limits_what_can_be_focused() -> void:
	var actor := _make_actor()
	var interactor: Interactor = actor.get_child(0)
	interactor.facing = actor
	var behind := _make_interactable(Vector3(0, 0, 1))
	var ahead := _make_interactable(Vector3(0, 0, -2))
	await _settle()
	_check(interactor.focused == ahead, "prefers what is in front, even if further away")
	actor.rotation.y = PI
	await _settle()
	_check(interactor.focused == behind, "turning around changes the focus")
	for node: Node in [actor, behind, ahead]:
		node.free()


func _test_prompt_follows_focus() -> void:
	var actor := _make_actor()
	var prompt: InteractionPrompt = PROMPT.instantiate()
	prompt.interactor = actor.get_child(0)
	root.add_child(prompt)
	_check(not prompt.visible, "prompt starts hidden")
	var target := _make_interactable(Vector3(0, 0, -1), "Open")
	await _settle()
	_check(prompt.visible, "prompt shows when something is in reach")
	await process_frame
	_check(prompt.get_node("%Label").text == "[E] Open", "prompt names the key and the action")
	target.prompt = "Close"
	await process_frame
	await process_frame
	_check(prompt.get_node("%Label").text == "[E] Close", "prompt follows a changed text")
	actor.position = Vector3(50, 0, 0)
	await _settle()
	_check(not prompt.visible, "prompt hides again")

	actor.position = Vector3.ZERO
	await _settle()
	_check(prompt.visible, "and shows when back in reach")
	target.free()
	target = _make_interactable(Vector3(60, 0, 0))
	await _settle()
	_check(not prompt.visible, "prompt hides when the focused interactable is freed")
	for node: Node in [actor, prompt, target]:
		node.free()
