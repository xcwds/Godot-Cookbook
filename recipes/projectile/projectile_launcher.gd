class_name ProjectileLauncher
extends Node3D
## Fires projectiles from where it is, along its -Z axis. Put it at the
## muzzle of a weapon, or under a first-person camera.

signal fired(projectile: Projectile)

## The projectile to fire. Used to make a pool when [member pool] is empty.
@export var projectile_scene: PackedScene
## An existing pool to take projectiles from. Share one between launchers
## that fire the same projectile.
@export var pool: ObjectPool
## Shots per second.
@export var fire_rate := 5.0
## Input action that fires while held. Leave empty to fire only from code.
@export var fire_action := &""

var _cooldown_left := 0.0


func _ready() -> void:
	if pool == null:
		pool = ObjectPool.new()
		pool.name = "ProjectilePool"
		pool.scene = projectile_scene
		# Projectiles must not move with the launcher, so the pool lives
		# beside the scene, not under this node.
		var scene := get_tree().current_scene
		var parent: Node = scene if scene != null else get_tree().root
		parent.add_child.call_deferred(pool)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if fire_action != &"" and Input.is_action_pressed(fire_action):
		fire()


func can_fire() -> bool:
	return _cooldown_left <= 0.0 and pool != null and pool.is_inside_tree()


## Fires one projectile if the cooldown allows. Returns it, or null.
func fire() -> Projectile:
	if not can_fire():
		return null
	var projectile := pool.acquire() as Projectile
	if projectile == null:
		return null
	_cooldown_left = 1.0 / fire_rate
	projectile.launch(global_transform)
	fired.emit(projectile)
	return projectile
