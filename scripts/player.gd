extends CharacterBody2D

signal inventory_changed
signal notice_requested(text: String)
signal health_changed
signal hurt_by(attacker: Node)  # emitida por monster.gd cuando nos golpea
signal xp_changed(current_xp: int, xp_to_next: int)
signal level_changed(new_level: int)
signal weapon_changed(weapon_id: String)
signal skill_cooldown_changed(slot: int, remaining: float, max_cd: float)
signal blocking_changed(active: bool)
signal class_changed(class_data: Resource)
signal mana_changed(current: int, total: int)
signal attack_hit(target: Node2D)
signal died(lost_items: Dictionary)

const DEFAULT_WALK_TEX   := "res://assets/Actor/Character/Hunter/SeparateAnim/Walk.png"
const DEFAULT_IDLE_TEX   := "res://assets/Actor/Character/Hunter/SeparateAnim/Idle.png"
const SHOOT_COOLDOWN     := 0.4
const INVULNERABILITY_T  := 1.5
var respawn_pos: Vector2 = Vector2(1584.0, 1584.0)

const XP_PER_LEVEL: Array[int] = [50, 120, 250, 450, 700, 1000, 1400, 1900, 2500]

# ── Puñetazo sin arma ────────────────────────────────────────────────────────
const FIST_DAMAGE:    int   = 4
const FIST_RANGE:     float = 22.0
const FIST_COOLDOWN:  float = 0.30
const FIST_KNOCKBACK: float = 35.0
const FIST_ARC:       float = 90.0

# ── Habilidades del Guerrero ──────────────────────────────────────────────────
const SKILL_SPIN_CD:      float = 8.0
const SKILL_CHARGE_CD:    float = 15.0
const SKILL_SPIN_LEVEL:   int   = 1
const SKILL_BLOCK_LEVEL:  int   = 3
const SKILL_CHARGE_LEVEL: int   = 5
const CHARGE_SPEED_MULT:  float = 4.0
const CHARGE_DURATION:    float = 0.40
const CHARGE_PUSH_RANGE:  float = 18.0
const CHARGE_PUSH_DMG:    int   = 8
const WEAPON_IDS:         Array[String] = ["sword", "staff", "iron_sword"]

# ── Habilidades del Mago ──────────────────────────────────────────────────────
const SKILL_FIREBALL_CD:       float = 8.0
const SKILL_MAGIC_SHIELD_CD:   float = 18.0
const SKILL_ICE_RAY_CD:        float = 12.0
const SKILL_FIREBALL_LEVEL:    int   = 1
const SKILL_MAGIC_SHIELD_LEVEL: int  = 3
const SKILL_ICE_RAY_LEVEL:     int   = 5
const FIREBALL_SPLASH:         float = 55.0
const MAGE_MAX_MANA:           int   = 100
const MANA_REGEN:              float = 8.0

var max_hp: int   = 30     # público para que hud.gd lo lea
var _speed: float = 80.0
var _walk_tex:        String = DEFAULT_WALK_TEX
var _idle_tex:        String = DEFAULT_IDLE_TEX
var _sprite_dir_path: String = ""  # carpeta base para walk animations
var _sprite_idle_path: String = "" # carpeta para idle frames (puede ser variante)

var xp:           int   = 0
var level:        int   = 1
var _damage_mult: float = 1.0
var _class_data         = null  # ClassData o null
var _base_max_hp: int   = 30    # HP de raza antes de multiplicador de clase
var _base_speed:  float = 80.0  # velocidad de raza antes de multiplicador

var equipped_weapon             = null   # WeaponData o null
var _equipped_weapon_id: String = ""
var _melee_cd:   float          = 0.0
var _skill_cds:  Array[float]   = [0.0, 0.0, 0.0]
var _blocking:   bool           = false
var _charging:   bool           = false
var _charge_t:   float          = 0.0
var _charge_dir: Vector2        = Vector2.ZERO

var _race_modulate: Color = Color.WHITE

var mana:                int   = 0
var max_mana:            int   = 0
var _mana_accum:         float = 0.0
var _magic_shield_active: bool  = false
var _magic_shield_t:     float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_dir:        Vector2    = Vector2.DOWN
var _shoot_cooldown: float      = 0.0
var _inv_t:          float      = 0.0   # tiempo de invulnerabilidad restante
var inventory:       Dictionary = {}
var hp:              int        = 30
var in_safe_zone:    bool       = false
var _shielded:       bool       = false
var input_blocked:   bool       = false

