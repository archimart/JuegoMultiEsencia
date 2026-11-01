extends CompanionAbility

const CHARGE_SPEED      := 230.0
const BACK_ATTACK_MULT  := 2.0
const CONTACT_DIST      := 8.0


func get_velocity(companion_pos: Vector2) -> Vector2:
	if not is_instance_valid(_target):
		cancel()
		return Vector2.ZERO
	var to_enemy := _target.global_position - companion_pos
	if to_enemy.length() < CONTACT_DIST:
		var mult := _check_back_attack(companion_pos)
		hit_landed.emit(_target, mult)
		_active = false
		finished.emit()
		return Vector2.ZERO
	return to_enemy.normalized() * CHARGE_SPEED


func get_speed_scale() -> float:
	return 1.6


func _check_back_attack(wolf_pos: Vector2) -> float:
	# El compañero padre nos da acceso al jugador objetivo
	var companion: Node = get_parent()
	if companion == null:
		return 1.0
	var player: Node2D = companion.get("target") as Node2D
	if player == null or not is_instance_valid(_target):
		return 1.0

	# El monstruo mira hacia el jugador (dirección de persecución)
	var face_dir := (player.global_position - _target.global_position).normalized()
	# Si el lobo está en el lado opuesto al jugador → ataque por la espalda
	var to_wolf  := (wolf_pos - _target.global_position).normalized()
	return BACK_ATTACK_MULT if to_wolf.dot(face_dir) < -0.3 else 1.0
