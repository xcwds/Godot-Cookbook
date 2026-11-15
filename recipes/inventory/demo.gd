extends Node3D
## Collect coins and a key, then use the key on the door.

@onready var _inventory: Inventory = $Player/Inventory
@onready var _door: CSGBox3D = $Door
@onready var _door_interactable: Interactable = $Door/Interactable
@onready var _status: Label = %Status


func _ready() -> void:
	_door_interactable.interacted.connect(_on_door_used)
	_inventory.changed.connect(_on_inventory_changed)


func _on_door_used(_actor: Node) -> void:
	# Spending an item: remove() only succeeds if there is one to spend.
	if _inventory.remove(&"key"):
		_status.text = "The key opened the door."
		_door.queue_free()
	else:
		_status.text = "The door is locked. Find the key."


func _on_inventory_changed(item_id: StringName, count: int) -> void:
	if item_id == &"key" and count > 0:
		_door_interactable.prompt = "Unlock"
