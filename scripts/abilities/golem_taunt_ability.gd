extends CompanionAbility

const CHARGE_SPEED  := 180.0
const CONTACT_DIST  := 10.0
const TAUNT_SECS    := 4.0
const BLOCK_DIST    := 20.0   # distancia del golem entre monstruo y jugador

var _taunt_t: float = 0.0


func _on_activate() -> void:
	_taunt_t = TAUNT_SECS
	FX.particles(get_parent().global_position, "shield")


func get_velocity(companion_pos: Vector2) -> Vector2:
	if not is_instance_valid(_target):
		cancel()
		return Vector2.ZERO

	var companion: Node = get_parent()
	var player: Node2D = companion.get("target") as Node2D

	# Calcula la posición de bloqueo: entre el monstruo y el jugador
	var block_pos := _target.global_position
	if player != null and is_instance_valid(player):
		var dir_to_player := (player.global_position - _target.global_position).normalized()
		block_pos = _target.global_position + dir_to_player * BLOCK_DIST

	var to_block := block_pos - companion_pos
	var dist     := to_block.length()

	if dist < CONTACT_DIST:
		# Ya está en posición — mantiene el bloqueo y cuenta el tiempo
		_taunt_t -= get_process_delta_time()
		if _taunt_t <= 0.0:
			hit_landed.emit(_target, 1.0)
			_active = false
			finished.emit()
		return Vector2.ZERO

	return to_block.normalized() * CHARGE_SPEED


func get_speed_scale() -> float:
	return 1.4
