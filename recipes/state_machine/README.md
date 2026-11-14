# State machine

A finite state machine built from nodes: a `StateMachine` node with one `State` child per state. Only the current state receives input, process and physics callbacks.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo_state.gd`) into your project.
2. Add a `Node` with `state_machine.gd` to your scene and one child `Node` per state, each with a script that `extends State`.
3. Set `initial_state` on the machine, or leave it empty to start in the first child.
4. In a state, override `_enter`, `_exit`, `_do_process`, `_do_physics_process` or `_do_unhandled_input`, and call `finished.emit("OtherStateName")` to switch.

The machine waits for `owner.ready`, so it must live in a scene whose root is its owner.

## Requirements

None. See `recipe.cfg`.

## Settings

| Property | On | Purpose |
|---|---|---|
| `initial_state` | `StateMachine` | State to start in. |
| `is_debug` | `StateMachine` | Print every transition. |

## Where to take it next

- Transitions are by node name. Typed references or an enum would catch typos at parse time.
- `State._enter()` can re-run a callback in the new state within the same frame, driven by a dictionary built with `generate_delta_dictionary()`. It works but is easy to get wrong; the plan is to move that into the machine.
- No state history, so there is no "return to previous state".
