extends State
## Demo-only state: shows its name and colour, then moves on after a delay.

@export var next_state: State
@export var duration := 1.0
@export var color := Color.WHITE

var _elapsed := 0.0


func _enter(_previous_state_path: String, _data := {}) -> void:
	_elapsed = 0.0
	owner.get_node("%Light").color = color
	owner.get_node("%StateLabel").text = name


func _do_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		finished.emit(next_state.name)
