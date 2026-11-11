extends Node2D

@onready var _sprite:  AnimatedSprite2D = $AnimatedSprite2D
@onready var _area:    Area2D           = $InteractArea

var _data:         MountData = null
var _player:       Node2D    = null
var _mounted:      bool      = false
var _player_near:  bool      = false
var _dir_anim  := DirectionAnimator.new()
var _last_dir:     String    = "down"


func setup(data: MountData, player: Node2D) -> void:
	_data   = data
	_player = player
	_build_frames()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func get_speed() -> float:
	return _data.speed if _data != null else 150.0


func update_anim(vel: Vector2, player_dir: String = "") -> void:
	var moving := vel.length_squared() > 25.0
	var prefix := "walk_" if moving else "idle_"
	if not player_dir.is_empty():
		_last_dir = player_dir
		_dir_anim._dir = player_dir
	elif moving:
		_dir_anim.update_velocity(vel)
		_last_dir = _dir_anim.get_dir()
	var dir := _last_dir
	# Cuando va hacia abajo el jabalí queda al frente del jugador
	z_index = 1 if (dir == "down" and _mounted) else 0
	var anim := prefix + dir
	if _sprite.animation != anim:
		_sprite.play(anim)


func mount() -> void:
	_mounted = true
	z_index  = 0
	_player.mount_start(self)


func dismount() -> void:
	_mounted = false
	z_index  = 0
	global_position = _player.global_position + Vector2(32.0, 0.0)
	_player.mount_end()
	update_anim(Vector2.ZERO, _last_dir)


func _on_body_entered(body: Node2D) -> void:
	if body == _player:
		_player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_near = false


func _unhandled_input(event: InputEvent) -> void:
	if not ((_player_near and not _mounted) or _mounted):
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _mounted:
		dismount()
		return
	if _player == null:
		return
	mount()


# ── Construcción de frames (mismo formato que los personajes) ──────────────────

func _build_frames() -> void:
	var base: String = _data.sprite_dir if _data != null else ""
	if base.is_empty():
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	# idle usa la rotación cardinal; walk usa la carpeta disponible más cercana
	var idle_map := {"down": "south", "up": "north", "left": "west",  "right": "east"}
	var walk_map := {"down": "south-east", "up": "north", "left": "west", "right": "north-east"}
	for dir: String in ["down", "up", "left", "right"]:
		var walk_anim := "walk_" + dir
		frames.add_animation(walk_anim)
		frames.set_animation_loop(walk_anim, true)
		var walk_sub := _find_walk_sub(base, walk_map[dir])
		if not walk_sub.is_empty():
			frames.set_animation_speed(walk_anim, 8.0)
			for i: int in 8:
				frames.add_frame(walk_anim, load(walk_sub + "/frame_%03d.png" % i))
		else:
			frames.set_animation_speed(walk_anim, 1.0)
			var rot := _find_idle_frame(base, idle_map[dir])
			if not rot.is_empty():
				frames.add_frame(walk_anim, load(rot))

		var idle_anim := "idle_" + dir
		frames.add_animation(idle_anim)
		frames.set_animation_speed(idle_anim, 1.0)
		frames.set_animation_loop(idle_anim, false)
		var rot := _find_idle_frame(base, idle_map[dir])
		if not rot.is_empty():
			frames.add_frame(idle_anim, load(rot))

	_sprite.sprite_frames = frames
	_sprite.position      = Vector2(0.0, 6.0)
	_sprite.play("idle_down")


func _find_walk_sub(base: String, dname: String) -> String:
	for suffix: String in ["/animations/walking/", "/animations/Walking/"]:
		var p := base + suffix + dname
		if DirAccess.dir_exists_absolute(p):
			return p
	var dir := DirAccess.open(base)
	if dir:
		dir.list_dir_begin()
		var sub := dir.get_next()
		while not sub.is_empty():
			if dir.current_is_dir() and not sub.begins_with("."):
				for suffix: String in ["/animations/walking/", "/animations/Walking/"]:
					var p := base + "/" + sub + suffix + dname
					if DirAccess.dir_exists_absolute(p):
						return p
			sub = dir.get_next()
	return ""


func _find_idle_frame(base: String, dname: String) -> String:
	var direct := base + "/rotations/" + dname + ".png"
	if ResourceLoader.exists(direct):
		return direct
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
