class_name HealthBar2D
extends TextureProgressBar
## Bar that changes colour as it drains. Point [member meter] at a [Meter],
## such as a Health node, and it keeps itself up to date.

## The meter to display. Optional: call [method set_values] yourself instead.
@export var meter: Meter:
	set = set_meter
## Below this fraction of the maximum the bar uses [member low_color].
@export_range(0.0, 1.0) var low_threshold := 0.35
## Below this fraction of the maximum the bar uses [member mid_color].
@export_range(0.0, 1.0) var mid_threshold := 0.7
@export var low_color := Color(0.85, 0.2, 0.2)
@export var mid_color := Color(0.9, 0.75, 0.2)
@export var high_color := Color(0.2, 0.8, 0.2)

## The old name of [member meter]. Scenes and code that set it keep working.
var health: Meter:
	get:
		return meter
	set(value):
		set_meter(value)


func set_meter(new_meter: Meter) -> void:
	if meter != null:
		meter.changed.disconnect(set_values)
	meter = new_meter
	if meter != null:
		meter.changed.connect(set_values)
		set_values(meter.current, meter.maximum)


## The old name of [method set_meter].
func set_health(new_health: Meter) -> void:
	set_meter(new_health)


## Shows [param current] out of [param maximum]. Same arguments as
## [signal Meter.changed], so it can be connected to it directly.
func set_values(current: float, maximum: float) -> void:
	max_value = maximum
	value = clampf(current, 0.0, maximum)
	var fraction := value / maximum if maximum > 0.0 else 0.0
	if fraction < low_threshold:
		tint_progress = low_color
	elif fraction < mid_threshold:
		tint_progress = mid_color
	else:
		tint_progress = high_color
