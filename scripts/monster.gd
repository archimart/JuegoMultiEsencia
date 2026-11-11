extends CharacterBody2D

signal died  # emitida antes de queue_free para que el compañero reciba XP

enum State { WANDER, CHASE, ATTACK, FLEE, DEAD }

const WANDER_SPEED_MUL := 0.45
const WANDER_CHANGE_T  := 2.0
const KNOCKBACK_DECAY  := 10.0
const ANIM_FPS         := 5.0

@export var data: MonsterData

@onready var _sprite:    AnimatedSprite2D = $AnimatedSprite2D
@onready var _col_shape: CollisionShape2D = $CollisionShape2D

var _dir_anim := DirectionAnimator.new()

var _state:      int     = State.WANDER
var _player:     Node2D  = null
var _health:     int     = 0
var _knockback:  Vector2 = Vector2.ZERO
var _attack_cd:  float   = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _wander_t:   float   = 0.0
var _hp_visible: bool    = false
var _slow_mult:  float   = 1.0
var _slow_t:     float   = 0.0
var _poison_dps: float   = 0.0
var _poison_t:   float   = 0.0
var _poison_acc: float   = 0.0
var _cursed_t:   float   = 0.0
var _taunt_node: Node2D  = null
var _taunt_t:    float   = 0.0

var _coin_scene: PackedScene = preload("res://scenes/coin.tscn")


func _ready() -> void:
	add_to_group("monster")
	if data == null:
		push_error("Monster sin MonsterData asignado")
		return
	_health = data.max_health

	_sprite.centered      = true
	_sprite.offset        = Vector2(0.0, -data.frame_size * 0.5)
	_sprite.sprite_frames = DirectionAnimator.build_4dir_frames(
		load(data.sprite_path), data.frame_size, 4, ANIM_FPS
	)
	_sprite.play("walk_down")

	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]

	_wander_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	_wander_t   = randf_range(0.3, WANDER_CHANGE_T)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _slow_t > 0.0:
		_slow_t = maxf(0.0, _slow_t - delta)
		if _slow_t <= 0.0:
			_slow_mult = 1.0
	# Veneno
	if _poison_t > 0.0:
		_poison_t -= delta
		_poison_acc += _poison_dps * delta
		if _poison_acc >= 1.0:
			var pdmg := int(_poison_acc)
			_poison_acc -= float(pdmg)
			_health -= pdmg
			FX.damage_number(global_position + Vector2(0.0, -20.0), pdmg, Color(0.35, 0.95, 0.3))
			if _health <= 0 and _state != State.DEAD:
				_die()
				return
		if _poison_t <= 0.0:
			_poison_acc = 0.0
	# Maldición
	if _cursed_t > 0.0:
		_cursed_t = maxf(0.0, _cursed_t - delta)
	# Provocación
	if _taunt_t > 0.0:
		_taunt_t = maxf(0.0, _taunt_t - delta)
		if _taunt_t <= 0.0 or not is_instance_valid(_taunt_node):
			_taunt_node = null
	# Modulación visual según estado activo
	if _poison_t > 0.0:
		_sprite.self_modulate = Color(0.4, 1.3, 0.4)
	elif _cursed_t > 0.0:
		_sprite.self_modulate = Color(0.75, 0.4, 1.0)
	elif _slow_t > 0.0:
		_sprite.self_modulate = Color(0.5, 0.85, 1.8)
	else:
		_sprite.self_modulate = Color.WHITE
	_knockback = _knockback.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity   = Vector2.ZERO

	match _state:
		State.WANDER: _tick_wander(delta)
		State.CHASE:  _tick_chase()
		State.ATTACK: _tick_attack()
		State.FLEE:   _tick_flee()

	velocity += _knockback
	move_and_slide()
	_tick_sprite()
	queue_redraw()


func _tick_wander(delta: float) -> void:
	if _player != null and not data.is_static:
		var dist := global_position.distance_to(_player.global_position)
		if dist < data.vision_range:
			_state = State.CHASE
			return
	elif _player != null and data.is_static:
		# Estático: ataca solo si el jugador entra al rango de ataque
		if global_position.distance_to(_player.global_position) <= data.attack_range:
			_state = State.ATTACK
			return
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = WANDER_CHANGE_T + randf() * 1.5
		if randf() < 0.25:
			_wander_dir = Vector2.ZERO
		else:
			_wander_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	velocity = _wander_dir * data.speed * WANDER_SPEED_MUL * _slow_mult


func _tick_chase() -> void:
	if _player == null:
		_state = State.WANDER
		return
	if _player.get("in_safe_zone"):
		_state = State.WANDER
		return
	var chase_target: Node2D = _taunt_node \
		if (_taunt_node != null and is_instance_valid(_taunt_node)) else _player
	var diff := chase_target.global_position - global_position
	var dist := diff.length()
	if chase_target == _player and dist > data.vision_range * 1.5:
		_state = State.WANDER
		return
	if dist <= data.attack_range:
		_state = State.ATTACK
		return
	velocity = diff.normalized() * data.speed * _slow_mult


