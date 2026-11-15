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
## True from the start of a transition until state_changed has been emitted.
var _is_switching := false
## True while the old state's _exit() runs.
var _is_exiting := false
## Requests made while a transition was running, applied once it is done.
var _queued: Array[Dictionary] = []


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
	_is_switching = true
	state._enter(&"", {})
	state_changed.emit(&"", state.name)
	_is_switching = false
	_apply_queued()


## Switches to the child state named [param next_state] from outside the
## machine, for example to interrupt a character for a cutscene or a respawn.
## The current state's [method State._exit] runs first, as for any
## transition, also when [param next_state] is the current state.
func transition_to(next_state: StringName, data: Dictionary = {}) -> void:
	if state == null:
		return
	_request(next_state, data, false)


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
	_request(next_state, data, continue_tick)


## Transitions do not nest. A request made while one runs, from the new
## state's _enter() or from a state_changed listener, waits until it has
## finished and is then applied in order. A request from _exit() is refused:
## the machine is already on its way somewhere.
func _request(next_state: StringName, data: Dictionary, continue_tick: bool) -> void:
	var target := get_node_or_null(NodePath(next_state)) as State
	if target == null:
		push_error("%s: no state named '%s'." % [get_path(), next_state])
		return
	if _is_exiting:
		push_error(
			(
				"%s: transition to '%s' requested while leaving %s; _exit() cannot transition."
				% [get_path(), next_state, state.name]
			)
		)
		return
	if _is_switching:
		_queued.append({"target": target, "data": data, "continue_tick": continue_tick})
		return
	_switch(target, data, continue_tick)
	_apply_queued()


func _switch(target: State, data: Dictionary, continue_tick: bool) -> void:
	var previous_name := state.name
	var target_name := target.name
	if is_debug:
		print("%s: %s -> %s" % [get_path(), previous_name, target_name])

	_is_switching = true
	_is_exiting = true
	state._exit()
	_is_exiting = false
	state = target
	state._enter(previous_name, data)
	_continue_tick = continue_tick
	state_changed.emit(previous_name, target_name)
	_is_switching = false


func _apply_queued() -> void:
	var applied := 0
	while not _queued.is_empty():
		if applied == MAX_HAND_OFFS_PER_TICK:
			push_error(
				(
					"%s: more than %d transitions requested from _enter() in a row, last state %s."
					% [get_path(), MAX_HAND_OFFS_PER_TICK, state.name]
				)
			)
			_queued.clear()
			return
		var next: Dictionary = _queued.pop_front()
		_switch(next["target"], next["data"], next["continue_tick"])
		applied += 1
