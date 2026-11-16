extends Control

@onready var _stamina: Meter = $Stamina
@onready var _status: Label = %Status
@onready var _log: Label = %Log


func _ready() -> void:
	_stamina.changed.connect(_on_changed)
	_stamina.depleted.connect(func() -> void: _log.text = "depleted")
	_stamina.filled.connect(func() -> void: _log.text = "filled")
	%Spend.pressed.connect(_on_spend_pressed)
	%Drain.pressed.connect(func() -> void: _log.text = "drained %d" % _stamina.drain(3.0))
	%Add.pressed.connect(func() -> void: _log.text = "added %d" % _stamina.add(2.0))
	%Fill.pressed.connect(_stamina.fill)
	_on_changed(_stamina.current, _stamina.maximum)


func _on_spend_pressed() -> void:
	_log.text = "spent 4" if _stamina.spend(4.0) else "not enough to spend 4"


func _on_changed(current: float, maximum: float) -> void:
	_status.text = "Stamina: %d / %d" % [current, maximum]
