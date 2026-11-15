# State machine

A finite state machine built from nodes: a `StateMachine` node with one `State` child per state. Only the current state receives input, process and physics callbacks.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo_state.gd`) into your project.
2. Add a `Node` with `state_machine.gd` to your scene, and one child `Node` per state, each with a script that `extends State`.
3. Set `initial_state` on the machine, or leave it empty to start in the first child.
4. In each state, override the callbacks you need and switch states by name:

```gdscript
extends State


func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	owner.velocity.y = owner.jump_velocity


func _physics_update(delta: float) -> void:
	if owner.is_on_floor():
		hand_off_to(&"Idle")
		return
	owner.velocity += owner.get_gravity() * delta
	owner.move_and_slide()
```

| Override | Called |
|---|---|
| `_enter(previous_state, data)` | When the machine switches to this state. |
| `_exit()` | When it switches away. |
| `_update(delta)` | Every frame. |
| `_physics_update(delta)` | Every physics tick. |
| `_handle_input(event)` | For unhandled input. |

There are two ways to switch:

- `transition_to(name, data)`: the new state gets its first callback on the next frame or tick. Use it when this state has already done the work for this frame.
- `hand_off_to(name, data)`: the new state also runs the callback that is executing now, so no frame is lost. Use it at the top of a callback when this state should not handle the frame, and `return` straight after.

If the machine has an `owner`, it enters the first state after the owner is ready, so states can use the owner's `@onready` variables in `_enter`.

## Requirements

None. See `recipe.cfg`.

## Settings

| Member | Purpose |
|---|---|
| `initial_state` | State to start in. Defaults to the first child state. |
| `is_debug` | Print every transition. |
| `state` | The current state. |
| `state_changed(previous_state, new_state)` | Signal emitted after every transition. |

## Where to take it next

- Transitions are by node name, so a typo is only reported at runtime (`no state named ...`). Constants for the names, as `third_person_movement` uses, are the cheap fix.
- No history: `_enter` receives the previous state's name, but there is no stack to pop back to.
- No nested or parallel machines. You can put a second `StateMachine` inside a state, but nothing forwards callbacks to it for you.
- Hand-offs are capped at 8 per callback to catch two states that keep handing off to each other.
