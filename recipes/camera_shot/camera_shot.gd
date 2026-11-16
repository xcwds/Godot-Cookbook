class_name CameraShot
extends Node3D
## One placed view for a [CameraDirector]: the camera goes to where this node
## is and looks along its -Z axis, like a Camera3D placed here would.

## Field of view of the shot, in degrees.
@export_range(1.0, 179.0) var fov := 75.0
## Seconds the camera takes to get here from wherever it was.
@export var blend_time := 1.0
## Seconds the camera stays once it has arrived. Negative stays until
## [method CameraDirector.stop] or another shot is played.
@export var hold_time := 2.0
## Keep looking at this node instead of along the shot's own -Z axis, so the
## shot can track something that moves.
@export var look_at_target: Node3D


## Where the camera should be for this shot right now.
func get_view() -> Transform3D:
	# Where the shot is drawn this frame, in case something moves it.
	var view := get_global_transform_interpolated().orthonormalized()
	if look_at_target != null and is_instance_valid(look_at_target):
		var to_target := look_at_target.get_global_transform_interpolated().origin - view.origin
		# looking_at() cannot aim at its own position or straight up or down.
		if not to_target.is_zero_approx() and not to_target.cross(Vector3.UP).is_zero_approx():
			view.basis = Basis.looking_at(to_target)
	return view
