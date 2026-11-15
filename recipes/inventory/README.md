# Pickups and inventory

Three small pieces:

- `Inventory`: how many of each item something carries. Items are just names, such as `&"coin"` or `&"key"`.
- `Pickup`: an item lying in the world, collected by walking into it.
- `InventoryPanel`: a UI panel that lists what an inventory holds.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Add a `Node` with `inventory.gd` as a direct child of your player.
3. Put your player on physics layer 2 (`player`); pickups only notice bodies on that layer.
4. Instance `pickup.tscn` in the level and set its `item_id` and `amount`. Replace its `Mesh` to change how it looks.
5. Instance `inventory_panel.tscn` in your UI and set its `inventory`.

Spend items from anywhere that can reach the inventory:

```gdscript
func _on_door_used(actor: Node) -> void:
	var inventory := Inventory.find_in(actor)
	if inventory != null and inventory.remove(&"key"):
		open()
```

## Requirements

| Kind | Needed |
|---|---|
| Physics layers | The collector is on layer 2. Pickups look only at layer 2. |

## Settings

| Member | On | Purpose |
|---|---|---|
| `max_stack` | `Inventory` | The most of one item that can be carried. |
| `add(item_id, amount)` | `Inventory` | Adds what fits and returns how many that was. |
| `remove(item_id, amount)` | `Inventory` | Removes that many, or nothing and returns false if there are fewer. |
| `has(item_id, amount)`, `get_count(item_id)`, `get_items()`, `clear()` | `Inventory` | Queries and reset. |
| `changed(item_id, count)` | `Inventory` | Signal with the new count; 0 when the last one goes. |
| `Inventory.find_in(node)` | `Inventory` | The inventory that is a direct child of a node. |
| `item_id`, `amount` | `Pickup` | What it gives. |
| `spin_speed` | `Pickup` | Idle spin, in turns per second. |
| `collected(by)` | `Pickup` | Signal just before it disappears, for a sound or an effect. |
| `inventory` | `InventoryPanel` | The inventory to list. |

A pickup that does not fit under `max_stack` stays where it is.

## Saving

`Inventory` and `Pickup` join the `saveable` group, so the `save_load` recipe saves them with no extra code. A pickup collected before the save has no entry in it, so loading removes it again, and coins cannot be duplicated or lost through a save and load.

## Where to take it next

- Items have no data beyond a name. Make an `ItemData` resource with a display name, icon, description and stack size, and key the inventory by it.
- No slots, weight or capacity; the only limit is `max_stack` per item.
- No using, dropping or equipping. Those are functions that call `remove()` and then do something.
- The panel is a text list that is always visible. Give it icons, or show it from an input action.
- Pickups are collected on touch. To require a button press, put an `Interactable` from the `interaction` recipe on the pickup instead and add to the inventory from `interacted`.
