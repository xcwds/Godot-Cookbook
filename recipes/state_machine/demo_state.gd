extends State
## Demo-only state: shows its name and colour, then moves on after a delay.

@export var next_state: State
@export var duration := 1.0
@export var color := Color.WHITE

var _elapsed := 0.0


func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	_elapsed = 0.0
	owner.get_node("%Light").color = color
	owner.get_node("%StateLabel").text = name


func _update(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		transition_to(next_state.name)
