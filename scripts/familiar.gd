extends CharacterBody2D

const FOLLOW_DIST   := 12.0
const TELEPORT_DIST := 200.0
const RETURN_DIST   := 220.0
const ANIM_FPS      := 5.0

var monster_id:     String = ""
var rarity:         String = "common"
var is_shiny:       bool   = false
var stat_mult:      float  = 1.0
var hp:             int    = 15

var _max_hp:        int    = 15
var _damage:        int    = 4
var _attack_cd_max: float  = 1.4
var _move_speed:    float  = 150.0
var _attack_range:  float  = 44.0

const SPIRIT_SHIELD_CD := 10.0
const GOLEM_TAUNT_CD   := 6.0
const GOLEM_TAUNT_RANGE := 100.0

var _player:     Node2D  = null
var _target:     Node2D  = null
var _attack_cd:  float   = 0.0
var _slot:       int     = 0
var _smooth_dir: Vector2 = Vector2(0.0, 1.0)
var _shiny_t:    float   = 0.0
var _ability_id: String  = ""
var _ability_t:  float   = 0.0

var _sprite:   AnimatedSprite2D
var _dir_anim := DirectionAnimator.new()


func _ready() -> void:
	add_to_group("familiar")
	collision_layer = 4
	collision_mask  = 1

	_sprite          = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.scale    = Vector2(0.6, 0.6)
	_sprite.offset   = Vector2(0.0, -6.0)
	add_child(_sprite)

	var cs    := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 3.0
	shape.height = 6.0
	cs.shape = shape
	add_child(cs)


func setup(player: Node2D, mid: String, egg_rarity: String = "common", shiny: bool = false) -> void:
	monster_id = mid
	rarity     = egg_rarity
	is_shiny   = shiny
	stat_mult  = _calc_stat_mult(egg_rarity, shiny)
	_player    = player
	_slot      = clampi(FamiliarSystem.get_active_count() - 1, 0, 4)
	_load_data()
	match _ability_id:
		"spirit": _ability_t = SPIRIT_SHIELD_CD
		"golem":  _ability_t = GOLEM_TAUNT_CD * 0.4
	_load_sprite()
	_apply_shader()
	_play_spawn_animation()
	if player.has_signal("hurt_by"):
		player.hurt_by.connect(_on_player_hurt)
	if player.has_signal("attack_hit"):
		player.attack_hit.connect(_on_player_attack_hit)
	FamiliarSystem.affection_changed.connect(_on_affection_changed)


func _calc_stat_mult(rar: String, shiny: bool) -> float:
	var base: float = 1.0
	match rar:
		"rare":  base = 1.25
		"epic":  base = 1.5
	if shiny:
		base *= 1.1
	return base


func _load_data() -> void:
	_apply_data_from_resource()
	hp = _max_hp


func _apply_data_from_resource() -> void:
	var path := "res://resources/familiar_%s.tres" % monster_id
	if not ResourceLoader.exists(path):
		return
	var data: Resource = load(path)
	var total_mult := stat_mult \
		* FamiliarSystem.get_affection_mult(monster_id) \
		* FamiliarSystem.get_level_mult(monster_id)
	_max_hp        = int(roundf(float(data.get("max_hp")) * total_mult))
	_damage        = int(roundf(float(data.get("damage")) * total_mult))
	_attack_cd_max = float(data.get("attack_cooldown"))
	_move_speed    = float(data.get("move_speed"))
	_attack_range  = float(data.get("attack_range"))
	_ability_id    = str(data.get("ability_id"))


func _recalc_stats() -> void:
	var old_ratio := float(hp) / float(maxi(1, _max_hp))
	_apply_data_from_resource()
	hp = clampi(int(roundf(old_ratio * float(_max_hp))), 1, _max_hp)


func _on_affection_changed(mid: String, _level: int) -> void:
	if mid == monster_id:
		_recalc_stats()


