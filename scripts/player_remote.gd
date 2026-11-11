extends Node2D

@onready var _sprite:     AnimatedSprite2D = $Sprite
@onready var _name_label: Label            = $NameLabel

var _target_pos:   Vector2 = Vector2.ZERO
var _lerp_speed:   float   = 15.0
var _current_anim: String  = ""


func _ready() -> void:
	_target_pos = global_position


func setup(data: Dictionary) -> void:
	_name_label.text = data.get("display_name", "???")

	var race_path: String = data.get("race_path", "")
	if race_path.is_empty():
		return
	var race_res: RaceData = ResourceLoader.load(race_path, "", ResourceLoader.CACHE_MODE_REUSE) as RaceData
	if race_res == null:
		return

	var gender: String  = data.get("gender", "m")
	var variant: String = data.get("sprite_variant", "")

	# Determinar la ruta del sprite (directional o sheet)
	var dir_path := ""
	if gender == "m" and not race_res.sprite_dir_path_m.is_empty():
		dir_path = race_res.sprite_dir_path_m
	elif not race_res.sprite_dir_path_f.is_empty():
		dir_path = race_res.sprite_dir_path_f

	var idle_path := variant if not variant.is_empty() else dir_path

	_sprite.position = Vector2(0.0, -8.0)
	if not dir_path.is_empty():
		_sprite.sprite_frames = _build_directional_frames(dir_path, idle_path)
	else:
		var walk_tex_path: String = race_res.walk_tex_path
		var idle_tex_path: String = race_res.idle_tex_path
		if walk_tex_path.is_empty():
			return
		var frames := DirectionAnimator.build_4dir_frames(load(walk_tex_path), 16, 4, 8.0, "walk")
		if not idle_tex_path.is_empty():
			DirectionAnimator.build_4dir_frames(load(idle_tex_path), 16, 1, 1.0, "idle", frames)
		_sprite.sprite_frames = frames

	_sprite.play("idle_down")
	_current_anim = "idle_down"


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_target_pos, _lerp_speed * delta)


func update_state(pos: Vector2, anim: String, flip: bool) -> void:
	_target_pos    = pos
	_sprite.flip_h = flip
	if anim != _current_anim:
		_current_anim = anim
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim):
			_sprite.play(anim)


# ── Directional frames (mismo formato que player.gd) ─────────────────────────

func _build_directional_frames(walk_base: String, idle_base: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var dir_map := {"down": "south", "up": "north", "left": "west", "right": "east"}

	for dir: String in ["down", "up", "left", "right"]:
		var dname: String = dir_map[dir]
		var walk_anim := "walk_" + dir
		frames.add_animation(walk_anim)
		frames.set_animation_speed(walk_anim, 8.0)
		frames.set_animation_loop(walk_anim, true)

		# Intentar cargar frames de animación
		var loaded := false
		for fi: int in 8:
			var p := "%s/animations/walking/%s/frame_%03d.png" % [walk_base, dname, fi]
			if not ResourceLoader.exists(p):
				break
			frames.add_frame(walk_anim, load(p))
			loaded = true

		# Si no hay animación de walking, usar la rotación estática
		if not loaded:
			var rot_path := "%s/rotations/%s.png" % [walk_base, dname]
			if ResourceLoader.exists(rot_path):
				frames.add_frame(walk_anim, load(rot_path))

		# Idle: usar la variante pre-coloreada (idle_base) si existe, si no usar walk_base
		var idle_anim := "idle_" + dir
		frames.add_animation(idle_anim)
		frames.set_animation_speed(idle_anim, 1.0)
		frames.set_animation_loop(idle_anim, true)
		var idle_rot := "%s/rotations/%s.png" % [idle_base, dname]
		if ResourceLoader.exists(idle_rot):
			frames.add_frame(idle_anim, load(idle_rot))
		else:
			# Fallback: primer frame del walk
			if frames.get_frame_count(walk_anim) > 0:
				frames.add_frame(idle_anim, frames.get_frame_texture(walk_anim, 0))

	return frames
