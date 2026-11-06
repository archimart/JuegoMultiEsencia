extends Node
## Efectos visuales reutilizables: temblor de cámara, hit-stop, números de daño y partículas.

var _camera:    Camera2D = null
var _shake_str: float    = 0.0
var _shake_dur: float    = 0.0
var _shake_t:   float    = 0.0
var _hitstop:   bool     = false

var _dmg_scene: PackedScene = preload("res://scenes/damage_number.tscn")


func _process(delta: float) -> void:
	if _shake_t <= 0.0:
		return
	_shake_t -= delta
	var cam := _get_camera()
	if cam == null:
		return
	var ratio := clampf(_shake_t / _shake_dur, 0.0, 1.0)
	var s     := _shake_str * ratio
	cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	if _shake_t <= 0.0:
		cam.offset = Vector2.ZERO


# ─── API pública ───────────────────────────────────────────────────────────────

func camera_shake(strength: float = 3.0, duration: float = 0.15) -> void:
	_shake_str = strength
	_shake_dur = duration
	_shake_t   = duration


func hit_stop(duration: float = 0.05) -> void:
	if _hitstop:
		return
	_hitstop          = true
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop          = false


func damage_number(world_pos: Vector2, amount: int, color: Color = Color.WHITE) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var node: Node2D = _dmg_scene.instantiate() as Node2D
	root.add_child(node)
	node.global_position = world_pos  # después de add_child para respetar transform del padre
	node.call("setup", amount, color)


func particles(world_pos: Vector2, type: String) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	match type:
		"hit":    _cfg_hit(p)
		"death":  _cfg_death(p)
		"chop":   _cfg_chop(p)
		"coin":   _cfg_coin(p)
		"heal":   _cfg_heal(p)
		"shield": _cfg_shield(p)
		"punch":     _cfg_punch(p)
		"slash":     _cfg_slash(p)
		"magic_hit": _cfg_magic_hit(p)
		"nova":      _cfg_nova(p)
		"fire_ex":   _cfg_fire_ex(p)
		"fire_trail":_cfg_fire_trail(p)
		"ice_hit":   _cfg_ice_hit(p)
		"ice_trail": _cfg_ice_trail(p)
		"mine":      _cfg_mine(p)
	root.add_child(p)
	p.global_position = world_pos  # siempre después de add_child
	p.emitting = true
	p.finished.connect(p.queue_free)


# ─── Utilidad ─────────────────────────────────────────────────────────────────

func _get_camera() -> Camera2D:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	return _camera


# ─── Presets de partículas ─────────────────────────────────────────────────────

func _cfg_hit(p: CPUParticles2D) -> void:
	p.amount               = 8
	p.lifetime             = 0.35
	p.explosiveness        = 0.95
	p.spread               = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 75.0
	p.gravity              = Vector2(0.0, 60.0)
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.0
	p.color                = Color(1.0, 0.85, 0.2)


func _cfg_death(p: CPUParticles2D) -> void:
	p.amount               = 22
	p.lifetime             = 0.55
	p.explosiveness        = 1.0
	p.spread               = 180.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 110.0
	p.gravity              = Vector2(0.0, 40.0)
	p.scale_amount_min     = 1.5
	p.scale_amount_max     = 3.0
	p.color                = Color(1.0, 0.45, 0.1)


func _cfg_chop(p: CPUParticles2D) -> void:
	p.amount               = 10
	p.lifetime             = 0.5
	p.explosiveness        = 0.9
	p.direction            = Vector2(0.0, -1.0)
	p.spread               = 60.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 65.0
	p.gravity              = Vector2(0.0, 130.0)
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.0
	p.color                = Color(0.55, 0.32, 0.12)


func _cfg_coin(p: CPUParticles2D) -> void:
	p.amount               = 7
	p.lifetime             = 0.4
	p.explosiveness        = 0.9
	p.spread               = 180.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 50.0
	p.gravity              = Vector2.ZERO
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.0
	p.color                = Color(1.0, 0.88, 0.1)


