extends SceneTree
## Headless test for recipes/inventory. Run with:
##   godot --headless --path . -s tests/test_inventory.gd

const PICKUP := preload("res://recipes/inventory/pickup.tscn")
const PANEL := preload("res://recipes/inventory/inventory_panel.tscn")

var _failures := 0


func _initialize() -> void:
	await process_frame
	_test_add_remove_and_count()
	_test_stack_limit()
	_test_save_data_round_trip()
	await _test_pickup_is_collected()
	await _test_pickup_is_left_when_it_cannot_be_taken()
	await _test_panel_lists_items()
	if _failures == 0:
		print("test_inventory: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for i in 4:
		await physics_frame


func _make_inventory() -> Inventory:
	var inventory := Inventory.new()
	root.add_child(inventory)
	return inventory


## A body on the player layer, optionally carrying an inventory.
func _make_body(at: Vector3, with_inventory := true) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
	body.position = at
	if with_inventory:
		body.add_child(Inventory.new())
	root.add_child(body)
	return body


func _make_pickup(at: Vector3, item_id := &"coin", amount := 1) -> Pickup:
	var pickup: Pickup = PICKUP.instantiate()
	pickup.item_id = item_id
	pickup.amount = amount
	pickup.position = at
	root.add_child(pickup)
	return pickup


func _test_add_remove_and_count() -> void:
	var inventory := _make_inventory()
	var changes: Array = []
	inventory.changed.connect(func(id: StringName, count: int) -> void: changes.append([id, count]))
	_check(inventory.get_count(&"coin") == 0 and not inventory.has(&"coin"), "starts empty")
	_check(inventory.add(&"coin", 3) == 3, "add returns how many were added")
	_check(inventory.add(&"key") == 1, "amount defaults to one")
	_check(inventory.has(&"coin", 3) and not inventory.has(&"coin", 4), "has checks the amount")
	_check(inventory.get_items() == {&"coin": 3, &"key": 1}, "get_items lists everything")

	_check(not inventory.remove(&"coin", 5), "cannot remove more than there are")
	_check(inventory.get_count(&"coin") == 3, "and nothing is removed when it fails")
	_check(inventory.remove(&"coin", 2) and inventory.get_count(&"coin") == 1, "remove takes some")
	_check(inventory.remove(&"key") and not inventory.get_items().has(&"key"), "the last one goes")
	_check(not inventory.remove(&"gem"), "removing an item never held fails")
	_check(
		changes == [[&"coin", 3], [&"key", 1], [&"coin", 1], [&"key", 0]],
		"changed reports each new count: %s" % [changes]
	)
	inventory.clear()
	_check(inventory.get_items().is_empty(), "clear empties it")
	inventory.free()


func _test_stack_limit() -> void:
	var inventory := _make_inventory()
	inventory.max_stack = 5
	_check(inventory.add(&"coin", 4) == 4, "fits under the limit")
	_check(inventory.add(&"coin", 4) == 1, "only what fits is added")
	_check(
		inventory.add(&"coin") == 0 and inventory.get_count(&"coin") == 5, "a full stack takes none"
	)
	_check(inventory.add(&"coin", -3) == 0, "negative amounts are ignored")
	inventory.max_stack = 2
	_check(inventory.add(&"coin") == 0, "nothing is added, or reported, above a lowered limit")
	inventory.free()


func _test_save_data_round_trip() -> void:
	var inventory := _make_inventory()
	inventory.add(&"coin", 7)
	inventory.add(&"key")
	# Through JSON, as the save_load recipe would store it.
	var stored: Dictionary = JSON.parse_string(JSON.stringify(inventory.save_data()))
	var other := _make_inventory()
	other.add(&"gem", 2)
	other.load_data(stored)
	_check(other.get_items() == {&"coin": 7, &"key": 1}, "load_data replaces the contents")
	_check(inventory.is_in_group(&"saveable"), "and it is in the saveable group")
	inventory.free()
	other.free()


func _test_pickup_is_collected() -> void:
	var body := _make_body(Vector3(20, 0, 0))
	var inventory := Inventory.find_in(body)
	var pickup := _make_pickup(Vector3.ZERO, &"coin", 2)
	var collectors: Array = []
	pickup.collected.connect(func(by: Node3D) -> void: collectors.append(by))
	await _settle()
	_check(
		is_instance_valid(pickup) and inventory.get_count(&"coin") == 0,
		"nothing happens at a distance"
	)
	body.position = Vector3.ZERO
	await _settle()
	_check(inventory.get_count(&"coin") == 2, "walking in adds the items")
	_check(collectors == [body], "collected names who took it")
	_check(not is_instance_valid(pickup), "and the pickup is gone")
	body.free()


func _test_pickup_is_left_when_it_cannot_be_taken() -> void:
	var stranger := _make_body(Vector3.ZERO, false)
	var pickup := _make_pickup(Vector3.ZERO)
	await _settle()
	_check(is_instance_valid(pickup), "a body without an inventory leaves it")
	stranger.free()

	var body := _make_body(Vector3(20, 0, 0))
	var inventory := Inventory.find_in(body)
	inventory.max_stack = 3
	inventory.add(&"coin", 3)
	body.position = Vector3.ZERO
	await _settle()
	_check(
		is_instance_valid(pickup) and inventory.get_count(&"coin") == 3,
		"a full inventory leaves it"
	)
	body.free()
	pickup.free()


func _test_panel_lists_items() -> void:
	var inventory := _make_inventory()
	var panel: InventoryPanel = PANEL.instantiate()
	panel.inventory = inventory
	root.add_child(panel)
	var list := panel.get_node("%ItemList")
	_check(list.get_child_count() == 0 and panel.get_node("%Empty").visible, "shows Empty at first")
	inventory.add(&"coin", 3)
	inventory.add(&"rusty_key")
	await process_frame
	var texts := list.get_children().map(func(row: Label) -> String: return row.text)
	_check(texts == ["Coin  x3", "Rusty Key  x1"], "lists items with counts: %s" % [texts])
	_check(not panel.get_node("%Empty").visible, "and hides Empty")
	inventory.remove(&"coin", 3)
	await process_frame
	_check(list.get_child_count() == 1, "rows disappear with the item")
	panel.free()
	inventory.free()
