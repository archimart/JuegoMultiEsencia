extends CharacterBody2D

signal died  # emitida antes de queue_free para que el compañero reciba XP

enum State { WANDER, CHASE, ATTACK, DEAD }

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

var _coin_scene: PackedScene = preload("res://scenes/coin.tscn")


func _ready() -> void:
	add_to_group("monster")
	if data == null:
		push_error("Monster sin MonsterData asignado")
		return
	_health = data.max_health

	_sprite.centered      = true
	_sprite.offset        = Vector2(0.0, -8.0)
	_sprite.sprite_frames = DirectionAnimator.build_4dir_frames(
		load(data.sprite_path), 16, 4, ANIM_FPS
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
	_knockback = _knockback.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity   = Vector2.ZERO

	match _state:
		State.WANDER: _tick_wander(delta)
		State.CHASE:  _tick_chase()
		State.ATTACK: _tick_attack()

	velocity += _knockback
	move_and_slide()
	_tick_sprite()
	queue_redraw()


func _tick_wander(delta: float) -> void:
	if _player != null:
		if global_position.distance_to(_player.global_position) < data.vision_range:
			_state = State.CHASE
			return
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = WANDER_CHANGE_T + randf() * 1.5
		if randf() < 0.25:
			_wander_dir = Vector2.ZERO
		else:
			_wander_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	velocity = _wander_dir * data.speed * WANDER_SPEED_MUL


func _tick_chase() -> void:
	if _player == null:
		_state = State.WANDER
		return
	if _player.get("in_safe_zone"):
		_state = State.WANDER
		return
	var diff := _player.global_position - global_position
	var dist := diff.length()
	if dist > data.vision_range * 1.5:
		_state = State.WANDER
		return
	if dist <= data.attack_range:
		_state = State.ATTACK
		return
	velocity = diff.normalized() * data.speed


func _tick_attack() -> void:
	if _player == null:
		_state = State.WANDER
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist > data.attack_range * 1.4:
		_state = State.CHASE
		return
	if _attack_cd <= 0.0:
		if _player.has_method("take_hit"):
			_player.take_hit(data.damage)
			if _player.has_signal("hurt_by"):
				_player.hurt_by.emit(self)
		_attack_cd = data.attack_cooldown


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
	if _health <= 0:
		_die()


func _die() -> void:
	_state = State.DEAD
	set_physics_process(false)
	_col_shape.disabled = true
	died.emit()  # antes de queue_free para que los oyentes aún tengan referencia válida
	FX.particles(global_position, "death")
	FX.camera_shake(2.5, 0.12)
	SFX.play("die_monster")
	var gold_count := randi_range(data.gold_min, data.gold_max)
	for _i: int in gold_count:
		var coin: Node2D = _coin_scene.instantiate()
		coin.global_position = global_position + Vector2(
			randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)
		)
		get_tree().current_scene.add_child(coin)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.35)
	tw.tween_callback(queue_free)


func _tick_sprite() -> void:
	match _state:
		State.WANDER:
			if _wander_dir.length_squared() > 0.01:
				_dir_anim.update_velocity(_wander_dir)
		State.CHASE, State.ATTACK:
			if _player != null:
				_dir_anim.face_target(global_position, _player.global_position)
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