func _load_sprite() -> void:
	var path := "res://resources/monster_%s.tres" % monster_id
	if not ResourceLoader.exists(path):
		_sprite.sprite_frames = SpriteFrames.new()
		return
	var mon_data: Resource = load(path)
	var sprite_path: String = str(mon_data.get("sprite_path"))
	if not ResourceLoader.exists(sprite_path):
		return
	var frames := DirectionAnimator.build_4dir_frames(load(sprite_path), 16, 4, ANIM_FPS)
	_sprite.sprite_frames = frames
	_sprite.play("walk_down")


func _play_spawn_animation() -> void:
	_sprite.scale = Vector2(0.0, 0.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(0.78, 0.78), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "scale", Vector2(0.6, 0.6), 0.08)


func _apply_shader() -> void:
	if not ResourceLoader.exists("res://shaders/familiar_outline.gdshader"):
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/familiar_outline.gdshader")
	if is_shiny:
		mat.set_shader_parameter("outline_color", Color(1.0, 0.9, 0.2, 1.0))
	elif rarity == "epic":
		mat.set_shader_parameter("outline_color", Color(0.9, 0.5, 1.0, 1.0))
	elif rarity == "rare":
		mat.set_shader_parameter("outline_color", Color(0.5, 0.75, 1.0, 1.0))
	_sprite.material = mat


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _player == null or not is_instance_valid(_player):
		return
	if is_shiny:
		_shiny_t -= delta
		if _shiny_t <= 0.0:
			FX.particles(global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-8.0, 0.0)), "slash")
			_shiny_t = randf_range(1.5, 3.5)
	var raw: Variant = _player.get("last_dir")
	if raw is Vector2 and (raw as Vector2).length_squared() > 0.1:
		_smooth_dir = _smooth_dir.lerp((raw as Vector2).normalized(), 1.0 - exp(-delta * 7.0))

	# Habilidades periódicas (espíritu y gólem actúan aunque no ataquen)
	_ability_t -= delta
	if _ability_t <= 0.0:
		match _ability_id:
			"spirit":
				_ability_t = SPIRIT_SHIELD_CD
				if _player != null and _player.has_method("apply_shield"):
					_player.call("apply_shield")
					FX.particles(global_position, "shield")
			"golem":
				_ability_t = GOLEM_TAUNT_CD
				_do_taunt()

	if _target != null and not is_instance_valid(_target):
		_target = null

	if _target != null:
		var dist := global_position.distance_to(_target.global_position)
		if dist > _attack_range:
			velocity = (_target.global_position - global_position).normalized() * _move_speed
		else:
			velocity = Vector2.ZERO
			if _attack_cd <= 0.0:
				_do_attack()
		if global_position.distance_to(_player.global_position) > RETURN_DIST:
			_target = null
	else:
		var target_pos := _get_arc_pos()
		if global_position.distance_to(_player.global_position) > TELEPORT_DIST:
			global_position = target_pos
			velocity        = Vector2.ZERO
		else:
			var diff := target_pos - global_position
			var dist := diff.length()
			velocity = diff.normalized() * minf(_move_speed, dist * 8.0) if dist > FOLLOW_DIST else Vector2.ZERO

	move_and_slide()
	_update_anim()


func _get_arc_pos() -> Vector2:
	var ids  := FamiliarSystem.get_familiar_monster_ids()
	var idx  := ids.find(monster_id)
	if idx < 0:
		idx = _slot
	var total := maxi(1, ids.size())

	var behind_angle := (-_smooth_dir).angle()
	const ARC_HALF   := 0.785398   # 45° en radianes
	const RADIUS     := 38.0

	var angle: float
	if total == 1:
		angle = behind_angle
	else:
		angle = behind_angle - ARC_HALF + float(idx) / float(total - 1) * ARC_HALF * 2.0

	return _player.global_position + Vector2(cos(angle), sin(angle)) * RADIUS


