# Projectiles and object pool

Three pieces that work together or apart:

- `ObjectPool`: keeps instances of a scene for reuse, so firing does not create and free a node per shot. It is not specific to projectiles.
- `Projectile`: flies straight ahead until it hits something or times out. It checks the whole distance it covers each physics tick, so it cannot pass through a thin wall however fast it is.
- `ProjectileLauncher`: fires projectiles from where it is, at a set rate, from an input action or from code.

## Add it to your project

1. Copy this folder (without the `demo*` files) into your project.
2. Add a `Node3D` with `projectile_launcher.gd` at the muzzle of your weapon, or under a first-person camera. It fires along its -Z axis.
3. Set its `projectile_scene` to `projectile.tscn`, or to your own scene with `projectile.gd` on the root.
4. Set `fire_action` to an input action to fire while it is held, or call `fire()` yourself.

The launcher makes its own pool. To share one pool between several launchers, add a `Node` with `object_pool.gd` to the scene and set each launcher's `pool`.

To make projectiles deal damage with the `hitbox` recipe, add a `Hitbox` to your projectile scene and end the flight when it lands a hit, as `demo_projectile.gd` does:

```gdscript
extends Projectile

@onready var _hitbox: Hitbox = $Hitbox


func _ready() -> void:
	launched.connect(func() -> void: _hitbox.active = true)
	despawned.connect(func() -> void: _hitbox.active = false)
	_hitbox.hit_landed.connect(func(_hurtbox: Hurtbox) -> void: despawn())
```

## Requirements

| Kind | Needed |
|---|---|
| Physics layers | Projectiles stop at layer 1 by default; change `collision_mask` on the projectile. |

## Settings

| Member | On | Purpose |
|---|---|---|
| `speed`, `lifetime`, `gravity_scale`, `collision_mask` | `Projectile` | Flight. `gravity_scale` above 0 makes it arc. |
| `launch(transform)`, `despawn()` | `Projectile` | Start and end a flight. |
| `launched`, `hit(collision)`, `despawned` | `Projectile` | Signals. `collision` has `collider`, `position` and `normal`. |
| `projectile_scene`, `pool` | `ProjectileLauncher` | What to fire, and optionally where to take it from. |
| `fire_rate`, `fire_action` | `ProjectileLauncher` | Shots per second, and the action that fires while held. |
| `fire()`, `can_fire()`, `fired(projectile)` | `ProjectileLauncher` | Fire from code, and a signal for muzzle flashes and sounds. |
| `scene`, `initial_size`, `can_grow` | `ObjectPool` | What to pool, how many to make up front, and whether to make more when they run out. |
| `acquire()`, `release(node)`, `ObjectPool.release_or_free(node)` | `ObjectPool` | Take an instance, and give it back. |
| `get_active_count()`, `get_total_count()` | `ObjectPool` | For tuning `initial_size`. |

## How the pool works

Instances are children of the pool. A released instance is hidden and its `process_mode` is set to disabled, which also takes its physics areas and bodies out of the simulation. An acquired instance is shown and enabled again; it is up to the instance to reset its own state, which `Projectile.launch()` does.

## Where to take it next

- The wall check is a ray, so the projectile has no size against the world. Use a `ShapeCast3D` for large projectiles.
- Nothing happens on impact. Spawn a spark or a decal from `hit`, using `collision["position"]` and `collision["normal"]`; those are good candidates for a second pool.
- No spread, burst or ammunition. They belong in `ProjectileLauncher.fire()`.
- No homing. Steer `velocity` toward a target in `_physics_process()`.
- The launcher fires where it points, not at what is under the crosshair. For a first-person weapon held to one side, aim the launcher at the point the camera is looking at.
