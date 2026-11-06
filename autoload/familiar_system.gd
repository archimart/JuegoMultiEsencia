extends Node

signal egg_progress_changed(item_id: String, kills: int, needed: int)
signal egg_ready(item_id: String)
signal roster_changed
signal affection_changed(monster_id: String, level: int)

const MAX_FAMILIARS   := 5
const KILLS_TO_HATCH  := 10
const EGG_DROP_CHANCE := 0.15
const RECOVERY_TIME   := 60.0
const FAM_MAX_LEVEL   := 10
const FAM_XP_BASE     := 20

const FAMILIAR_ABILITIES: Dictionary = {
	"slime":    "Ralentiza",
	"bat":      "Ataque aéreo",
	"heart":    "Cura al jugador",
	"mushroom": "Nube de esporas",
	"racoon":   "Roba objetos",
	"scorpion": "Veneno",
	"skull":    "Maldición",
	"snake":    "Mordedura",
	"spider":   "Tela de araña",
	"spirit":   "Escudo mágico",
	"golem":    "Provocar",
}

var egg_kills:   Dictionary   = {}   # {item_id: int}
var _owned:      Array[String] = []  # monster_ids poseídos (hasta MAX_FAMILIARS)
var _familiars:  Array         = []  # nodos activos en el mundo (Node2D)
var _recovering: Dictionary   = {}  # {monster_id: float} tiempo restante
var _player:     Node2D       = null
var _recover_tick:   float      = 0.0
var _egg_rarities:   Dictionary = {}  # {monster_id → {rarity, is_shiny}}
var _owned_rarities: Dictionary = {}  # {monster_id → {rarity, is_shiny}}
var _hatching:       bool       = false
var _fam_xp:     Dictionary = {}  # {monster_id: int}
var _fam_levels: Dictionary = {}  # {monster_id: int}
var _affection:  Dictionary = {}  # {monster_id: int}
var _fam_names:  Dictionary = {}  # {monster_id: String}

var _egg_scene: PackedScene = null
var _fam_scene: PackedScene = null


func _ready() -> void:
	_egg_scene = load("res://scenes/egg.tscn")
	_fam_scene = load("res://scenes/familiar.tscn")


func _process(delta: float) -> void:
	if _recovering.is_empty():
		return
	var just_finished := false
	for mid in _recovering.keys():
		_recovering[mid] -= delta
		if _recovering[mid] <= 0.0:
			_recovering.erase(mid)
			just_finished = true
	if just_finished:
		roster_changed.emit()
		return
	_recover_tick += delta
	if _recover_tick >= 1.0:
		_recover_tick = 0.0
		roster_changed.emit()


func init_player(player: Node2D) -> void:
	_player = player


# ── Progreso de huevos ───────────────────────────────────────────────────────

func on_monster_killed(mon_data: Resource, _world_pos: Vector2, player: Node2D) -> void:
	if player == null:
		return
	var inv: Dictionary = player.get("inventory") if player.get("inventory") != null else {}
	for item_id: String in inv.keys():
		if not item_id.begins_with("egg_"):
			continue
		if int(inv.get(item_id, 0)) <= 0:
			continue
		var prev: int = int(egg_kills.get(item_id, 0))
		if prev >= KILLS_TO_HATCH:
			continue
		var cur: int = mini(prev + 1, KILLS_TO_HATCH)
		egg_kills[item_id] = cur
		egg_progress_changed.emit(item_id, cur, KILLS_TO_HATCH)
		if cur >= KILLS_TO_HATCH:
			egg_ready.emit(item_id)
			if player.has_signal("notice_requested"):
				player.notice_requested.emit("Huevo listo! [F] para eclosionar")
	for fid: String in get_familiar_monster_ids():
		give_fam_xp(fid, 2)


func try_drop_egg(mon_data: Resource, world_pos: Vector2, scene: Node) -> void:
	if mon_data == null or randf() > EGG_DROP_CHANCE:
		return
	var egg: Node2D = _egg_scene.instantiate()
	var mname: String = str(mon_data.get("essence_id"))
	if mname.is_empty():
		return
	var rar := _pick_rarity()
	_egg_rarities[mname] = rar
	egg.set("egg_id", "egg_" + mname)
	egg.set("rarity", rar.get("rarity", "common"))
	egg.set("is_shiny", rar.get("is_shiny", false))
	egg.global_position = world_pos + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
	scene.call_deferred("add_child", egg)


func _pick_rarity() -> Dictionary:
	var r := randf()
	var shiny := randf() < 0.01
	var rarity: String
	if r < 0.74:
		rarity = "common"
	elif r < 0.94:
		rarity = "rare"
	else:
		rarity = "epic"
	return {"rarity": rarity, "is_shiny": shiny}


