extends SceneTree
## Base for the headless tests in tests/. A test file extends this script and
## contains functions named test_*; they are found by name and run in the order
## they are written, so none has to be registered. Run a test file with:
##   godot --headless --path . -s tests/test_health.gd
##
## Each test prints its name before it runs, so a script error or a hang can be
## traced to a test. A failed _check() prints "FAIL <test>: <message>" and the
## run exits with 1. Nodes added with _spawn() are freed after the test that
## added them.
##
## Override _before_all(), _after_all(), _before_each() and _after_each() for
## setup and cleanup. Like the tests, they may use await.

## How long _tap() holds an action, in seconds.
const TAP_SECONDS := 0.05

var _failures := 0
var _current_test := ""
var _spawned: Array[Node] = []


func _initialize() -> void:
	# Nodes only become ready once the tree is running.
	await process_frame
	var file := (get_script() as Script).resource_path.get_file().get_basename()
	var tests := _test_names()
	if tests.is_empty():
		printerr("FAIL: %s has no test_* functions" % file)
		_failures += 1
	_current_test = "_before_all"
	await _before_all()
	var failed_tests := 0
	for test in tests:
		_current_test = test
		print("  " + test)
		var failures_before := _failures
		await _before_each()
		await call(test)
		await _after_each()
		_free_spawned()
		if _failures > failures_before:
			failed_tests += 1
	_current_test = "_after_all"
	await _after_all()
	_free_spawned()
	if _failures == 0:
		print("%s: OK (%d tests)" % [file, tests.size()])
	else:
		printerr("%s: %d of %d tests FAILED" % [file, failed_tests, tests.size()])
	quit(1 if _failures > 0 else 0)


## Runs once before the first test.
func _before_all() -> void:
	pass


## Runs once after the last test.
func _after_all() -> void:
	pass


## Runs before every test.
func _before_each() -> void:
	pass


## Runs after every test, before the nodes it spawned are freed.
func _after_each() -> void:
	pass


## Counts a failure and prints the message unless the condition holds.
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL %s: %s" % [_current_test, message])


## Like _check(actual == expected, ...), and prints both values on failure.
func _check_eq(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s (got %s, expected %s)" % [message, actual, expected])


## Adds a node to the tree (under the root unless a parent is given) and frees
## it after the current test. Returns the node.
func _spawn(node: Node, parent: Node = null) -> Node:
	(parent if parent != null else root).add_child(node)
	_spawned.append(node)
	return node


## Waits for a number of physics ticks.
func _wait_physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


## Waits for the physics ticks that fit in a time, whatever the frame rate.
func _wait(seconds: float) -> void:
	await _wait_physics_frames(roundi(seconds * Engine.physics_ticks_per_second))


## Waits for a number of rendered frames, each with its physics tick.
func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame


## Sends an action press and then its release as input events, a frame apart,
## the way _input() and _unhandled_input() receive a key.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


## Holds an action for a moment, for code that polls Input.
func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _wait(TAP_SECONDS)
	Input.action_release(action)


# The test_* functions of the test file, in the order they are written.
func _test_names() -> Array[String]:
	var names: Array[String] = []
	for method: Dictionary in (get_script() as Script).get_script_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names


func _free_spawned() -> void:
	# Newest first, so a node spawned under another goes before its parent.
	_spawned.reverse()
	for node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()
