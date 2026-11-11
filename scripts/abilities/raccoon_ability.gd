extends CompanionAbility

const DASH_SPEED   := 250.0
const CONTACT_DIST := 7.0


func get_velocity(companion_pos: Vector2) -> Vector2:
	if not is_instance_valid(_target):
		cancel()
		return Vector2.ZERO
	var to_enemy := _target.global_position - companion_pos
	if to_enemy.length() < CONTACT_DIST:
		hit_landed.emit(_target, 1.0)
		_steal()
		_active = false
		finished.emit()
		return Vector2.ZERO
	return to_enemy.normalized() * DASH_SPEED


func get_speed_scale() -> float:
	return 1.8


func _steal() -> void:
	var companion: Node = get_parent()
	if companion == null:
		return
	var player: Node2D = companion.get("target") as Node2D
	if player == null or not is_instance_valid(player):
		return
	# Roba 1 moneda de oro del monstruo
	player.call("collect_item", "gold", 1)
	FX.damage_number(_target.global_position + Vector2(0.0, -16.0), 1, Color(1.0, 0.85, 0.0))
	SFX.play("coin")
