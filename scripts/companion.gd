extends CharacterBody2D

signal xp_changed(current_xp: int, xp_to_next: int)
signal level_changed(new_level: int)
signal notice_requested(text: String)

# Preloads explícitos para que el parser resuelva los tipos antes del escaneo global
const CompanionData    := preload("res://scripts/companion_data.gd")
const CompanionAbility := preload("res://scripts/companion_ability.gd")

enum State { FOLLOW, ACTIVE, RETURN }

const FOLLOW_DIST     := 18.0
const SPEED           := 110.0
const RETURN_SPEED    := 150.0
const TELEPORT_DIST   := 200.0
const STOP_RADIUS     := 12.0
const IDLE_SPEED_SCALE := 0.4
const XP_RANGE        := 200.0
const MAX_TARGET_DIST := 150.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var data: CompanionData = null

var target: Node2D = null  # jugador propietario

var _state:     int     = State.FOLLOW
var _enemy:     Node2D  = null
var _attack_cd: float   = 0.0
var _level:     int     = 0
var _xp:        int     = 0
var _ability:   Node    = null   # CompanionAbility instanciado desde data.ability_scene_path

var _dir_anim := DirectionAnimator.new()


func _ready() -> void:
	add_to_group("companion")
	_build_frames()
	get_tree().node_added.connect(_on_node_added)
	for m: Node in get_tree().get_nodes_in_group("monster"):
		_hook_monster(m)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)

	match _state:
		State.FOLLOW: _tick_follow()
		State.ACTIVE: _tick_active()
		State.RETURN: _tick_return()

	move_and_slide()
	_update_sprite()


# ─── Configuración ─────────────────────────────────────────────────────────────

func set_target(player: Node2D) -> void:
	target = player
	_init_ability()
	if player.has_signal("hurt_by"):
		player.hurt_by.connect(_on_player_hurt_by)


func _init_ability() -> void:
	if data == null or data.ability_scene_path.is_empty():
		return
	if not ResourceLoader.exists(data.ability_scene_path):
		push_warning("[Companion] Ability scene no encontrada: %s" % data.ability_scene_path)
		return
	var scene := load(data.ability_scene_path) as PackedScene
	if scene == null:
		return
	_ability = scene.instantiate()
	add_child(_ability)
	_ability.hit_landed.connect(_on_hit_landed)
	_ability.finished.connect(_on_ability_finished)


# ─── Objetivo de ataque ────────────────────────────────────────────────────────

func set_attack_target(monster: Node2D) -> void:
	# MP: solo el servidor cambia de estado; añadir is_multiplayer_authority() en multijugador
	if _ability == null or _state == State.ACTIVE:
		return
	if not is_instance_valid(monster):
		return
	if _attack_cd > 0.0:
		return
	_enemy = monster
	_ability.activate(monster)
	_state = State.ACTIVE


func _on_player_hurt_by(attacker: Node) -> void:
	if attacker is Node2D:
		set_attack_target(attacker as Node2D)


func _on_hit_landed(enemy: Node2D, mult: float) -> void:
	_apply_hit(enemy, mult)


func _on_ability_finished() -> void:
	_state = State.RETURN


func _on_node_added(node: Node) -> void:
	if node.is_in_group("monster"):
		_hook_monster(node)


func _hook_monster(m: Node) -> void:
	if m.has_signal("died") and not m.died.is_connected(_on_monster_died.bind(m)):
		m.died.connect(_on_monster_died.bind(m))


func _on_monster_died(monster: Node) -> void:
	if target != null:
		var dist := (monster as Node2D).global_position.distance_to(target.global_position)
		if dist <= XP_RANGE:
			add_xp(1)
	if _enemy == monster:
		_enemy = null
		if _ability != null:
			_ability.cancel()
		_state = State.RETURN


# ─── XP y niveles ──────────────────────────────────────────────────────────────

func add_xp(amount: int) -> void:
	# MP: solo el servidor llama esto
	if data == null:
		return
	var max_idx: int = data.damage_per_level.size() - 1
	if _level >= max_idx:
		return
	_xp += amount
	_check_level_up()
	xp_changed.emit(_xp, _get_xp_to_next())


func _check_level_up() -> void:
	if data == null:
		return
	var needed := _get_xp_to_next()
	while needed > 0 and _xp >= needed:
		_xp   -= needed
		_level += 1
		_on_level_up()
		needed = _get_xp_to_next()
	xp_changed.emit(_xp, _get_xp_to_next())


func _get_xp_to_next() -> int:
	if data == null or _level >= data.xp_to_next.size():
		return 0
	return data.xp_to_next[_level]


func get_level_display() -> int:
	return _level + 1


func _on_level_up() -> void:
	var lvl := get_level_display()
	notice_requested.emit("¡%s subió al nivel %d!" % [data.companion_name if data else "Compañero", lvl])
	FX.damage_number(global_position + Vector2(0.0, -28.0), lvl, Color(1.0, 0.88, 0.15))
	FX.camera_shake(2.0, 0.1)
	SFX.play("coin")
	_sprite.self_modulate = Color(3.5, 2.8, 0.5)
	var tw := create_tween()
	tw.tween_property(_sprite, "self_modulate", Color.WHITE, 0.5)
	level_changed.emit(lvl)


func _get_damage() -> int:
	if data == null:
		return 2
	return data.damage_per_level[_level]