var _arrow_scene:      PackedScene = preload("res://scenes/arrow.tscn")
var _magic_bolt_scene: PackedScene = preload("res://scenes/magic_bolt.tscn")
var _bag_scene:        PackedScene = preload("res://scenes/loot_bag.tscn")
var _dir_anim    := DirectionAnimator.new()


func setup_race(race: RaceData) -> void:
	max_hp      = race.max_hp
	hp          = race.max_hp
	_base_max_hp = race.max_hp
	_base_speed  = race.speed
	_speed      = race.speed
	_walk_tex = race.walk_tex_path if not race.walk_tex_path.is_empty() else DEFAULT_WALK_TEX
	_idle_tex = race.idle_tex_path if not race.idle_tex_path.is_empty() else DEFAULT_IDLE_TEX
	var gender := GameState.selected_gender
	if gender == "m" and not race.sprite_dir_path_m.is_empty():
		_sprite_dir_path = race.sprite_dir_path_m
	elif not race.sprite_dir_path_f.is_empty():
		_sprite_dir_path = race.sprite_dir_path_f
	else:
		_sprite_dir_path = ""
	# Variante de sprite (carpeta de idle) — puede diferir de walk si es una variante pre-coloreada
	var variant := GameState.selected_sprite_variant
	_sprite_idle_path = variant if not variant.is_empty() else _sprite_dir_path
	_build_frames()
	_race_modulate = Color.WHITE
	_sprite.self_modulate = Color.WHITE
	_sprite.material = null
	health_changed.emit()


func setup_class(cd: Resource) -> void:
	revert_class()
	_class_data  = cd
	if cd == null:
		return
	max_hp       = int(float(_base_max_hp) * float(cd.get("hp_mult")))
	hp           = mini(hp, max_hp)
	_speed       = _base_speed * float(cd.get("speed_mult"))
	_damage_mult = float(cd.get("damage_mult"))
	var wid: String = str(cd.get("weapon_id"))
	match wid:
		"bow":
			inventory["bow"]    = 1
			inventory["arrows"] = maxi(inventory.get("arrows", 0), 20)
		"sword":
			inventory["sword"] = 1
			_auto_equip("sword")
		"staff":
			inventory["staff"] = 1
			_auto_equip("staff")
			max_mana = MAGE_MAX_MANA
			mana     = MAGE_MAX_MANA
			mana_changed.emit(mana, max_mana)
	inventory_changed.emit()
	health_changed.emit()
	class_changed.emit(cd)


func revert_class() -> void:
	if _class_data == null:
		return
	max_hp       = _base_max_hp
	hp           = mini(hp, max_hp)
	_speed       = _base_speed
	_damage_mult = 1.0
	_class_data  = null
	if not _equipped_weapon_id.is_empty():
		_equipped_weapon_id = ""
		equipped_weapon     = null
		weapon_changed.emit("")
	max_mana             = 0
	mana                 = 0
	_mana_accum          = 0.0
	_magic_shield_active = false
	_magic_shield_t      = 0.0
	_sprite.self_modulate = _race_modulate
	mana_changed.emit(0, 0)


# ── XP y niveles ──────────────────────────────────────────────────────────────

func add_xp(amount: int) -> void:
	if level > XP_PER_LEVEL.size():
		return
	xp += amount
	_tick_level_up()


func _tick_level_up() -> void:
	while true:
		var needed := _get_xp_to_next()
		if needed <= 0 or xp < needed:
			break
		xp    -= needed
		level += 1
		_on_level_up()
	xp_changed.emit(xp, _get_xp_to_next())


func _get_xp_to_next() -> int:
	var idx := level - 1
	if idx >= XP_PER_LEVEL.size():
		return 0
	return XP_PER_LEVEL[idx]


func _on_level_up() -> void:
	level_changed.emit(level)
	notice_requested.emit("¡Subiste al nivel %d!" % level)
	FX.camera_shake(3.0, 0.2)
	SFX.play("coin")
	_sprite.self_modulate = Color(3.0, 2.5, 0.5)
	var tw := create_tween()
	tw.tween_property(_sprite, "self_modulate", _race_modulate, 0.7)


