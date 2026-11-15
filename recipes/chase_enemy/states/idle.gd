extends State
## Walks back to its post and waits there, watching for the target.


func _physics_update(delta: float) -> void:
	var enemy: ChaseEnemy = owner
	if enemy.can_see_target(enemy.detection_range):
		enemy.target_spotted.emit()
		transition_to(&"Chase")
		return
	enemy.move_toward_point(enemy.home, delta)
