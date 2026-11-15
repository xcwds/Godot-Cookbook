# Chase enemy

An enemy (`ChaseEnemy`) that stands at its post, chases a target it can see, stops when it gets close, and walks home when it loses the target. It finds its way around obstacles with a `NavigationAgent3D`, and its two behaviours are states under a `StateMachine`.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) and the `state_machine` recipe into your project.
2. Give your level a navigation mesh: add a `NavigationRegion3D`, put the level geometry under it, create a `NavigationMesh` on it and press **Bake NavigationMesh** in the editor toolbar.
3. Instance `chase_enemy.tscn` on the navigation mesh. Its origin is at its feet.
4. Tell it what to chase: add your player to the `player` group, or set the enemy's `target`.
5. Name physics layer 5 `enemy`.

To make it do something when it arrives, connect `reached_target`. To hurt on contact, add a `Hitbox` from the `hitbox` recipe as a child, as the demo does.

## Requirements

| Kind | Needed |
|---|---|
| Recipes | `state_machine` |
| Level | A `NavigationRegion3D` with a baked navigation mesh. |
| Physics layers | The enemy is on layer 5 and collides with layer 1. Its line-of-sight check looks at layer 1. |

## Settings

| Member | Purpose |
|---|---|
| `target`, `target_group` | What to chase. With no `target`, the first node in the group. |
| `target_height` | Height above the target's origin that the enemy looks at. |
| `speed`, `turn_speed`, `stop_distance` | Movement. |
| `detection_range`, `lose_range` | Distances at which the target is noticed and given up. |
| `requires_line_of_sight`, `eye_height`, `lose_sight_time` | Seeing. A target out of sight for `lose_sight_time` seconds is given up. |
| `home` | Where it returns to. Set to its starting position on ready. |
| `target_spotted`, `target_lost`, `reached_target` | Signals. |

## Scene layout

- `StateMachine` with `Idle` (walk home, watch) and `Chase`. Add states such as `Attack` or `Patrol` next to them.
- `NavigationAgent3D`: path settings such as how close counts as arrived.
- `Body` and `Visor`: placeholder visuals. Replace them with a model facing -Z.

## Where to take it next

- It sees in all directions. Add a field-of-view check to `can_see_target()` using the enemy's facing.
- Enemies do not avoid each other and can overlap. Turn on avoidance on the `NavigationAgent3D` and move with its `velocity_computed` signal.
- The enemy and the player do not block each other, because they are on different layers and neither looks at the other's.
- It stops and stares when it reaches the target. Add an `Attack` state entered from `Chase`.
- It only waits at home. A `Patrol` state walking between markers is the usual addition.
- The navigation mesh is static. Rebake, or use navigation obstacles, when the level changes.
