extends CompanionAbility

const CHASE_SPEED  := 220.0
const CONTACT_DIST := 7.0


func get_velocity(companion_pos: Vector2) -> Vector2:
	if not is_instance_valid(_target):
		cancel()
		return Vector2.ZERO
	var to_enemy := _target.global_position - companion_pos
	if to_enemy.length() < CONTACT_DIST:
		hit_landed.emit(_target, 1.0)
		_heal_player()
		_active = false
		finished.emit()
		return Vector2.ZERO
	return to_enemy.normalized() * CHASE_SPEED


func get_speed_scale() -> float:
	return 1.5


func _heal_player() -> void:
	var companion: Node = get_parent()
	if companion == null:
		return
	var player: Node2D = companion.get("target") as Node2D
	if player == null or not is_instance_valid(player):
		return
	var dmg: int = companion.call("_get_damage") if companion.has_method("_get_damage") else 2
	var heal := maxi(1, dmg / 2)
	if player.has_method("heal_hp"):
		player.call("heal_hp", heal)
	FX.damage_number(player.global_position + Vector2(0.0, -20.0), heal, Color(0.6, 0.2, 1.0))
	FX.particles(player.global_position, "heal")
