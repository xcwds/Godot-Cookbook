class_name Inventory
extends Node
## A minimal inventory: how many of each item something is carrying. Items
## are just names, such as [code]&"coin"[/code] or [code]&"key"[/code].
## Add it as a child of the player.

## Emitted when the amount of an item changes. [param count] is the new
## amount, 0 when the last one is gone.
signal changed(item_id: StringName, count: int)

## The most of any one item that can be carried.
@export var max_stack := 99

var _items: Dictionary[StringName, int] = {}


## The inventory that is a direct child of [param node], or null.
static func find_in(node: Node) -> Inventory:
	for child in node.get_children():
		if child is Inventory:
			return child
	return null


func _ready() -> void:
	# Lets the save_load recipe pick this up, if it is in the project.
	add_to_group(&"saveable")


## Adds up to [param amount] of an item and returns how many fitted.
func add(item_id: StringName, amount := 1) -> int:
	var current := get_count(item_id)
	var added := clampi(amount, 0, max_stack - current)
	if added > 0:
		_set_count(item_id, current + added)
	return added


## Removes [param amount] of an item. Returns false, removing nothing, if
## there are not that many.
func remove(item_id: StringName, amount := 1) -> bool:
	if amount <= 0 or not has(item_id, amount):
		return false
	_set_count(item_id, get_count(item_id) - amount)
	return true


func has(item_id: StringName, amount := 1) -> bool:
	return get_count(item_id) >= amount


func get_count(item_id: StringName) -> int:
	return _items.get(item_id, 0)


## Every item carried and how many, as a copy.
func get_items() -> Dictionary[StringName, int]:
	return _items.duplicate()


func clear() -> void:
	for item_id: StringName in _items.keys():
		_set_count(item_id, 0)


func save_data() -> Dictionary:
	var items := {}
	for item_id in _items:
		items[String(item_id)] = _items[item_id]
	return {"items": items}


func load_data(data: Dictionary) -> void:
	clear()
	var items: Dictionary = data.get("items", {})
	for item_id: String in items:
		_set_count(StringName(item_id), int(items[item_id]))


func _set_count(item_id: StringName, count: int) -> void:
	if count > 0:
		_items[item_id] = count
	else:
		_items.erase(item_id)
	changed.emit(item_id, count)