func register_egg_rarity(monster_id: String, rar: String, shiny: bool) -> void:
	_egg_rarities[monster_id] = {"rarity": rar, "is_shiny": shiny}


func get_egg_rarity(monster_id: String) -> Dictionary:
	return _egg_rarities.get(monster_id, {"rarity": "common", "is_shiny": false})


func get_owned_rarity(monster_id: String) -> Dictionary:
	return _owned_rarities.get(monster_id, {"rarity": "common", "is_shiny": false})


# ── Eclosión (añade al roster, NO invoca automáticamente) ────────────────────

func try_hatch(player: Node2D) -> void:
	if _hatching:
		return
	if _owned.size() >= MAX_FAMILIARS:
		if player.has_signal("notice_requested"):
			player.notice_requested.emit("Familiar máximo alcanzado (max %d)" % MAX_FAMILIARS)
		return
	var inv: Dictionary = player.get("inventory") if player.get("inventory") != null else {}
	for item_id: String in inv.keys():
		if not item_id.begins_with("egg_"):
			continue
		if int(inv.get(item_id, 0)) <= 0:
			continue
		if int(egg_kills.get(item_id, 0)) < KILLS_TO_HATCH:
			continue
		_hatch(item_id, player)
		return
	if player.has_signal("notice_requested"):
		player.notice_requested.emit("No hay huevos listos")


func _hatch(item_id: String, player: Node2D) -> void:
	_hatching = true
	player.call("collect_item", item_id, -1)
	egg_kills.erase(item_id)
	var monster_id: String = item_id.substr(4)
	var rar: Dictionary = _egg_rarities.get(monster_id, {"rarity": "common", "is_shiny": false})
	_play_hatch_animation(player.global_position, player.get_tree().current_scene, monster_id, rar)


func _play_hatch_animation(world_pos: Vector2, scene: Node, monster_id: String, rar: Dictionary) -> void:
	var n := Node2D.new()
	n.global_position = world_pos + Vector2(0.0, -10.0)
	scene.add_child(n)

	var spr := Sprite2D.new()
	spr.texture = load("res://assets/Items/Treasure/GoldCoin.png")
	spr.scale   = Vector2(2.0, 2.4)
	spr.self_modulate = _rarity_node_color(rar)
	n.add_child(spr)

	var tw := n.create_tween()
	for _i in 4:
		tw.tween_property(spr, "position:x",  3.0, 0.05)
		tw.tween_property(spr, "position:x", -3.0, 0.05)
	tw.tween_property(spr, "position:x", 0.0, 0.03)
	tw.tween_property(spr, "scale", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func() -> void:
		FX.particles(world_pos, "punch")
		FX.particles(world_pos + Vector2(randf_range(-8.0, 8.0), -8.0), "slash")
		n.queue_free()
		_finish_hatch(monster_id, rar)
	)


func _finish_hatch(monster_id: String, rar: Dictionary) -> void:
	_owned_rarities[monster_id] = rar
	if not _owned.has(monster_id):
		_owned.append(monster_id)
	_hatching = false
	roster_changed.emit()
	if _player != null and _player.has_signal("notice_requested"):
		var prefix := ""
		match rar.get("rarity", "common"):
			"rare": prefix = "[RARO] "
			"epic": prefix = "[ÉPICO] "
		if rar.get("is_shiny", false):
			prefix = "[BRILLANTE] " + prefix
		_player.notice_requested.emit("%s%s se unió! [C]→Sacar" % [prefix, monster_id.capitalize()])


func _rarity_node_color(rar: Dictionary) -> Color:
	if rar.get("is_shiny", false):
		return Color(1.0, 0.95, 0.3)
	match rar.get("rarity", "common"):
		"rare": return Color(0.5, 0.75, 1.0)
		"epic": return Color(0.9, 0.5, 1.0)
	return Color(1.0, 0.95, 0.75)


# ── XP, Nivel, Cariño, Nombre ────────────────────────────────────────────────

func give_fam_xp(monster_id: String, amount: int) -> void:
	if not _owned.has(monster_id):
		return
	var level := get_fam_level(monster_id)
	if level >= FAM_MAX_LEVEL:
		return
	_fam_xp[monster_id] = int(_fam_xp.get(monster_id, 0)) + amount
	var needed := _xp_needed(level)
	while int(_fam_xp.get(monster_id, 0)) >= needed and level < FAM_MAX_LEVEL:
		_fam_xp[monster_id] = int(_fam_xp.get(monster_id, 0)) - needed
		level += 1
		_fam_levels[monster_id] = level
		var display := get_fam_name(monster_id)
		if display.is_empty():
			display = monster_id.capitalize()
		if _player != null and _player.has_signal("notice_requested"):
			_player.notice_requested.emit("%s subió a Nv.%d!" % [display, level])
		roster_changed.emit()
		needed = _xp_needed(level)


