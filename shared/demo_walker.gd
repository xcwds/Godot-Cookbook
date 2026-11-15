extends Node3D
## Demo-only stand-in for a character: a capsule that walks in a circle.

@export var radius := 6.0
@export var speed := 3.0
## When false the walker keeps moving but something else decides its facing.
@export var auto_face := true

var _angle := 0.0


func _process(delta: float) -> void:
	_angle += speed / radius * delta
	position = Vector3(cos(_angle) * radius, position.y, sin(_angle) * radius)
	if auto_face:
		# Face along the direction of travel (the tangent of the circle).
		rotation.y = -_angle + PI