func _get_cooldown() -> float:
	if data == null:
		return 3.0
	return data.cooldown_per_level[_level]


# ─── Estados ───────────────────────────────────────────────────────────────────

func _tick_follow() -> void:
	var player_dir := (target.get("last_dir") as Vector2)
	if player_dir == Vector2.ZERO:
		player_dir = Vector2.DOWN
	var ideal_pos := target.global_position - player_dir * FOLLOW_DIST

	if global_position.distance_to(target.global_position) > TELEPORT_DIST:
		global_position    = ideal_pos
		velocity           = Vector2.ZERO
		return

	var to_ideal := ideal_pos - global_position
	var dist     := to_ideal.length()
	if dist > STOP_RADIUS:
		velocity            = to_ideal.normalized() * minf(SPEED, dist * 6.0)
		_sprite.speed_scale = 1.0
	else:
		velocity            = Vector2.ZERO
		_sprite.speed_scale = IDLE_SPEED_SCALE


func _tick_active() -> void:
	if not is_instance_valid(_enemy) or _ability == null or not _ability.is_active():
		if _ability != null:
			_ability.cancel()
		_state = State.RETURN
		return
	if target != null and _enemy.global_position.distance_to(target.global_position) > MAX_TARGET_DIST:
		_ability.cancel()
		_state = State.RETURN
		return
	velocity            = _ability.get_velocity(global_position)
	_sprite.speed_scale = _ability.get_speed_scale()


func _tick_return() -> void:
	if target == null:
		_state = State.FOLLOW
		return
	var to_player := target.global_position - global_position
	var dist      := to_player.length()
	if dist < STOP_RADIUS:
		_state              = State.FOLLOW
		velocity            = Vector2.ZERO
		_sprite.speed_scale = IDLE_SPEED_SCALE
		return
	velocity            = to_player.normalized() * RETURN_SPEED
	_sprite.speed_scale = 1.2


func _apply_hit(enemy: Node2D, mult: float = 1.0) -> void:
	# MP: solo el servidor aplica daño
	if not is_instance_valid(enemy):
		return
	var dmg := int(float(_get_damage()) * mult)
	if enemy.has_method("take_damage"):
		enemy.take_damage(dmg, global_position)
	FX.particles(global_position, "hit")
	if mult > 1.5:
		FX.camera_shake(3.0, 0.15)
		FX.damage_number(global_position + Vector2(0.0, -8.0), dmg, Color(1.0, 0.5, 0.1))
	_attack_cd = _get_cooldown()


# ─── Sprite ────────────────────────────────────────────────────────────────────

func _update_sprite() -> void:
	if data != null and data.sprite_is_4dir:
		var anim := _get_4dir_anim()
		if _sprite.animation != anim:
			_sprite.play(anim)
	else:
		var dir := _dir_anim.update_velocity(velocity)
		if dir == "left":
			_sprite.flip_h = true
		elif dir == "right":
			_sprite.flip_h = false


func _get_4dir_anim() -> String:
	var prefix := "walk_" if velocity.length_squared() > 4.0 else "idle_"
	if velocity.length_squared() > 4.0:
		_dir_anim.update_velocity(velocity)
	return prefix + _dir_anim.get_dir()


func _build_frames() -> void:
	if data == null:
		_build_fallback_frames()
		return
	if data.sprite_is_4dir:
		_build_4dir_frames()
	else:
		_build_animal_frames()


func _build_animal_frames() -> void:
	if data.sprite_tex.is_empty():
		_build_fallback_frames()
		return
	var frames := SpriteFrames.new()
	var tex: Texture2D = load(data.sprite_tex)
	frames.add_animation("fly")
	frames.set_animation_speed("fly", data.sprite_fps)
	frames.set_animation_loop("fly", true)
	var cols: int = int(tex.get_width()) / data.sprite_cell_w
	for col: int in cols:
		var a := AtlasTexture.new()
		a.atlas  = tex
		a.region = Rect2(col * data.sprite_cell_w, 0, data.sprite_cell_w, data.sprite_cell_h)
		frames.add_frame("fly", a)
	_sprite.sprite_frames = frames
	_sprite.play("fly")


func _build_4dir_frames() -> void:
	if data.sprite_walk_tex.is_empty():
		_build_fallback_frames()
		return
	var frames := DirectionAnimator.build_4dir_frames(
		load(data.sprite_walk_tex), data.sprite_tile_size, data.sprite_walk_frames, data.sprite_fps, "walk"
	)
	if not data.sprite_idle_tex.is_empty():
		DirectionAnimator.build_4dir_frames(
			load(data.sprite_idle_tex), data.sprite_tile_size, 1, 1.0, "idle", frames
		)
	_sprite.sprite_frames = frames
	_sprite.play("idle_down" if frames.has_animation("idle_down") else "walk_down")


func _build_fallback_frames() -> void:
	# Parrot rojo como fallback si no hay datos de sprite
	const TEX := "res://assets/Actor/Animal/Parrot/SpriteSheetRed.png"
	var frames := SpriteFrames.new()
	var tex: Texture2D = load(TEX)
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 6.0)
	frames.set_animation_loop("fly", true)
	for col: int in 2:
		var a := AtlasTexture.new()
		a.atlas  = tex
		a.region = Rect2(col * 16, 0, 16, 16)
		frames.add_frame("fly", a)
	_sprite.sprite_frames = frames
	_sprite.play("fly")
