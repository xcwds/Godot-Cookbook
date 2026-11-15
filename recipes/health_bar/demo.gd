extends Node3D

@onready var _health: Health = $Health


func _ready() -> void:
	%Damage.pressed.connect(_health.damage.bind(15.0))
	%Heal.pressed.connect(_health.heal.bind(10.0))
	%Reset.pressed.connect(_health.reset)