func _ready() -> void:
	add_to_group("player")
	_build_frames()
	_reg_skill_actions()
	FamiliarSystem.init_player(self)


func _physics_process(delta: float) -> void:
	# Cooldowns
	_melee_cd       = maxf(0.0, _melee_cd - delta)
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
	for i: int in 3:
		if _skill_cds[i] > 0.0:
			_skill_cds[i] = maxf(0.0, _skill_cds[i] - delta)
			skill_cooldown_changed.emit(i, _skill_cds[i], _skill_max_cd(i))

	# Regenerar maná
	if max_mana > 0 and mana < max_mana:
		_mana_accum += MANA_REGEN * delta
		if _mana_accum >= 1.0:
			var gain := int(_mana_accum)
			_mana_accum -= float(gain)
			mana = mini(mana + gain, max_mana)
			mana_changed.emit(mana, max_mana)

	# Escudo mágico (temporización)
	if _magic_shield_active:
		_magic_shield_t -= delta
		if _magic_shield_t <= 0.0:
			_magic_shield_active = false
			_sprite.self_modulate = _race_modulate
			notice_requested.emit("Escudo mágico expiró")
		else:
			_sprite.self_modulate = Color(0.5, 0.75, 2.5)

	# Cancelar bloqueo si se soltó la tecla o no cumple requisitos
	if _blocking and (not Input.is_action_pressed("skill_2") \
			or equipped_weapon == null or level < SKILL_BLOCK_LEVEL):
		_skill_block_end()

	# Carga (override de movimiento)
	if _charging:
		_charge_t = maxf(0.0, _charge_t - delta)
		velocity  = _charge_dir * _speed * CHARGE_SPEED_MULT
		move_and_slide()
		_check_charge_push()
		_update_anim(true)
		if _charge_t <= 0.0:
			_end_charge()
		return

	if input_blocked:
		velocity = Vector2.ZERO
		_update_anim(false)
		return

	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	var speed_factor := 0.5 if _blocking else 1.0
	velocity = input.normalized() * _speed * speed_factor if input != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

	if input != Vector2.ZERO:
		last_dir = input.normalized()

	# Invulnerabilidad y parpadeo
	if _inv_t > 0.0:
		_inv_t -= delta
		# Parpadeo: ciclos de 0.16 s; mitad opaco, mitad transparente
		_sprite.modulate.a = 0.25 if fmod(_inv_t, 0.16) < 0.08 else 1.0
	else:
		_sprite.modulate.a = 1.0

	_update_anim(input != Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
		return

	if event is InputEventKey and event.keycode == KEY_F and event.pressed:
		FamiliarSystem.try_hatch(self)
		return

	if OS.is_debug_build() and event is InputEventKey \
			and event.keycode == KEY_F1 and event.pressed:
		collect_item("wood", 20)
		collect_item("arrows", 20)
		collect_item("mineral", 10)
		collect_item("iron_ingot", 5)
		if inventory.get("bow", 0) == 0:
			collect_item("bow", 1)
		if inventory.get("pickaxe", 0) == 0:
			collect_item("pickaxe", 1)
		return

	if event is InputEventKey and event.keycode == KEY_H and event.pressed:
		_use_health_potion()
		return

	# Habilidades del Guerrero (teclas 1-3)
	if _is_warrior():
		if event.is_action_pressed("skill_1"):
			_skill_spin()
			return
		if event.is_action_pressed("skill_2"):
			_skill_block_start()
			return
		if event.is_action_released("skill_2"):
			_skill_block_end()
			return
		if event.is_action_pressed("skill_3"):
			_skill_charge()
			return

	# Habilidades del Mago (teclas 1-3)
	if _is_mage():
		if event.is_action_pressed("skill_1"):
			_skill_fireball()
			return
		if event.is_action_pressed("skill_2"):
			_skill_magic_shield()
			return
		if event.is_action_pressed("skill_3"):
			_skill_ice_ray()
			return

	if not event.is_action_pressed("shoot"):
		return

	# Mago: bolt mágico
	if _is_mage():
		_attack_magic()
		return

	# Arquero: disparar flechas
	if _class_data != null and str(_class_data.get("weapon_id")) == "bow":
		if inventory.get("bow", 0) <= 0:
			return
		if inventory.get("arrows", 0) <= 0:
			notice_requested.emit("Sin flechas")
			return
		if _shoot_cooldown > 0.0:
			return
		_shoot()
		return

	# Sin clase o Guerrero: cuerpo a cuerpo
	_attack_melee()


func _shoot() -> void:
	var dir := (get_global_mouse_position() - global_position).normalized()
	last_dir = dir

	inventory["arrows"] = inventory.get("arrows", 0) - 1
	if inventory["arrows"] <= 0:
		inventory.erase("arrows")
	inventory_changed.emit()

	var arrow: Node2D = _arrow_scene.instantiate()
	arrow.global_position = global_position + Vector2(0.0, -8.0) + dir * 20.0
	arrow.direction = dir
	get_tree().current_scene.add_child(arrow)

	SFX.play("shoot")
	_shoot_cooldown = SHOOT_COOLDOWN
	_signal_closest_target(dir, 350.0)


func _signal_closest_target(dir: Vector2, max_range: float) -> void:
	var best: Node2D = null
	var best_dist  := max_range
	for m: Node in get_tree().get_nodes_in_group("monster"):
		if not m is Node2D:
			continue
		var diff: Vector2 = (m as Node2D).global_position - global_position
		var dist := diff.length()
		if dist > max_range or dir.dot(diff.normalized()) < 0.6:
			continue
		if dist < best_dist:
			best_dist = dist
			best = m as Node2D
	if best != null:
		attack_hit.emit(best)


func collect_item(item: String, amount: int) -> void:
	inventory[item] = inventory.get(item, 0) + amount
	inventory_changed.emit()


func heal_hp(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	health_changed.emit()


func _use_health_potion() -> void:
	if inventory.get("health_potion", 0) <= 0:
		notice_requested.emit("No tienes pociones de vida")
		return
	if hp >= max_hp:
		notice_requested.emit("Ya tienes la vida al máximo")
		return
	inventory["health_potion"] -= 1
	if inventory["health_potion"] <= 0:
		inventory.erase("health_potion")
	heal_hp(20)
	FX.particles(global_position + Vector2(0, -12), "heal")
	SFX.play("spirit")
	notice_requested.emit("Poción de vida usada (+20 HP)")
	inventory_changed.emit()


func apply_shield() -> void:
	_shielded = true
	_sprite.self_modulate = Color(0.5, 0.9, 2.5)
	var tw := create_tween()
	tw.tween_property(_sprite, "self_modulate", Color(0.75, 0.9, 1.5), 0.3)
	FX.particles(global_position, "shield")


func take_hit(damage: int) -> void:
	if _inv_t > 0.0:
		return
	if _magic_shield_active:
		FX.particles(global_position, "shield")
		_sprite.self_modulate = Color(0.5, 0.75, 2.5)
		_inv_t = 0.4
		health_changed.emit()
		return
	if _shielded:
		_shielded = false
		_sprite.self_modulate = Color(2.5, 2.5, 5.0)
		var tw := create_tween()
		tw.tween_property(_sprite, "self_modulate", _race_modulate, 0.25)
		_inv_t = 0.5
		health_changed.emit()
		FX.particles(global_position, "shield")
		SFX.play("hit_monster")
		return
	var actual_dmg := damage
	if _blocking:
		actual_dmg = maxi(1, int(float(damage) * 0.30))
		FX.particles(global_position, "shield")
	hp    = maxi(0, hp - actual_dmg)
	_inv_t = INVULNERABILITY_T
	health_changed.emit()
	_sprite.self_modulate = Color(4.0, 4.0, 4.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "self_modulate", _race_modulate, 0.12)
	FX.camera_shake(4.0, 0.18)
	FX.damage_number(global_position + Vector2(0.0, -20.0), actual_dmg, Color(1.0, 0.35, 0.35))
	SFX.play("hit_player")
	if hp <= 0:
		_respawn()


func _respawn() -> void:
	var lost: Dictionary = inventory.duplicate()
	if not inventory.is_empty():
		var bag: Node2D = _bag_scene.instantiate()
		bag.position = global_position
		bag.set("contents", inventory.duplicate())
		get_tree().current_scene.add_child(bag)
	inventory.clear()
	inventory_changed.emit()
	input_blocked = true
	SFX.play("die_player")
	died.emit(lost)


func do_respawn() -> void:
	hp = max_hp
	global_position = respawn_pos
	_inv_t = INVULNERABILITY_T * 2.0
	input_blocked = false
	health_changed.emit()
	notice_requested.emit("Renaciste  —  tu bolsa está en el punto de caída")


func _update_anim(moving: bool) -> void:
	var prefix := "walk_" if moving else "idle_"
	if moving:
		_dir_anim.update_velocity(last_dir * _speed)
	var anim := prefix + _dir_anim.get_dir()
	if _sprite.animation != anim:
		_sprite.play(anim)


func _build_frames() -> void:
	if not _sprite_dir_path.is_empty():
		_build_directional_frames()
		return
	_sprite.position = Vector2(0.0, -8.0)
	var frames := DirectionAnimator.build_4dir_frames(load(_walk_tex), 16, 4, 8.0, "walk")
	DirectionAnimator.build_4dir_frames(load(_idle_tex), 16, 1, 1.0, "idle", frames)
	_sprite.sprite_frames = frames
	_sprite.play("idle_down")


func _build_directional_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var walk_base := _sprite_dir_path   # siempre el original (tiene animaciones de walk)
	var idle_base := _sprite_idle_path  # puede ser variante pre-coloreada
	var dir_map := {"down": "south", "up": "north", "left": "west", "right": "east"}
	for dir: String in ["down", "up", "left", "right"]:
		var dname: String = dir_map[dir]

		# Walk: usa la variante si tiene sus propios frames, si no el original
		var walk_anim := "walk_" + dir
		frames.add_animation(walk_anim)
		frames.set_animation_speed(walk_anim, 8.0)
		frames.set_animation_loop(walk_anim, true)
		var walk_sub := _find_walk_sub(idle_base, dname) if idle_base != walk_base else ""
		for i: int in 8:
			var path: String
			if not walk_sub.is_empty():
				path = walk_sub + "/frame_%03d.png" % i
			else:
				path = walk_base + "/Idle/animations/Walking/" + dname + "/frame_%03d.png" % i
			frames.add_frame(walk_anim, load(path))

		# Idle: busca primero en la variante, después en el original
		var idle_anim := "idle_" + dir
		frames.add_animation(idle_anim)
		frames.set_animation_speed(idle_anim, 1.0)
		frames.set_animation_loop(idle_anim, false)
		var idle_path := _find_idle_frame_path(idle_base, dname)
		if idle_path.is_empty():
			idle_path = _find_idle_frame_path(walk_base, dname)
		frames.add_frame(idle_anim, load(idle_path))

	_sprite.sprite_frames = frames
	_sprite.position = Vector2(0.0, -13.0)
	_sprite.play("idle_down")


func _find_idle_frame_path(base: String, dname: String) -> String:
	var dir := DirAccess.open(base)
	if dir:
		dir.list_dir_begin()
		var sub := dir.get_next()
		while not sub.is_empty():
			if dir.current_is_dir() and not sub.begins_with("."):
				var p := base + "/" + sub + "/rotations/" + dname + ".png"
				if ResourceLoader.exists(p):
					return p
			sub = dir.get_next()
	return ""


func _find_walk_sub(base: String, dname: String) -> String:
	# Devuelve la ruta completa al directorio de frames para 'dname', o "" si no existe.
	var dir := DirAccess.open(base)
	if dir:
		dir.list_dir_begin()
		var sub := dir.get_next()
		while not sub.is_empty():
			if dir.current_is_dir() and not sub.begins_with("."):
				# Acepta tanto "walking" como "Walking"
				for suffix: String in ["/animations/walking/", "/animations/Walking/"]:
					var p := base + "/" + sub + suffix + dname
					if DirAccess.dir_exists_absolute(p):
						return p
			sub = dir.get_next()
	return ""


# ── Equipamiento ──────────────────────────────────────────────────────────────

func equip_item(item_id: String) -> void:
	if item_id not in WEAPON_IDS:
		return
	if _equipped_weapon_id == item_id:
		_equipped_weapon_id = ""
		equipped_weapon     = null
		weapon_changed.emit("")
		notice_requested.emit("Desequipado")
		return
	var path := "res://resources/weapon_%s.tres" % item_id
	if not ResourceLoader.exists(path):
		return
	_equipped_weapon_id = item_id
	equipped_weapon     = load(path)
	weapon_changed.emit(item_id)
	notice_requested.emit("Equipado: %s" % str(equipped_weapon.get("display_name")))


func _auto_equip(item_id: String) -> void:
	var path := "res://resources/weapon_%s.tres" % item_id
	if ResourceLoader.exists(path):
		_equipped_weapon_id = item_id
		equipped_weapon     = load(path)
		weapon_changed.emit(item_id)


# ── Combate cuerpo a cuerpo ───────────────────────────────────────────────────

func _is_warrior() -> bool:
	if _class_data == null:
		return false
	return str(_class_data.get("class_label")) == "Guerrero"


func _attack_melee() -> void:
	if _melee_cd > 0.0 or _charging:
		return
	var mouse_dir := get_global_mouse_position() - global_position
	if mouse_dir.length() > 0.1:
		last_dir = mouse_dir.normalized()
	if equipped_weapon != null:
		_do_melee(
			int(equipped_weapon.get("damage")),
			float(equipped_weapon.get("range_px")),
			float(equipped_weapon.get("arc_deg")),
			float(equipped_weapon.get("knockback")),
			"slash"
		)
		_melee_cd = float(equipped_weapon.get("cooldown"))
	else:
		_do_melee(FIST_DAMAGE, FIST_RANGE, FIST_ARC, FIST_KNOCKBACK, "punch")
		_melee_cd = FIST_COOLDOWN


func _do_melee(dmg: int, range_px: float, arc_deg: float, _kb: float, fx_type: String) -> void:
	var hit_any := false
	for m: Node in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m) or not m is Node2D:
			continue
		var diff: Vector2 = (m as Node2D).global_position - global_position
		var dist := diff.length()
		if dist > range_px or dist < 0.5:
			continue
		if arc_deg < 360.0:
			var ang := absf(last_dir.angle_to(diff.normalized()))
			if ang > deg_to_rad(arc_deg * 0.5):
				continue
		if m.has_method("take_damage"):
			m.call("take_damage", int(float(dmg) * _damage_mult), global_position)
			attack_hit.emit(m as Node2D)
		hit_any = true
	FX.particles(global_position + last_dir * range_px * 0.65, fx_type)
	if hit_any:
		FX.hit_stop(0.04)
		FX.camera_shake(2.5, 0.12)
		SFX.play("hit_monster")


# ── Habilidades del Guerrero ──────────────────────────────────────────────────

func _skill_max_cd(slot: int) -> float:
	if _is_mage():
		match slot:
			0: return SKILL_FIREBALL_CD
			1: return SKILL_MAGIC_SHIELD_CD
			2: return SKILL_ICE_RAY_CD
		return 1.0
	match slot:
		0: return SKILL_SPIN_CD
		2: return SKILL_CHARGE_CD
	return 1.0


func _skill_spin() -> void:
	if level < SKILL_SPIN_LEVEL:
		notice_requested.emit("Torbellino disponible en Nv.%d" % SKILL_SPIN_LEVEL)
		return
	if _skill_cds[0] > 0.0:
		notice_requested.emit("Torbellino: %.0fs" % _skill_cds[0])
		return
	var spin_dmg: int
	var spin_range: float
	if equipped_weapon != null:
		spin_dmg   = maxi(1, int(float(int(equipped_weapon.get("damage"))) * 1.5 * _damage_mult))
		spin_range = float(equipped_weapon.get("range_px")) * 1.2
	else:
		spin_dmg   = maxi(1, int(float(FIST_DAMAGE) * 1.5 * _damage_mult))
		spin_range = FIST_RANGE * 1.2
	_do_melee(spin_dmg, spin_range, 360.0, 80.0, "slash")
	_skill_cds[0] = SKILL_SPIN_CD
	skill_cooldown_changed.emit(0, SKILL_SPIN_CD, SKILL_SPIN_CD)
	_sprite.self_modulate = Color(2.0, 1.8, 0.5)
	var tw := create_tween()
	tw.tween_property(_sprite, "self_modulate", _race_modulate, 0.45)


func _skill_block_start() -> void:
	if level < SKILL_BLOCK_LEVEL:
		notice_requested.emit("Bloqueo disponible en Nv.%d" % SKILL_BLOCK_LEVEL)
		return
	if equipped_weapon == null:
		notice_requested.emit("Necesitas espada para Bloqueo")
		return
	_blocking = true
	blocking_changed.emit(true)
	_sprite.self_modulate = Color(0.5, 0.85, 2.2)
	FX.particles(global_position, "shield")


func _skill_block_end() -> void:
	if not _blocking:
		return
	_blocking = false
	blocking_changed.emit(false)
	_sprite.self_modulate = _race_modulate


func _skill_charge() -> void:
	if level < SKILL_CHARGE_LEVEL:
		notice_requested.emit("Carga disponible en Nv.%d" % SKILL_CHARGE_LEVEL)
		return
	if _skill_cds[2] > 0.0:
		notice_requested.emit("Carga: %.0fs" % _skill_cds[2])
		return
	if equipped_weapon == null:
		notice_requested.emit("Necesitas espada para Carga")
		return
	_charge_dir = get_global_mouse_position() - global_position
	if _charge_dir.length() > 0.1:
		_charge_dir = _charge_dir.normalized()
	else:
		_charge_dir = last_dir
	last_dir     = _charge_dir
	_charging    = true
	_charge_t    = CHARGE_DURATION
	_skill_cds[2] = SKILL_CHARGE_CD
	skill_cooldown_changed.emit(2, SKILL_CHARGE_CD, SKILL_CHARGE_CD)
	_inv_t = CHARGE_DURATION + 0.15
	FX.particles(global_position, "shield")
	_sprite.self_modulate = Color(2.2, 1.6, 0.4)


func _check_charge_push() -> void:
	for m: Node in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m) or not m is Node2D:
			continue
		var diff := (m as Node2D).global_position - global_position
		if diff.length() > CHARGE_PUSH_RANGE:
			continue
		if m.has_method("take_damage"):
			m.call("take_damage", int(float(CHARGE_PUSH_DMG) * _damage_mult),
				   global_position - _charge_dir * 30.0)


