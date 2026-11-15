class_name InventoryPanel
extends PanelContainer
## Lists what an [Inventory] holds and keeps itself up to date.

## The inventory to show.
@export var inventory: Inventory

@onready var _list: VBoxContainer = %ItemList
@onready var _empty: Label = %Empty


func _ready() -> void:
	if inventory != null:
		inventory.changed.connect(func(_item_id: StringName, _count: int) -> void: refresh())
	refresh()


func refresh() -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	var items := inventory.get_items() if inventory != null else {}
	_empty.visible = items.is_empty()
	for item_id: StringName in items:
		var row := Label.new()
		row.name = item_id
		row.text = "%s  x%d" % [String(item_id).capitalize(), items[item_id]]
		_list.add_child(row)
