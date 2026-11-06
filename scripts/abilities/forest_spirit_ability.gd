class_name ForestSpiritAbility
extends CompanionAbility

var _heal_timer: float = 6.0
var _shield_cd:  float = 0.0
var _companion          # nodo Companion padre (sin tipo para acceder a vars internas)


func _ready() -> void:
	_companion = get_parent()
	var data: CompanionData = _companion.data if _companion != null else null
	if data != null and data.heal_interval > 0.0:
		_heal_timer = data.heal_interval


func _process(delta: float) -> void:
	if _companion == null:
		return
	var player: Node2D = _companion.target
	if player == null or not is_instance_valid(player):
		return
	var data: CompanionData = _companion.data
	if data == null:
		return
	var level: int = _companion._level

	_heal_timer = maxf(0.0, _heal_timer - delta)
	if _heal_timer <= 0.0:
		_heal_timer = data.heal_interval
		_do_heal(player, data, level)

	_shield_cd = maxf(0.0, _shield_cd - delta)
	if _shield_cd <= 0.0 and not bool(player.get("_shielded")):
		var cur_hp: int = player.get("hp")
		var max_hp: int = player.get("max_hp")
		if max_hp > 0 and float(cur_hp) / float(max_hp) < data.shield_hp_threshold:
			_do_shield(player, data, level)


func activate(_enemy: Node2D) -> void:
	pass  # El espíritu no ataca; _active queda false → companion vuelve a FOLLOW en un frame


func _do_heal(player: Node2D, data: CompanionData, level: int) -> void:
	var cur_hp: int = player.get("hp")
	var max_hp: int = player.get("max_hp")
	if cur_hp >= max_hp:
		return
	var pct_arr := data.heal_pct_per_level
	var pct: float = pct_arr[mini(level, pct_arr.size() - 1)] if not pct_arr.is_empty() else 0.10
	var amount := maxi(1, int(float(max_hp) * pct))
	if player.has_method("heal_hp"):
		player.call("heal_hp", amount)
	FX.damage_number(player.global_position + Vector2(0.0, -26.0), amount, Color(0.25, 1.0, 0.35))
	FX.particles(player.global_position + Vector2(0.0, -8.0), "heal")
	SFX.play("spirit")


func _do_shield(player: Node2D, data: CompanionData, level: int) -> void:
	var cd_arr := data.shield_cooldown_per_level
	_shield_cd = cd_arr[mini(level, cd_arr.size() - 1)] if not cd_arr.is_empty() else 20.0
	if player.has_method("apply_shield"):
		player.call("apply_shield")
	SFX.play("spirit")
