class_name StateMachine
extends Node
## Runs one child [State] at a time and forwards input, process and physics
## callbacks to it.

## Emitted after every transition, once the new state has been entered.
signal state_changed(previous_state: StringName, new_state: StringName)

## Upper limit on hand-offs within one callback, to catch states that hand
## off to each other forever.
const MAX_HAND_OFFS_PER_TICK := 8

## State to start in. Defaults to the first child state.
@export var initial_state: State
## Print every transition.
@export var is_debug := false

## The current state. Read-only; states change it with
## [method State.transition_to], other code with [method transition_to].
var state: State

var _initial_state: State
var _continue_tick := false


func _ready() -> void:
	for child in get_children():
		if child is State:
			child.transition_requested.connect(_on_transition_requested.bind(child))
			if state == null:
				state = child
	if initial_state != null:
		state = initial_state
	_initial_state = state
	if state == null:
		push_error("%s has no State children." % get_path())
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return

	# Let the scene finish setting up first, so states can use their owner.
	if owner != null and not owner.is_node_ready():
		await owner.ready
	state._enter(&"", {})
	state_changed.emit(&"", state.name)


## Switches to the child state named [param next_state] from outside the
## machine, for example to interrupt a character for a cutscene or a respawn.
## The current state's [method State._exit] runs first, as for any
## transition, also when [param next_state] is the current state.
func transition_to(next_state: StringName, data: Dictionary = {}) -> void:
	if state == null:
		return
	var target := get_node_or_null(NodePath(next_state)) as State
	if target == null:
		push_error("%s: no state named '%s'." % [get_path(), next_state])
		return
	_switch(target, data, false)


## Leaves the current state and enters the initial state again, as if the
## machine had just started.
func restart(data: Dictionary = {}) -> void:
	if _initial_state != null:
		transition_to(_initial_state.name, data)


func _unhandled_input(event: InputEvent) -> void:
	_run(func(current: State) -> void: current._handle_input(event))


func _process(delta: float) -> void:
	_run(func(current: State) -> void: current._update(delta))


func _physics_process(delta: float) -> void:
	_run(func(current: State) -> void: current._physics_update(delta))


## Calls [param callback] on the current state, and again on each state that
## is handed the tick with [method State.hand_off_to].
func _run(callback: Callable) -> void:
	if state == null:
		return
	for i in MAX_HAND_OFFS_PER_TICK:
		_continue_tick = false
		callback.call(state)
		if not _continue_tick:
			return
	_continue_tick = false
	push_error(
		(
			"%s: more than %d hand-offs in one tick, last state %s."
			% [get_path(), MAX_HAND_OFFS_PER_TICK, state.name]
		)
	)


func _on_transition_requested(
	next_state: StringName, data: Dictionary, continue_tick: bool, sender: State
) -> void:
	# Only the current state may leave. A request from any other state is
	# late, for example a timer that fired after the machine moved on.
	if sender != state:
		return
	var target := get_node_or_null(NodePath(next_state)) as State
	if target == null:
		push_error("%s: no state named '%s'." % [get_path(), next_state])
		return
	_switch(target, data, continue_tick)


func _switch(target: State, data: Dictionary, continue_tick: bool) -> void:
	if is_debug:
		print("%s: %s -> %s" % [get_path(), state.name, target.name])

	var previous := state
	previous._exit()
	state = target
	state._enter(previous.name, data)
	_continue_tick = continue_tick
	state_changed.emit(previous.name, state.name)
