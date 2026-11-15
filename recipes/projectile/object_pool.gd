class_name ObjectPool
extends Node
## Keeps instances of a scene around for reuse instead of creating and
## freeing them, for things that appear and disappear constantly: bullets,
## hit sparks, floating damage numbers.
##
## Instances are children of the pool. A released instance is hidden and
## stops processing until it is acquired again.

const POOL_META := &"object_pool"

## The scene to make instances of.
@export var scene: PackedScene
## How many instances to create up front.
@export var initial_size := 16
## Create more when all instances are in use. When off, [method acquire]
## returns null instead.
@export var can_grow := true

var _free: Array[Node] = []
var _total := 0


## Hands [param node] back to the pool it came from, or frees it if it did
## not come from one. Lets pooled scenes clean up without knowing.
static func release_or_free(node: Node) -> void:
	var pool: ObjectPool = node.get_meta(POOL_META, null)
	if is_instance_valid(pool):
		pool.release(node)
	else:
		node.queue_free()


func _ready() -> void:
	for i in initial_size:
		_free.append(_create())


## Returns an instance ready for use, or null if the pool is empty and
## cannot grow.
func acquire() -> Node:
	if _free.is_empty():
		if not can_grow:
			return null
		_free.append(_create())
	var node: Node = _free.pop_back()
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if "visible" in node:
		node.visible = true
	return node


## Puts an instance back. Releasing one that is already back does nothing.
func release(node: Node) -> void:
	if node in _free:
		return
	_deactivate(node)
	_free.append(node)


func get_total_count() -> int:
	return _total


func get_active_count() -> int:
	return _total - _free.size()


func _create() -> Node:
	var node := scene.instantiate()
	node.set_meta(POOL_META, self)
	_deactivate(node)
	add_child(node)
	_total += 1
	return node


func _deactivate(node: Node) -> void:
	# A disabled node stops processing, and its physics areas and bodies
	# are taken out of the simulation.
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if "visible" in node:
		node.visible = false
