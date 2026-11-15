class_name Pickup
extends Area3D
## An item lying in the world. It is collected by any body that walks into
## it and has an [Inventory] with room.

## Emitted just before the pickup disappears.
signal collected(by: Node3D)

## Which item this gives.
@export var item_id := &"coin"
## How many.
@export var amount := 1
## Turns per second, for the idle spin. 0 keeps it still.
@export var spin_speed := 0.25


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Lets the save_load recipe pick this up, if it is in the project. See
	# "Saveable nodes" in docs/recipe_contract.md.
	add_to_group(&"saveable")


## A pickup saves only that it is still there. One that was collected before
## the save has no entry, so a load removes it.
func save_data() -> Dictionary:
	return {}


func load_data(_data: Dictionary) -> void:
	pass


func _physics_process(delta: float) -> void:
	rotate_y(TAU * spin_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	var inventory := Inventory.find_in(body)
	# Left where it is if the inventory cannot take all of it.
	if inventory == null or inventory.get_count(item_id) + amount > inventory.max_stack:
		return
	inventory.add(item_id, amount)
	collected.emit(body)
	queue_free()
