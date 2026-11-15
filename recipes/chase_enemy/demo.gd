extends Node3D
## Enemies chase the player and hurt on contact.

const SPAWN := Vector3(0, 1.1, 0)

@onready var _player: ThirdPersonCharacter = $Player
@onready var _health: Health = $Player/Health
@onready var _status: Label = %Status


func _ready() -> void:
	# The shared level has no navigation mesh of its own, so one is baked
	# here. In your own level, bake it in the editor instead.
	$NavigationRegion3D.bake_navigation_mesh(false)

	for enemy: ChaseEnemy in $Enemies.get_children():
		enemy.target_spotted.connect(func() -> void: _status.text = "%s spotted you." % enemy.name)
		enemy.target_lost.connect(func() -> void: _status.text = "%s lost you." % enemy.name)
	_health.died.connect(_on_player_died)


func _on_player_died() -> void:
	_status.text = "Caught. Back to the start."
	_player.position = SPAWN
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_health.reset()