func _do_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var dmg := _damage
	if _ability_id == "bat":
		dmg = int(float(_damage) * 1.8)
	if _target.has_method("take_damage"):
		_target.call("take_damage", dmg, global_position)
	FX.particles(global_position, "punch")
	_do_ability(_target)
	_attack_cd = _attack_cd_max


func _do_ability(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	match _ability_id:
		"heart":
			if _player != null and _player.has_method("heal_hp"):
				_player.call("heal_hp", 2)
				FX.particles(_player.global_position, "shield")
		"slime":
			if target.has_method("apply_slow"):
				target.call("apply_slow", 2.5)
		"spider":
			if target.has_method("apply_slow"):
				target.call("apply_slow", 3.5, 0.0)
		"scorpion":
			if target.has_method("apply_poison"):
				target.call("apply_poison", 3.5, 4.0)
		"snake":
			if target.has_method("apply_poison"):
				target.call("apply_poison", 2.0, 6.0)
		"skull":
			if target.has_method("apply_curse"):
				target.call("apply_curse", 3.0)
				FX.particles(target.global_position, "death")
		"mushroom":
			# Nube de esporas: daño al objetivo + todos los monstruos en radio 55 px
			for m: Node in get_tree().get_nodes_in_group("monster"):
				if m == target or not is_instance_valid(m) or not m is Node2D:
					continue
				if (m as Node2D).global_position.distance_to(target.global_position) > 55.0:
					continue
				if m.has_method("take_damage"):
					m.call("take_damage", _damage, target.global_position)
			FX.particles(target.global_position, "punch")
		"racoon":
			if _player != null and _player.has_method("collect_item"):
				_player.call("collect_item", "gold", 1)
		"bat":
			FX.particles(global_position, "slash")


func _do_taunt() -> void:
	var count := 0
	for m: Node in get_tree().get_nodes_in_group("monster"):
		if not is_instance_valid(m) or not m is Node2D:
			continue
		if (m as Node2D).global_position.distance_to(global_position) > GOLEM_TAUNT_RANGE:
			continue
		if m.has_method("set_taunt"):
			m.call("set_taunt", self, 4.0)
			count += 1
	if count > 0:
		FX.particles(global_position, "shield")
		if _player != null and _player.has_signal("notice_requested"):
			_player.notice_requested.emit("Gólem provoca %d enemigo%s" % [count, "s" if count > 1 else ""])


func take_damage(dmg: int, _source: Vector2) -> void:
	hp -= dmg
	FX.particles(global_position, "hurt")
	if hp <= 0:
		hp = 0
		FamiliarSystem.familiar_died(monster_id, self)
		queue_free()


func _on_player_hurt(attacker: Node) -> void:
	if is_instance_valid(attacker):
		_target = attacker as Node2D


func _on_player_attack_hit(target: Node2D) -> void:
	if is_instance_valid(target):
		_target = target


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _player == null or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) < 22.0:
		get_viewport().set_input_as_handled()
		_do_pet()


func _do_pet() -> void:
	FamiliarSystem.pet_familiar(monster_id)
	_spawn_heart()


func _spawn_heart() -> void:
	var lbl := Label.new()
	lbl.text = "♥"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.5))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.global_position = global_position + Vector2(-3.0, -14.0)
	get_tree().current_scene.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 14.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.tween_callback(lbl.queue_free)


func _update_anim() -> void:
	if _sprite.sprite_frames == null:
		return
	# Reposo cuando no se mueve ni tiene objetivo
	if velocity.length_squared() < 4.0 and _target == null:
		if _sprite.is_playing():
			_sprite.stop()
			_sprite.frame = 0
		return
	if velocity.length_squared() > 4.0:
		_dir_anim.update_velocity(velocity)
	var anim := "walk_" + _dir_anim.get_dir()
	if not _sprite.sprite_frames.has_animation(anim):
		return
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
