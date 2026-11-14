extends Node3D

@onready var _bar_2d: TextureProgressBar = %HealthBar2d
@onready var _bar_3d: Sprite3D = $HealthBar3d
@onready var _slider: HSlider = %Slider


func _ready() -> void:
	_bar_3d.set_max_value(_slider.max_value)
	_slider.value_changed.connect(_on_value_changed)
	_on_value_changed(_slider.value)


func _on_value_changed(value: float) -> void:
	_bar_2d.update_healthbar(value)
	_bar_3d.update_healthbar(value)
