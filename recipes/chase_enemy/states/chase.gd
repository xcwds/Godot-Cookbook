extends State
## Follows the target until it gets away or stays out of sight too long.

var _unseen_for := 0.0
var _in_reach := false


func _enter(_previous_state: StringName, _data: Dictionary) -> void:
	_unseen_for = 0.0
	_in_reach = false


func _physics_update(delta: float) -> void:
	var enemy: ChaseEnemy = owner
	var target := enemy.get_target()
	if enemy.can_see_target(enemy.lose_range):
		_unseen_for = 0.0
	else:
		_unseen_for += delta
	var too_far := enemy.distance_to_target() > enemy.lose_range
	if target == null or too_far or _unseen_for >= enemy.lose_sight_time:
		enemy.target_lost.emit()
		transition_to(&"Idle")
		return

	if enemy.distance_to_target() <= enemy.stop_distance:
		enemy.face(target.global_position - enemy.global_position, delta)
		enemy.stand(delta)
		if not _in_reach:
			_in_reach = true
			enemy.reached_target.emit()
	else:
		_in_reach = false
		enemy.move_toward_point(target.global_position, delta)
