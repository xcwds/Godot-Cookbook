class_name State
extends Node
## One state of a [StateMachine]. Add it as a child of the machine and override
## the virtual methods you need. Only the current state receives callbacks.

## Emitted by [method transition_to] and [method hand_off_to]. The machine
## listens to this; states should call those methods rather than emit it.
signal transition_requested(next_state: StringName, data: Dictionary, continue_tick: bool)


## Called when the machine switches to this state. [param previous_state] is
## the name of the state being left, or empty for the initial state.
## [param data] is whatever the previous state passed along.
func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	pass


## Called when the machine switches away from this state.
func _exit() -> void:
	pass


## Called every frame while this state is current.
func _update(_delta: float) -> void:
	pass


## Called every physics tick while this state is current.
func _physics_update(_delta: float) -> void:
	pass


## Called for unhandled input while this state is current.
func _handle_input(_event: InputEvent) -> void:
	pass


## Switch to the sibling state named [param next_state]. The new state gets
## its first callback on the next frame or tick.
func transition_to(next_state: StringName, data: Dictionary = {}) -> void:
	transition_requested.emit(next_state, data, false)


## Switch to [param next_state] and let it run the callback that is executing
## right now, so no frame is lost. Use it when this state has decided it
## should not handle the current frame, and return straight after calling it.
func hand_off_to(next_state: StringName, data: Dictionary = {}) -> void:
	transition_requested.emit(next_state, data, true)