func _end_charge() -> void:
	_charging = false
	_sprite.self_modulate = _race_modulate
	FX.camera_shake(1.5, 0.08)


# ── Registro de acciones de habilidades ──────────────────────────────────────

func _reg_skill_actions() -> void:
	var keys: Array[int] = [KEY_1, KEY_2, KEY_3]
	for i: int in 3:
		var action := "skill_%d" % (i + 1)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.keycode = keys[i]
			InputMap.action_add_event(action, ev)


# ── Combate del Mago ──────────────────────────────────────────────────────────

func _is_mage() -> bool:
	if _class_data == null:
		return false
	return str(_class_data.get("class_label")) == "Mago"


func _attack_magic() -> void:
	if _melee_cd > 0.0:
		return
	if equipped_weapon == null:
		_spawn_magic_bolt(4, 250.0, 160.0, Color(0.85, 0.7, 1.1))
		_melee_cd = 0.5
		return
	var bolt_dmg:  int   = int(equipped_weapon.get("damage"))
	var bolt_cd:   float = float(equipped_weapon.get("cooldown"))
	var bolt_rng:  float = float(equipped_weapon.get("range_px"))
	var bolt_cost: int   = int(equipped_weapon.get("mana_cost"))
	if bolt_cost > 0 and mana < bolt_cost:
		notice_requested.emit("Sin maná (%d requerido)" % bolt_cost)
		return
	if bolt_cost > 0:
		mana -= bolt_cost
		mana_changed.emit(mana, max_mana)
	_spawn_magic_bolt(bolt_dmg, 180.0, bolt_rng, Color(0.6, 0.3, 1.3))
	_melee_cd = bolt_cd


