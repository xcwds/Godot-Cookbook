extends SceneTree
## Headless test for recipes/state_machine. Run with:
##   godot --headless --path . -s tests/test_state_machine.gd

var _failures := 0


class Recorder:
	extends State
	var log: Array = []
	var on_physics := Callable()

	func _enter(previous_state: StringName, data: Dictionary) -> void:
		log.append(["enter", previous_state, data])

	func _exit() -> void:
		log.append(["exit"])

	func _physics_update(_delta: float) -> void:
		log.append(["physics"])
		if on_physics.is_valid():
			on_physics.call()


func _initialize() -> void:
	# Nodes only become ready once the tree is running.
	await process_frame
	_test_starts_in_first_child_or_initial_state()
	_test_transition_runs_exit_then_enter_and_waits_a_tick()
	_test_hand_off_runs_new_state_in_same_tick()
	_test_hand_off_loop_is_capped()
	_test_unknown_state_is_ignored()
	_test_only_the_current_state_can_transition()
	_test_outside_code_can_transition_and_restart()
	if _failures == 0:
		print("test_state_machine: OK")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _make(names: Array, initial := "") -> StateMachine:
	var machine := StateMachine.new()
	for state_name: String in names:
		var state := Recorder.new()
		state.name = state_name
		machine.add_child(state)
	if initial != "":
		machine.initial_state = machine.get_node(initial)
	root.add_child(machine)
	return machine


func _test_starts_in_first_child_or_initial_state() -> void:
	var first := _make(["A", "B"])
	_check(first.state.name == &"A", "starts in first child")
	_check(first.state.log == [["enter", &"", {}]], "initial state is entered once")
	var chosen := _make(["A", "B"], "B")
	_check(chosen.state.name == &"B", "starts in initial_state")
	first.free()
	chosen.free()


func _test_transition_runs_exit_then_enter_and_waits_a_tick() -> void:
	var machine := _make(["A", "B"])
	var a: Recorder = machine.get_node("A")
	var b: Recorder = machine.get_node("B")
	var changes: Array = []
	machine.state_changed.connect(
		func(from: StringName, to: StringName) -> void: changes.append([from, to])
	)
	a.on_physics = func() -> void: a.transition_to(&"B", {"n": 1})
	machine._physics_process(0.1)
	_check(machine.state == b, "transition switches state")
	_check(a.log.back() == ["exit"], "old state is exited")
	_check(b.log == [["enter", &"A", {"n": 1}]], "new state is entered with data, not updated")
	_check(changes == [[&"A", &"B"]], "state_changed is emitted")
	machine._physics_process(0.1)
	_check(b.log.back() == ["physics"], "new state updates on the next tick")
	machine.free()


func _test_hand_off_runs_new_state_in_same_tick() -> void:
	var machine := _make(["A", "B"])
	var a: Recorder = machine.get_node("A")
	var b: Recorder = machine.get_node("B")
	a.on_physics = func() -> void: a.hand_off_to(&"B")
	machine._physics_process(0.1)
	_check(b.log == [["enter", &"A", {}], ["physics"]], "hand-off updates new state in same tick")
	machine.free()


func _test_hand_off_loop_is_capped() -> void:
	var machine := _make(["A", "B"])
	var a: Recorder = machine.get_node("A")
	var b: Recorder = machine.get_node("B")
	a.on_physics = func() -> void: a.hand_off_to(&"B")
	b.on_physics = func() -> void: b.hand_off_to(&"A")
	print("(an error about hand-offs is expected below)")
	machine._physics_process(0.1)
	var updates := a.log.count(["physics"]) + b.log.count(["physics"])
	_check(updates == StateMachine.MAX_HAND_OFFS_PER_TICK, "hand-off loop stops at the cap")
	machine.free()


func _test_unknown_state_is_ignored() -> void:
	var machine := _make(["A"])
	var a: Recorder = machine.get_node("A")
	a.on_physics = func() -> void: a.transition_to(&"Missing")
	print("(an error about a missing state is expected below)")
	machine._physics_process(0.1)
	_check(machine.state == a, "unknown target keeps the current state")
	machine.free()


func _test_only_the_current_state_can_transition() -> void:
	var machine := _make(["A", "B", "C"])
	var a: Recorder = machine.get_node("A")
	var b: Recorder = machine.get_node("B")
	a.transition_to(&"B")
	_check(machine.state == b, "the current state can leave")
	# A is no longer current: a late request from it must not move the machine.
	a.transition_to(&"C")
	_check(machine.state == b, "a state that is not current cannot trigger a transition")
	_check(b.log.back() != ["exit"], "and the current state is not exited")
	machine.free()


func _test_outside_code_can_transition_and_restart() -> void:
	var machine := _make(["A", "B"], "B")
	var a: Recorder = machine.get_node("A")
	var b: Recorder = machine.get_node("B")
	var changes: Array = []
	machine.state_changed.connect(
		func(from: StringName, to: StringName) -> void: changes.append([from, to])
	)
	b.log.clear()
	machine.transition_to(&"A", {"why": "stun"})
	_check(machine.state == a, "transition_to switches from outside")
	_check(b.log == [["exit"]], "the old state is exited")
	_check(a.log == [["enter", &"B", {"why": "stun"}]], "the new state gets the data")
	_check(changes == [[&"B", &"A"]], "state_changed is emitted")

	b.log.clear()
	machine.restart()
	_check(machine.state == b, "restart returns to the initial state, not the first child")
	machine.restart()
	_check(
		b.log == [["enter", &"A", {}], ["exit"], ["enter", &"B", {}]],
		"restarting re-enters the current state"
	)

	print("(an error about state 'Nope' is expected below)")
	machine.transition_to(&"Nope")
	_check(machine.state == b, "an unknown state from outside changes nothing")
	machine.free()
