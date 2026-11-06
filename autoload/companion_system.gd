extends Node
# Gestiona esencias, compañeros desbloqueados, equipo y cambios de activo.
# Autoridad del servidor en multijugador (MP: verificar is_multiplayer_authority antes de mutar).

signal companion_unlocked(comp_data: Resource)
signal team_changed
signal essence_gained(essence_id: String, current: int, required: int)

const TEAM_MAX      := 5
const KO_RECOVERY_T := 60.0
const SWITCH_CD_T   := 3.0
const LUCKY_CHANCE  := 0.02
const ESSENCE_RANGE := 200.0

var essences:  Dictionary = {}  # {essence_id: int}
var unlocked:  Array      = []  # [CompanionData]
var team:      Array      = []  # [CompanionData], slot 0 = activo
var ko_timers: Dictionary = {}  # {companion_name: float restante}

var _active_idx: int   = 0
var _switch_cd:  float = 0.0


func _process(delta: float) -> void:
	_switch_cd = maxf(0.0, _switch_cd - delta)
	var recovered: Array = []
	for cname: String in ko_timers:
		ko_timers[cname] = maxf(0.0, ko_timers[cname] - delta)
		if ko_timers[cname] <= 0.0:
			recovered.append(cname)
	for cname: String in recovered:
		ko_timers.erase(cname)


# ── Inicialización ────────────────────────────────────────────────────────────

func init_from_race(race_data: Resource) -> void:
	if race_data == null:
		return
	var initial = race_data.get("companion_data")
	if initial == null:
		return
	if not unlocked.has(initial):
		unlocked.append(initial)
	if not team.has(initial):
		team.insert(0, initial)
		if team.size() > TEAM_MAX:
			team.resize(TEAM_MAX)
	_active_idx = 0


# ── Consultas ─────────────────────────────────────────────────────────────────

func get_active_data() -> Resource:
	if team.is_empty():
		return null
	_active_idx = clampi(_active_idx, 0, team.size() - 1)
	return team[_active_idx] as Resource


func get_switch_cooldown() -> float:
	return _switch_cd


func is_companion_ko(comp_name: String) -> bool:
	return ko_timers.has(comp_name) and ko_timers[comp_name] > 0.0


func get_ko_remaining(comp_name: String) -> float:
	return ko_timers.get(comp_name, 0.0)


func get_essence_progress(essence_id: String, required: int) -> Dictionary:
	var current: int = int(essences.get(essence_id, 0))
	return {"current": current, "required": required,
			"ratio": 0.0 if required <= 0 else clampf(float(current) / float(required), 0.0, 1.0)}


# ── Muerte de monstruo ────────────────────────────────────────────────────────

func on_monster_killed(mon_data: Resource, world_pos: Vector2, player: Node2D) -> void:
	if mon_data == null:
		return
	var essence_id: String = str(mon_data.get("essence_id"))
	var comp_data = mon_data.get("companion_data")

	# 2 % de desbloqueo inmediato
	if comp_data != null and randf() < LUCKY_CHANCE:
		_unlock_companion(comp_data)

	if essence_id.is_empty():
		return

	# Solo dar esencias si el jugador está cerca
	if player == null or world_pos.distance_to(player.global_position) > ESSENCE_RANGE:
		return

	# Afinidad racial: ×2 esencias si la región coincide
	var mult: int = 1
	var race = GameState.selected_race
	if race != null:
		var race_region: String = str(race.get("region"))
		var mon_region:  String = str(mon_data.get("region"))
		if not race_region.is_empty() and race_region == mon_region:
			mult = 2

	var required: int = int(mon_data.get("essences_required"))
	var current:  int = int(essences.get(essence_id, 0)) + mult
	essences[essence_id] = current
	essence_gained.emit(essence_id, current, required)

	if comp_data != null and required > 0 and current >= required:
		_unlock_companion(comp_data)


func _unlock_companion(comp_data) -> void:
	if comp_data == null or unlocked.has(comp_data):
		return
	unlocked.append(comp_data)
	companion_unlocked.emit(comp_data)


# ── KO y cambio de compañero ──────────────────────────────────────────────────

func companion_ko(comp_name: String) -> void:
	if not comp_name.is_empty():
		ko_timers[comp_name] = KO_RECOVERY_T
	_auto_switch_away_from(comp_name)


func _auto_switch_away_from(bad_name: String) -> void:
	var original := _active_idx
	for _i: int in team.size():
		var next := (_active_idx + 1) % team.size()
		_active_idx = next
		var d = get_active_data()
		if d != null:
			var dname: String = str(d.get("companion_name"))
			if dname != bad_name and not is_companion_ko(dname):
				team_changed.emit()
				return
		if next == original:
			break
	# Todos KO o solo uno en el equipo
	_active_idx = original
	team_changed.emit()


func switch_next() -> bool:
	if _switch_cd > 0.0 or team.size() <= 1:
		return false
	var original := _active_idx
	for _i: int in team.size() - 1:
		_active_idx = (_active_idx + 1) % team.size()
		var d = get_active_data()
		if d != null and not is_companion_ko(str(d.get("companion_name"))):
			_switch_cd = SWITCH_CD_T
			team_changed.emit()
			return true
	_active_idx = original
	return false


func switch_prev() -> bool:
	if _switch_cd > 0.0 or team.size() <= 1:
		return false
	var original := _active_idx
	for _i: int in team.size() - 1:
		_active_idx = (_active_idx - 1 + team.size()) % team.size()
		var d = get_active_data()
		if d != null and not is_companion_ko(str(d.get("companion_name"))):
			_switch_cd = SWITCH_CD_T
			team_changed.emit()
			return true
	_active_idx = original
	return false


# ── Gestión del equipo ────────────────────────────────────────────────────────

func add_to_team(comp_data) -> bool:
	if comp_data == null:
		return false
	if team.size() >= TEAM_MAX or team.has(comp_data):
		return false
	if not unlocked.has(comp_data):
		return false
	team.append(comp_data)
	team_changed.emit()
	return true


func remove_from_team(idx: int) -> void:
	if idx <= 0 or idx >= team.size():
		return  # slot 0 es permanente
	team.remove_at(idx)
	_active_idx = clampi(_active_idx, 0, team.size() - 1)
	team_changed.emit()


func get_active_index() -> int:
	return _active_idx
