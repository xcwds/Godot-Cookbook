class_name ChaseEnemy
extends CharacterBody3D
## An enemy that waits at its post, chases a target it can see using the
## navigation mesh, and goes back when it loses it.
##
## The level needs a [NavigationRegion3D] with a baked navigation mesh.

signal target_spotted
signal target_lost
## Emitted when the enemy gets within [member stop_distance] of the target.
## Start an attack from here.
signal reached_target

## A new path is requested when the destination moves further than this.
const REPATH_DISTANCE := 0.25

## What to chase. Leave empty to chase the first node in [member target_group].
@export var target: Node3D
@export var target_group := &"player"
## Height above the target's origin to look at, for the line-of-sight check.
@export var target_height := 0.5

@export_group("Movement")
@export var speed := 3.5
## How quickly the enemy turns to face where it is going.
@export var turn_speed := 8.0
## The enemy stops this far from the target.
@export var stop_distance := 1.5

@export_group("Senses")
## The target is noticed inside this distance.
@export var detection_range := 10.0
## The chase is given up beyond this distance.
@export var lose_range := 15.0
## Only notice the target when nothing on the world layer is in the way.
@export var requires_line_of_sight := true
## Physics layers that block the view of the target.
@export_flags_3d_physics var line_of_sight_mask := 1
## Height of the enemy's eyes above its origin.
@export var eye_height := 1.5
## Seconds without seeing the target before the chase is given up.
@export var lose_sight_time := 2.0

## Where the enemy stands when it has nothing to chase.
var home := Vector3.ZERO

var _path_destination := Vector3.INF

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	home = global_position


func get_target() -> Node3D:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(target_group) as Node3D
	return target


func distance_to_target() -> float:
	var node := get_target()
	return global_position.distance_to(node.global_position) if node != null else INF


## True when the target is within [param within] metres and, if required,
## nothing blocks the view.
func can_see_target(within: float) -> bool:
	var node := get_target()
	if node == null or distance_to_target() > within:
		return false
	if not requires_line_of_sight:
		return true
	var from := global_position + Vector3.UP * eye_height
	var to := node.global_position + Vector3.UP * target_height
	var query := PhysicsRayQueryParameters3D.create(from, to, line_of_sight_mask)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Walks along the navigation path toward [param destination] for one
## physics tick. Returns true once it has arrived.
func move_toward_point(destination: Vector3, delta: float) -> bool:
	# Asking for a path is the expensive part, so only do it when the
	# destination has really moved.
	if destination.distance_to(_path_destination) > REPATH_DISTANCE:
		_path_destination = destination
		agent.target_position = destination
	var arrived := agent.is_navigation_finished()
	var direction := Vector3.ZERO
	if not arrived:
		direction = agent.get_next_path_position() - global_position
		direction.y = 0.0
		direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	face(direction, delta)
	fall_and_slide(delta)
	return arrived


## Stops walking but keeps falling and colliding.
func stand(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	fall_and_slide(delta)


func fall_and_slide(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()


## Turns toward [param direction] on the ground plane.
func face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := Vector3.FORWARD.signed_angle_to(direction, Vector3.UP)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
