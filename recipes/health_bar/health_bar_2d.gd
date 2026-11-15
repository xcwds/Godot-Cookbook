class_name HealthBar2D
extends TextureProgressBar
## Health bar that changes colour as it drains. Point [member health] at a
## [Health] node and it keeps itself up to date.

## The health to display. Optional: call [method set_values] yourself instead.
@export var health: Health:
	set = set_health
## Below this fraction of the maximum the bar uses [member low_color].
@export_range(0.0, 1.0) var low_threshold := 0.35
## Below this fraction of the maximum the bar uses [member mid_color].
@export_range(0.0, 1.0) var mid_threshold := 0.7
@export var low_color := Color(0.85, 0.2, 0.2)
@export var mid_color := Color(0.9, 0.75, 0.2)
@export var high_color := Color(0.2, 0.8, 0.2)


func set_health(new_health: Health) -> void:
	if health != null:
		health.changed.disconnect(set_values)
	health = new_health
	if health != null:
		health.changed.connect(set_values)
		set_values(health.current_health, health.max_health)


## Shows [param current] out of [param maximum]. Same arguments as
## [signal Health.changed], so it can be connected to it directly.
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
