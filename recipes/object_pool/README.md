# Object pool

`ObjectPool` keeps instances of a scene around for reuse, for things that appear and disappear constantly: bullets, hit sparks, floating damage numbers. Taking one from the pool and giving it back is cheaper than `instantiate()` and `queue_free()` every time, and it avoids a hitch when many are needed at once.

## Add it to your project

1. Copy this folder (without the `demo*` files) into your project.
2. Add a `Node` with `object_pool.gd` to your scene. Set `scene` to what it should hold and `initial_size` to how many you expect to need at once.
3. Take an instance, set it up, and give it back when it is done:

```gdscript
var spark: Node3D = $SparkPool.acquire()
spark.global_position = hit_position
spark.restart()
```

```gdscript
# In the spark's own script, when its effect has finished:
ObjectPool.release_or_free(self)
```

`release_or_free()` returns a node to the pool it came from and frees a node that did not come from one, so the same scene works pooled or not.

## Requirements

None. See `recipe.cfg`.

## Settings

| Member | Purpose |
|---|---|
| `scene` | The scene to make instances of. |
| `initial_size` | How many to create up front, in `_ready()`. |
| `can_grow` | Create more when all are in use. When off, `acquire()` returns null instead. |
| `acquire()` | Returns an instance, shown and processing. |
| `release(node)` | Puts an instance back. Doing it twice is harmless. |
| `ObjectPool.release_or_free(node)` | Static: back to its pool, or freed if it has none. |
| `get_active_count()`, `get_total_count()` | For tuning `initial_size`. |

## How it works

Instances are children of the pool. A released instance is hidden and its `process_mode` is set to disabled, which also takes its physics areas and bodies out of the simulation. An acquired instance is shown and enabled again.

Two things are left to the instance, because only it knows them:

- **Resetting its state.** An acquired instance is exactly as it was when it was released: same position, same velocity, same half-finished animation. Give the scene one method that starts it afresh, as `Projectile.launch()` does in the `projectile` recipe, and call it after `acquire()`.
- **Signal connections persist.** A connection made on a pooled instance is still there the next time it is handed out. Connect once, when the instance is first set up, not on every `acquire()`; otherwise the second use calls your function twice and the third three times. Connecting with `CONNECT_ONE_SHOT`, or checking `is_connected()` first, are the other ways out.

## Where to take it next

- The pool never shrinks. Free the surplus when `get_active_count()` has stayed low for a while, if memory matters.
- One scene per pool. A dictionary of pools keyed by scene makes a general `spawn(scene)` helper.
- `release()` looks the node up in an array, which is fine for dozens of instances. Keep a flag on the node for thousands.
- Instances stay children of the pool, so they move with it. Keep the pool at the origin, or set `top_level` on the instances.