func _tick_attack() -> void:
	if _player == null:
		_state = State.WANDER
		return
	var attack_target: Node2D = _taunt_node \
		if (_taunt_node != null and is_instance_valid(_taunt_node)) else _player
	var dist := global_position.distance_to(attack_target.global_position)
	if dist > data.attack_range * 1.4:
		_state = State.CHASE if not data.is_static else State.WANDER
		return
	if _attack_cd <= 0.0:
		if _cursed_t > 0.0:
			# Maldición: no puede atacar, solo reinicia el cooldown
			_attack_cd = data.attack_cooldown
		elif attack_target != _player:
			# Provocado: ataca al familiar del gólem
			if attack_target.has_method("take_damage"):
				attack_target.call("take_damage", data.damage, global_position)
			_attack_cd = data.attack_cooldown
		else:
			if _player.has_method("take_hit"):
				_player.take_hit(data.damage)
				if _player.has_signal("hurt_by"):
					_player.hurt_by.emit(self)
				if data.poisons_on_hit and _player.has_method("apply_poison"):
					_player.apply_poison(data.poison_dps, data.poison_duration)
			# Golpear al compañero si está cerca (daño reducido al 50 %)
			for comp: Node in get_tree().get_nodes_in_group("companion"):
				if comp is Node2D and comp.has_method("take_hit_companion"):
					var cdist := (comp as Node2D).global_position.distance_to(global_position)
					if cdist < data.attack_range * 1.5:
						comp.call("take_hit_companion", maxi(1, data.damage / 2))
			# Golpear familiares cercanos al jugador (están en la espalda, no al frente)
			for fam in get_tree().get_nodes_in_group("familiar"):
				if fam is Node2D and fam.has_method("take_damage"):
					var fdist := (fam as Node2D).global_position.distance_to(_player.global_position)
					if fdist < 55.0:
						fam.call("take_damage", maxi(1, data.damage), global_position)
			_attack_cd = data.attack_cooldown


func _tick_flee() -> void:
	if _player == null:
		_state = State.WANDER
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > data.vision_range * 2.0:
		_state = State.WANDER
		return
	var away := (global_position - _player.global_position).normalized()
	velocity = away * data.speed * _slow_mult


func take_damage(amount: int, from_pos: Vector2 = Vector2.ZERO) -> void:
	if _state == State.DEAD:
		return
	_health    -= amount
	_hp_visible = true
	if from_pos != Vector2.ZERO:
		_knockback = (global_position - from_pos).normalized() * 75.0
	_sprite.modulate = Color(5.0, 5.0, 5.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.14)
	FX.hit_stop(0.05)
	FX.damage_number(global_position + Vector2(0.0, -20.0), amount)
	SFX.play("hit_monster")
	if data.flees_when_hurt and _state != State.FLEE:
		var ratio := float(_health) / float(data.max_health)
		if ratio < data.flee_threshold:
			_state = State.FLEE
	if _health <= 0:
		_die()


func _die() -> void:
	_state = State.DEAD
	set_physics_process(false)
	_col_shape.set_deferred("disabled", true)
	died.emit()  # antes de queue_free para que los oyentes aún tengan referencia válida
	CompanionSystem.on_monster_killed(data, global_position, _player)
	FamiliarSystem.on_monster_killed(data, global_position, _player)
	FamiliarSystem.try_drop_egg(data, global_position, get_tree().current_scene)
	if _player != null and _player.has_method("add_xp"):
		_player.call("add_xp", _xp_for_region(str(data.get("region"))))
	FX.particles(global_position, "death")
	FX.camera_shake(2.5, 0.12)
	SFX.play("die_monster")
	var gold_count := randi_range(data.gold_min, data.gold_max)
	var scene      := get_tree().current_scene
	for _i: int in gold_count:
		var coin: Node2D = _coin_scene.instantiate()
		coin.global_position = global_position + Vector2(
			randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)
		)
		scene.call_deferred("add_child", coin)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.35)
	tw.tween_callback(queue_free)


func apply_slow(duration: float, mult: float = 0.35) -> void:
	_slow_mult = mult
	_slow_t    = maxf(_slow_t, duration)


func apply_poison(dps: float, duration: float) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_t   = maxf(_poison_t, duration)


func apply_curse(duration: float) -> void:
	_cursed_t = maxf(_cursed_t, duration)


func set_taunt(node: Node2D, duration: float) -> void:
	_taunt_node = node
	_taunt_t    = duration
	if _state == State.WANDER:
		_state = State.CHASE


func _xp_for_region(region: String) -> int:
	match region:
		"pradera":  return 15
		"bosque":   return 25
		"montaña":  return 35
		"desierto": return 35
		"pantano":  return 45
	return 15


func _tick_sprite() -> void:
	match _state:
		State.WANDER:
			if _wander_dir.length_squared() > 0.01:
				_dir_anim.update_velocity(_wander_dir)
		State.CHASE, State.ATTACK:
			if _player != null:
				_dir_anim.face_target(global_position, _player.global_position)
		State.FLEE:
			if _player != null:
				# Cara hacia donde huye (opuesto al jugador)
				var away := global_position - _player.global_position
				if away.length_squared() > 0.01:
					_dir_anim.update_velocity(away)
	var anim := "walk_" + _dir_anim.get_dir()
	if _sprite.animation != anim:
		_sprite.play(anim)


func _draw() -> void:
	if not _hp_visible or data == null:
		return
	const BW := 16
	const BH := 2
	var x := -BW / 2
	var y := -24
	draw_rect(Rect2(x, y, BW, BH), Color(0.1, 0.1, 0.1))
	var ratio := clampf(float(_health) / float(data.max_health), 0.0, 1.0)
	var fill  := int(BW * ratio)
	if fill > 0:
		var col := Color(0.2, 0.85, 0.2) if ratio > 0.5 else Color(0.9, 0.3, 0.1)
		draw_rect(Rect2(x, y, fill, BH), col)
