extends Node3D
## Shoot the dummies. The counter shows how few projectiles the pool needs.

@onready var _launcher: ProjectileLauncher = $Player/Head/Launcher
@onready var _pool_label: Label = %PoolLabel


func _ready() -> void:
	for dummy in $Dummies.get_children():
		dummy.get_node("Health").died.connect(dummy.queue_free)


func _process(_delta: float) -> void:
	var pool := _launcher.pool
	if pool != null:
		_pool_label.text = (
			"Projectiles in flight: %d, created in total: %d"
			% [pool.get_active_count(), pool.get_total_count()]
		)