func _spawn_magic_bolt(dmg: int, spd: float, rng: float, col: Color,
					   splash: float = 0.0, trail: String = "",
					   impact: String = "", is_piercing: bool = false,
					   slow_dur: float = 0.0) -> void:
	var dir := (get_global_mouse_position() - global_position)
	if dir.length() > 0.1:
		dir = dir.normalized()
	else:
		dir = last_dir
	last_dir = dir
	var bolt: Node2D = _magic_bolt_scene.instantiate()
	bolt.set("direction",     dir)
	bolt.set("damage",        int(float(dmg) * _damage_mult))
	bolt.set("speed",         spd)
	bolt.set("max_range",     rng)
	bolt.set("bolt_color",    col)
	bolt.set("splash_radius", splash)
	bolt.set("trail_type",    trail)
	bolt.set("impact_fx",     impact)
	bolt.set("piercing",      is_piercing)
	bolt.set("slow_duration", slow_dur)
	bolt.global_position = global_position + Vector2(0.0, -8.0) + dir * 12.0
	get_tree().current_scene.add_child(bolt)
	SFX.play("shoot")
	_signal_closest_target(dir, rng)


func _skill_fireball() -> void:
	if level < SKILL_FIREBALL_LEVEL:
		notice_requested.emit("Bola de fuego en Nv.%d" % SKILL_FIREBALL_LEVEL)
		return
	if _skill_cds[0] > 0.0:
		notice_requested.emit("Bola de fuego: %.0fs" % _skill_cds[0])
		return
	const FIREBALL_MANA := 20
	if mana < FIREBALL_MANA:
		notice_requested.emit("Sin maná (%d necesario)" % FIREBALL_MANA)
		return
	var fb_dmg: int = 18
	if equipped_weapon != null:
		fb_dmg = maxi(1, int(float(int(equipped_weapon.get("damage"))) * 1.5 * _damage_mult))
	mana -= FIREBALL_MANA
	mana_changed.emit(mana, max_mana)
	_spawn_magic_bolt(fb_dmg, 90.0, 350.0, Color(1.0, 0.4, 0.05),
					  FIREBALL_SPLASH, "fire_trail", "fire_ex")
	_skill_cds[0] = SKILL_FIREBALL_CD
	skill_cooldown_changed.emit(0, SKILL_FIREBALL_CD, SKILL_FIREBALL_CD)
	FX.camera_shake(1.5, 0.12)