func _cfg_heal(p: CPUParticles2D) -> void:
	p.amount               = 10
	p.lifetime             = 0.8
	p.explosiveness        = 0.7
	p.direction            = Vector2(0.0, -1.0)
	p.spread               = 35.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 50.0
	p.gravity              = Vector2(0.0, -15.0)
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.5
	p.color                = Color(0.2, 1.0, 0.35)


func _cfg_shield(p: CPUParticles2D) -> void:
	p.amount               = 14
	p.lifetime             = 0.45
	p.explosiveness        = 1.0
	p.spread               = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 65.0
	p.gravity              = Vector2.ZERO
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.0
	p.color                = Color(0.3, 0.7, 1.0)


func _cfg_punch(p: CPUParticles2D) -> void:
	p.amount               = 6
	p.lifetime             = 0.22
	p.explosiveness        = 0.9
	p.spread               = 70.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.gravity              = Vector2(0.0, 55.0)
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.0
	p.color                = Color(1.0, 0.65, 0.2)


func _cfg_slash(p: CPUParticles2D) -> void:
	p.amount               = 12
	p.lifetime             = 0.28
	p.explosiveness        = 1.0
	p.spread               = 55.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity              = Vector2(0.0, 20.0)
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.5
	p.color                = Color(1.0, 1.0, 0.55)


func _cfg_magic_hit(p: CPUParticles2D) -> void:
	p.amount               = 10
	p.lifetime             = 0.38
	p.explosiveness        = 1.0
	p.spread               = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.gravity              = Vector2.ZERO
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.5
	p.color                = Color(0.7, 0.35, 1.4)


func _cfg_nova(p: CPUParticles2D) -> void:
	p.amount               = 28
	p.lifetime             = 0.55
	p.explosiveness        = 1.0
	p.spread               = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.gravity              = Vector2.ZERO
	p.scale_amount_min     = 1.5
	p.scale_amount_max     = 3.5
	p.color                = Color(0.55, 0.2, 1.2)


func _cfg_fire_ex(p: CPUParticles2D) -> void:
	p.amount               = 26
	p.lifetime             = 0.58
	p.explosiveness        = 1.0
	p.spread               = 180.0
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 120.0
	p.gravity              = Vector2(0.0, -25.0)
	p.scale_amount_min     = 1.5
	p.scale_amount_max     = 4.0
	p.color                = Color(1.0, 0.4, 0.05)


func _cfg_fire_trail(p: CPUParticles2D) -> void:
	p.amount               = 5
	p.lifetime             = 0.22
	p.explosiveness        = 0.5
	p.spread               = 38.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 18.0
	p.gravity              = Vector2(0.0, -28.0)
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.0
	p.color                = Color(1.0, 0.55, 0.1)


func _cfg_ice_hit(p: CPUParticles2D) -> void:
	p.amount               = 12
	p.lifetime             = 0.5
	p.explosiveness        = 1.0
	p.spread               = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 65.0
	p.gravity              = Vector2.ZERO
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.5
	p.color                = Color(0.4, 0.88, 1.0)


func _cfg_ice_trail(p: CPUParticles2D) -> void:
	p.amount               = 5
	p.lifetime             = 0.18
	p.explosiveness        = 0.6
	p.spread               = 24.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 16.0
	p.gravity              = Vector2.ZERO
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 1.8
	p.color                = Color(0.6, 0.92, 1.0)


func _cfg_mine(p: CPUParticles2D) -> void:
	p.amount               = 10
	p.lifetime             = 0.4
	p.explosiveness        = 0.95
	p.spread               = 120.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 70.0
	p.gravity              = Vector2(0.0, 80.0)
	p.scale_amount_min     = 1.0
	p.scale_amount_max     = 2.5
	p.color                = Color(0.6, 0.55, 0.5)
