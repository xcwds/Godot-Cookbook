extends Control

@onready var _pool: ObjectPool = $Pool
@onready var _status: Label = %Status
@onready var _area: Control = %Area


func _ready() -> void:
	%Spawn.pressed.connect(_spawn.bind(1))
	%SpawnMany.pressed.connect(_spawn.bind(12))


func _process(_delta: float) -> void:
	_status.text = ("%d in use of %d created" % [_pool.get_active_count(), _pool.get_total_count()])


func _spawn(count: int) -> void:
	for i in count:
		var bubble: Label = _pool.acquire()
		var at := Vector2(randf(), randf()) * (_area.size - Vector2(80, 30))
		bubble.appear(_area.global_position + at)
