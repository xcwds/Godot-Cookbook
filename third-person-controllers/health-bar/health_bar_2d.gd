extends TextureProgressBar

const COLOR_LOW := Color(0.85, 0.2, 0.2)
const COLOR_MID := Color(0.9, 0.75, 0.2)
const COLOR_HIGH := Color(0.2, 0.8, 0.2)


func update_healthbar(new_value: float) -> void:
	tint_progress = (
		COLOR_LOW if new_value < max_value * 0.35 else
		COLOR_MID if new_value < max_value * 0.7 else
		COLOR_HIGH
	)
	value = clampf(new_value, 0, max_value)