func _skill_magic_shield() -> void:
	if level < SKILL_MAGIC_SHIELD_LEVEL:
		notice_requested.emit("Escudo mágico en Nv.%d" % SKILL_MAGIC_SHIELD_LEVEL)
		return
	if _skill_cds[1] > 0.0:
		notice_requested.emit("Escudo mágico: %.0fs" % _skill_cds[1])
		return
	const SHIELD_MANA := 30
	if mana < SHIELD_MANA:
		notice_requested.emit("Sin maná (%d necesario)" % SHIELD_MANA)
		return
	mana -= SHIELD_MANA
	mana_changed.emit(mana, max_mana)
	_magic_shield_active = true
	_magic_shield_t      = 5.0
	_skill_cds[1]        = SKILL_MAGIC_SHIELD_CD
	skill_cooldown_changed.emit(1, SKILL_MAGIC_SHIELD_CD, SKILL_MAGIC_SHIELD_CD)
	FX.particles(global_position, "shield")
	_sprite.self_modulate = Color(0.5, 0.75, 2.5)
	notice_requested.emit("¡Escudo mágico activo! (5s)")


func _skill_ice_ray() -> void:
	if level < SKILL_ICE_RAY_LEVEL:
		notice_requested.emit("Rayo de hielo en Nv.%d" % SKILL_ICE_RAY_LEVEL)
		return
	if _skill_cds[2] > 0.0:
		notice_requested.emit("Rayo de hielo: %.0fs" % _skill_cds[2])
		return
	const ICE_MANA := 25
	if mana < ICE_MANA:
		notice_requested.emit("Sin maná (%d necesario)" % ICE_MANA)
		return
	var ice_dmg: int = 10
	if equipped_weapon != null:
		ice_dmg = maxi(1, int(float(int(equipped_weapon.get("damage"))) * 0.9 * _damage_mult))
	mana -= ICE_MANA
	mana_changed.emit(mana, max_mana)
	_spawn_magic_bolt(ice_dmg, 260.0, 380.0, Color(0.5, 0.9, 1.2),
					  0.0, "ice_trail", "ice_hit", true, 3.0)
	_skill_cds[2] = SKILL_ICE_RAY_CD
	skill_cooldown_changed.emit(2, SKILL_ICE_RAY_CD, SKILL_ICE_RAY_CD)