func _xp_needed(level: int) -> int:
	return level * FAM_XP_BASE


func get_fam_level(monster_id: String) -> int:
	return int(_fam_levels.get(monster_id, 1))


func get_fam_xp(monster_id: String) -> int:
	return int(_fam_xp.get(monster_id, 0))


func get_fam_xp_needed(monster_id: String) -> int:
	return _xp_needed(get_fam_level(monster_id))


func get_level_mult(monster_id: String) -> float:
	return 1.0 + float(get_fam_level(monster_id) - 1) * 0.02


func get_affection(monster_id: String) -> int:
	return int(_affection.get(monster_id, 0))


func get_affection_mult(monster_id: String) -> float:
	return 1.0 + float(get_affection(monster_id)) * 0.01


func get_fam_name(monster_id: String) -> String:
	return str(_fam_names.get(monster_id, ""))


func set_fam_name(monster_id: String, new_name: String) -> void:
	_fam_names[monster_id] = new_name.strip_edges()
	roster_changed.emit()


func pet_familiar(monster_id: String) -> void:
	if not _owned.has(monster_id):
		return
	var cur := int(_affection.get(monster_id, 0))
	if cur >= 10:
		if _player != null and _player.has_signal("notice_requested"):
			_player.notice_requested.emit("El cariño ya es máximo!")
		return
	_affection[monster_id] = cur + 1
	affection_changed.emit(monster_id, cur + 1)
	var display := get_fam_name(monster_id)
	if display.is_empty():
		display = monster_id.capitalize()
	if _player != null and _player.has_signal("notice_requested"):
		_player.notice_requested.emit("♥ %s te quiere!" % display)
	roster_changed.emit()


func get_familiar_ability(monster_id: String) -> String:
	return FAMILIAR_ABILITIES.get(monster_id, "")


# ── Invocar / despedir ───────────────────────────────────────────────────────

func summon(monster_id: String) -> void:
	if _player == null:
		return
	if is_summoned(monster_id):
		return
	if is_recovering(monster_id):
		if _player.has_signal("notice_requested"):
			_player.notice_requested.emit("Recuperándose: %.0fs restantes" % get_recovery_remaining(monster_id))
		return
	var fam: Node2D = _fam_scene.instantiate()
	_player.get_tree().current_scene.add_child(fam)
	fam.global_position = _player.global_position + Vector2(randf_range(-18.0, 18.0), 0.0)
	fam.set("monster_id", monster_id)
	_familiars.append(fam)
	var rar: Dictionary = _owned_rarities.get(monster_id, {"rarity": "common", "is_shiny": false})
	fam.call("setup", _player, monster_id,
			rar.get("rarity", "common"), rar.get("is_shiny", false))
	roster_changed.emit()


func dismiss(monster_id: String) -> void:
	for f in _familiars:
		if is_instance_valid(f) and str(f.get("monster_id")) == monster_id:
			f.queue_free()
	_clean_dead()
	roster_changed.emit()


# ── Consultas ────────────────────────────────────────────────────────────────

func is_summoned(monster_id: String) -> bool:
	_clean_dead()
	for f in _familiars:
		if is_instance_valid(f) and str(f.get("monster_id")) == monster_id:
			return true
	return false


func get_owned_ids() -> Array[String]:
	return _owned.duplicate()


func get_active_count() -> int:
	_clean_dead()
	return _familiars.size()


func get_familiar_monster_ids() -> Array[String]:
	_clean_dead()
	var ids: Array[String] = []
	for f in _familiars:
		if is_instance_valid(f):
			ids.append(str(f.get("monster_id")))
	return ids


func familiar_died(monster_id: String, fam_node: Node = null) -> void:
	if fam_node != null:
		_familiars.erase(fam_node)
	_recovering[monster_id] = RECOVERY_TIME
	if _player != null and _player.has_signal("notice_requested"):
		_player.notice_requested.emit("%s caído — recuperándose en 60s" % monster_id.capitalize())
	roster_changed.emit()


func is_recovering(monster_id: String) -> bool:
	return _recovering.has(monster_id)


func get_recovery_remaining(monster_id: String) -> float:
	return float(_recovering.get(monster_id, 0.0))


func instant_recover_all() -> void:
	if _recovering.is_empty():
		return
	_recovering.clear()
	roster_changed.emit()


func remove_familiar(fam: Node) -> void:
	_familiars.erase(fam)
	roster_changed.emit()


func _clean_dead() -> void:
	_familiars = _familiars.filter(func(f) -> bool: return is_instance_valid(f))
