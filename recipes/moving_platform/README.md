# Moving platform

A platform (`MovingPlatform`) that travels between waypoints, waits at each stop, and carries whatever stands on it. Use it for lifts, shuttles between ledges, and platforms on a circuit.

Characters need no code to ride it. The platform is an `AnimatableBody3D`, and a `CharacterBody3D` standing on one is moved along with it by the engine. Both character recipes in the cookbook ride it as they are.

## Add it to your project

1. Copy this folder (without `demo.tscn`) into your project.
2. Instance `moving_platform.tscn` where the platform should start.
3. Set `waypoints` to where it should go, as offsets from that starting position. `(0, 4, 0)` is a lift that rises 4 metres; `(6, 0, 0), (6, 0, 6)` is two legs.
4. Resize the `CollisionShape3D` and `Mesh`, or replace the mesh with your own.

To start it from a switch or a trigger, turn `active` off in the scene and set it from code:

```gdscript
func _on_switch_used(_actor: Node) -> void:
	$Lift.active = true
```

## Requirements

| Kind | Needed |
|---|---|
| Physics layers | The platform is on layer 1, like the rest of the level. |

## Settings

| Member | Purpose |
|---|---|
| `waypoints` | Stops, as offsets from the starting position. The start is stop 0. |
| `speed` | Metres per second, averaged over each leg. |
| `wait_time` | Seconds to wait at each stop. |
| `loop_mode` | `PING_PONG` goes back the way it came, `LOOP` returns straight to the start, `ONCE` stops at the last waypoint. |
| `ease_in_out` | Speed up and slow down at each end. |
| `active` | Whether it is moving. `ONCE` turns this off when it finishes. |
| `waypoint_reached(index)` | Signal on arrival at a stop. |
| `get_target_index()` | The stop it is heading for or resting at. |

## Where to take it next

- Waypoints are numbers typed into the inspector. For editing in the 3D view, read positions from `Marker3D` nodes placed beside the platform, or follow a `Path3D`.
- The platform does not rotate. Rotating platforms carry characters too, but turning the character with the platform is up to the character.
- It does not wait for a passenger, and does not stop for something underneath it. An `Area3D` on top or below can set `active`.
- A fast platform dropping away can leave a character briefly airborne. Raise the character's `floor_snap_length` if you need steep or fast descents.
- Characters keep no momentum when they jump off. Both character recipes set their own horizontal velocity every tick.
