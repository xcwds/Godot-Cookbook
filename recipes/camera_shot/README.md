# Camera shot

Scripted camera shots for cutscenes and points of interest. A `CameraDirector` takes the view from the gameplay camera, blends to one placed `CameraShot` after another, then blends back to wherever the gameplay camera is by then. There are no player controls on it.

## Add it to your project

1. Copy this folder (without `demo.tscn` and `demo.gd`) into your project.
2. Instance `camera_director.tscn` once in your scene.
3. For each view, add a `Node3D`, attach `camera_shot.gd` and place it like a camera: it looks along its own -Z axis. To frame it, select the node and use **Perspective > Align Transform with View** in the 3D editor.
4. Set `fov`, `blend_time` and `hold_time` on each shot.
5. Play them from your code and stop player input while they run:

```gdscript
func _ready() -> void:
	director.input_locked.connect(func() -> void: player.set_physics_process(false))
	director.input_unlocked.connect(func() -> void: player.set_physics_process(true))


func _on_trigger_body_entered(_body: Node3D) -> void:
	director.play_sequence([$Shots/Wide, $Shots/Close])
```

## Requirements

None. It works with any current `Camera3D` and needs no other recipe, input action or physics layer.

## Settings

On `CameraShot`:

| Member | Purpose |
|---|---|
| `fov` | Field of view of the shot, in degrees. |
| `blend_time` | Seconds the camera takes to get to this shot. `0` cuts. |
| `hold_time` | Seconds the camera stays once it has arrived. Negative stays until `stop()` or another `play()`. |
| `look_at_target` | A node to keep looking at, so the shot tracks something that moves. Empty uses the shot's own rotation. |

On `CameraDirector`:

| Member | Purpose |
|---|---|
| `play(shot)`, `play_sequence(shots)` | Play one shot or several in order, then return. Called while playing, the new shots replace the old ones and the camera carries on from where it is. |
| `stop(blend_time)` | End early and return: at once by default, or with a blend of that many seconds. Use it for a skip button. |
| `return_blend_time` | Seconds to blend back after the last shot. `0` cuts back. |
| `easing` | Shape of every blend. The default eases in and out; `1` is linear. |
| `locks_input` | Emit `input_locked` and `input_unlocked` around the shots. Turn it off for shots the player can walk through. |
| `shot_started(shot)`, `shot_finished(shot)` | When the camera starts toward a shot, and when its hold time is over. Open the door or start the dialogue line here. |
| `sequence_finished` | Once, when the view is back with the gameplay camera, also after `stop()`. |
| `is_playing()`, `get_current_shot()` | State, for a skip prompt and the like. |
| `get_camera()` | The director's `Camera3D`, for near and far planes, cull mask or attributes. |

## How it behaves

- **Taking and giving back the view.** The first `play()` remembers the viewport's current `Camera3D`, starts from where that camera is drawn and from its field of view, and makes the director's own camera current. At the end the remembered camera is made current again. If it was freed meanwhile, the director lets go of the view and still emits `sequence_finished`.
- **Blending.** Position is interpolated in a straight line, rotation by the shortest turn and field of view linearly, all with the same easing. Each blend starts from where the camera is at that moment and aims at where the shot or the gameplay camera is right now, so both may move during the blend.
- **Input.** The director never touches your character or your camera rig. With `locks_input` on, `input_locked` comes before the first shot and `input_unlocked` with `sequence_finished`. A camera rig that keeps reading the mouse while it is not current, such as `OrbitCamera`, should be stopped and restarted from the same signals; the demo does that.
- **Frame rate and pausing.** The camera moves in `_process` and is not physics-interpolated. It stops while the tree is paused; set the director's process mode to Always for shots that play during a pause.

## Scene layout

`CameraDirector` (`Node`) → `Camera` (`Camera3D`). Shots are plain `Node3D` markers anywhere in the scene, also on things that move.

## Where to take it next

- Moving shots: follow a `Path3D` over a duration, or animate a `CameraShot` node with an `AnimationPlayer` and play it with a negative `hold_time`.
- For anything long or tightly timed, use an `AnimationPlayer` that animates a camera directly. This recipe is for a handful of shots, not a timeline.
- Letterbox bars and subtitles: a `CanvasLayer` shown on `input_locked` and hidden on `input_unlocked`.
- A straight-line blend can pass through walls. Add an in-between shot, or cut with `blend_time = 0`.
- Only position, rotation and field of view are blended. Depth of field and other camera attributes are left as they are on the director's camera.
