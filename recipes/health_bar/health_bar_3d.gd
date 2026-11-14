class_name HealthBar3D
extends Sprite3D
## A [HealthBar2D] rendered into the 3D world as a billboard, for floating
## above characters.

## The health to display. Optional: call [method set_values] yourself instead.
@export var health: Health:
	set(value):
		health = value
		if is_node_ready():
			_bar.health = value

@onready var _bar: HealthBar2D = $SubViewport/HealthBar2d


func _ready() -> void:
	texture = $SubViewport.get_texture()
	_bar.health = health


func set_values(current: float, maximum: float) -> void:
	_bar.set_values(current, maximum)
