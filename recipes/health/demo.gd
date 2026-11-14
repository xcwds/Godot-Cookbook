extends Control

@onready var _health: Health = $Health
@onready var _status: Label = %Status
@onready var _log: Label = %Log


func _ready() -> void:
	_health.changed.connect(_on_changed)
	_health.damaged.connect(func(amount: float) -> void: _log.text = "damaged: %d" % amount)
	_health.died.connect(func() -> void: _log.text = "died")
	%Damage.pressed.connect(_health.damage.bind(3.0))
	%Heal.pressed.connect(_health.heal.bind(2.0))
	%Reset.pressed.connect(_health.reset)
	_on_changed(_health.current_health, _health.max_health)


func _on_changed(current: float, maximum: float) -> void:
	_status.text = "Health: %d / %d" % [current, maximum]
