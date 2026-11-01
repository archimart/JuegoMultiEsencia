extends CompanionAbility

const DIVE_SPEED := 270.0


func get_velocity(companion_pos: Vector2) -> Vector2:
	if not is_instance_valid(_target):
		cancel()
		return Vector2.ZERO
	var to_enemy := _target.global_position - companion_pos
	if to_enemy.length() < 6.0:
		hit_landed.emit(_target, 1.0)
		_active = false
		finished.emit()
		return Vector2.ZERO
	return to_enemy.normalized() * DIVE_SPEED


func get_speed_scale() -> float:
	return 1.8
