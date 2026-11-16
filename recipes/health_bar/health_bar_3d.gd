class_name HealthBar3D
extends Sprite3D
## A [HealthBar2D] rendered into the 3D world as a billboard, for floating
## above characters.

## The meter to display, such as a Health node. Optional: call
## [method set_values] yourself instead.
@export var meter: Meter:
	set(value):
		meter = value
		if is_node_ready():
			_bar.meter = value

## The old name of [member meter]. Scenes and code that set it keep working.
var health: Meter:
	get:
		return meter
	set(value):
		meter = value

@onready var _bar: HealthBar2D = $SubViewport/HealthBar2d


func _ready() -> void:
	texture = $SubViewport.get_texture()
	_bar.meter = meter


func set_values(current: float, maximum: float) -> void:
	_bar.set_values(current, maximum)
