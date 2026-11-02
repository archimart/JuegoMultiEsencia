extends CharacterBody2D

signal inventory_changed
signal notice_requested(text: String)
signal health_changed
signal hurt_by(attacker: Node)  # emitida por monster.gd cuando nos golpea

const DEFAULT_WALK_TEX   := "res://assets/Actor/Character/Hunter/SeparateAnim/Walk.png"
const DEFAULT_IDLE_TEX   := "res://assets/Actor/Character/Hunter/SeparateAnim/Idle.png"
const SHOOT_COOLDOWN     := 0.4
const INVULNERABILITY_T  := 1.5
const RESPAWN_POS        := Vector2(80.0, 90.0)

var max_hp: int   = 30     # público para que hud.gd lo lea
var _speed: float = 80.0
var _walk_tex:       String = DEFAULT_WALK_TEX
var _idle_tex:       String = DEFAULT_IDLE_TEX
var _sprite_dir_path: String = ""

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_dir:        Vector2    = Vector2.DOWN
var _shoot_cooldown: float      = 0.0
var _inv_t:          float      = 0.0   # tiempo de invulnerabilidad restante
var inventory:       Dictionary = {}
var hp:              int        = 30
var in_safe_zone:    bool       = false

var _arrow_scene: PackedScene = preload("res://scenes/arrow.tscn")
var _bag_scene:   PackedScene = preload("res://scenes/loot_bag.tscn")
var _dir_anim    := DirectionAnimator.new()


func setup_race(race: RaceData) -> void:
	max_hp  = race.max_hp
	hp      = race.max_hp
	_speed  = race.speed
	_walk_tex        = race.walk_tex_path if not race.walk_tex_path.is_empty() else DEFAULT_WALK_TEX
	_idle_tex        = race.idle_tex_path if not race.idle_tex_path.is_empty() else DEFAULT_IDLE_TEX
	_sprite_dir_path = race.sprite_dir_path
	_build_frames()
	health_changed.emit()


func _ready() -> void:
	add_to_group("player")
	_build_frames()


func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	velocity = input.normalized() * _speed if input != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

	if input != Vector2.ZERO:
		last_dir = input.normalized()

	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)

	# Invulnerabilidad y parpadeo
	if _inv_t > 0.0:
		_inv_t -= delta
		# Parpadeo: ciclos de 0.16 s; mitad opaco, mitad transparente
		_sprite.modulate.a = 0.25 if fmod(_inv_t, 0.16) < 0.08 else 1.0
	else:
		_sprite.modulate.a = 1.0

	_update_anim(input != Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey \
			and event.keycode == KEY_F1 and event.pressed:
		collect_item("wood", 20)
		collect_item("arrows", 20)
		if inventory.get("bow", 0) == 0:
			collect_item("bow", 1)
		return

	if not event.is_action_pressed("shoot"):
		return
	if inventory.get("bow", 0) <= 0:
		return
	if inventory.get("arrows", 0) <= 0:
		notice_requested.emit("Sin flechas")
		return
	if _shoot_cooldown > 0.0:
		return
	_shoot()


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


func collect_item(item: String, amount: int) -> void:
	inventory[item] = inventory.get(item, 0) + amount
	inventory_changed.emit()


func take_hit(damage: int) -> void:
	if _inv_t > 0.0:
		return
	hp    = maxi(0, hp - damage)
	_inv_t = INVULNERABILITY_T
	health_changed.emit()
	_sprite.self_modulate = Color(4.0, 4.0, 4.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "self_modulate", Color.WHITE, 0.12)
	FX.camera_shake(4.0, 0.18)
	FX.damage_number(global_position + Vector2(0.0, -20.0), damage, Color(1.0, 0.35, 0.35))
	SFX.play("hit_player")
	if hp <= 0:
		_respawn()


func _respawn() -> void:
	if not inventory.is_empty():
		var bag: Node2D = _bag_scene.instantiate()
		bag.position = global_position
		bag.set("contents", inventory.duplicate())
		get_tree().current_scene.add_child(bag)
	inventory.clear()
	inventory_changed.emit()
	hp = max_hp
	global_position = RESPAWN_POS
	_inv_t = INVULNERABILITY_T * 2.0
	health_changed.emit()
	SFX.play("die_player")
	notice_requested.emit("Derrotado  —  bolsa en el punto de caída")


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
	var frames := DirectionAnimator.build_4dir_frames(load(_walk_tex), 16, 4, 8.0, "walk")
	DirectionAnimator.build_4dir_frames(load(_idle_tex), 16, 1, 1.0, "idle", frames)
	_sprite.sprite_frames = frames
	_sprite.play("idle_down")


func _build_directional_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var base := _sprite_dir_path
	var dir_map := {"down": "south", "up": "north", "left": "west", "right": "east"}
	for dir: String in ["down", "up", "left", "right"]:
		var dname: String = dir_map[dir]

		# Walk: 8 frames con loop
		var walk_anim := "walk_" + dir
		frames.add_animation(walk_anim)
		frames.set_animation_speed(walk_anim, 8.0)
		frames.set_animation_loop(walk_anim, true)
		for i: int in 8:
			var path := base + "/Idle/animations/Walking/" + dname + "/frame_%03d.png" % i
			frames.add_frame(walk_anim, load(path))

		# Idle: 1 frame estático
		var idle_anim := "idle_" + dir
		frames.add_animation(idle_anim)
		frames.set_animation_speed(idle_anim, 1.0)
		frames.set_animation_loop(idle_anim, false)
		frames.add_frame(idle_anim, load(base + "/Idle/rotations/" + dname + ".png"))

	_sprite.sprite_frames = frames
	_sprite.play("idle_down")
