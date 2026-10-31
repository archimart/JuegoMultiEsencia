extends CharacterBody2D

signal inventory_changed

const SPEED          := 80.0
const MOVE_THRESHOLD := 8.0          # umbral mínimo de velocidad para cambiar dirección
const WALK_TEX       := "res://assets/Actor/Character/Hunter/SeparateAnim/Walk.png"
const IDLE_TEX       := "res://assets/Actor/Character/Hunter/SeparateAnim/Idle.png"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

# Última dirección válida (se actualiza solo cuando velocity > MOVE_THRESHOLD)
var _last_dir  := Vector2.DOWN
var inventory: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	_build_frames()


func _physics_process(_delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	velocity = input.normalized() * SPEED if input != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

	# Solo actualiza la dirección cuando el personaje realmente se desplaza
	if velocity.length() > MOVE_THRESHOLD:
		_last_dir = velocity.normalized()

	_update_anim()


func collect_item(item: String, amount: int) -> void:
	inventory[item] = inventory.get(item, 0) + amount
	inventory_changed.emit()


func _update_anim() -> void:
	var moving := velocity.length() > MOVE_THRESHOLD
	var dir    := _last_dir
	var prefix := "walk_" if moving else "idle_"

	var suffix: String
	if absf(dir.y) >= absf(dir.x):
		suffix = "up" if dir.y < 0.0 else "down"
	else:
		suffix = "left" if dir.x < 0.0 else "right"

	var anim := prefix + suffix
	if _sprite.animation != anim:
		_sprite.play(anim)


func _build_frames() -> void:
	var frames   := SpriteFrames.new()
	var walk_tex: Texture2D = load(WALK_TEX)
	var idle_tex: Texture2D = load(IDLE_TEX)

	# Walk.png 64×64: COLUMNA = dirección, FILA = frame de animación
	# Orden de columnas confirmado: abajo=0, arriba=1, izquierda=2, derecha=3
	var walk_names := ["walk_down", "walk_up", "walk_left", "walk_right"]
	for dir_col: int in 4:
		frames.add_animation(walk_names[dir_col])
		frames.set_animation_speed(walk_names[dir_col], 8.0)
		frames.set_animation_loop(walk_names[dir_col], true)
		for frame_row: int in 4:
			var a := AtlasTexture.new()
			a.atlas  = walk_tex
			a.region = Rect2(dir_col * 16, frame_row * 16, 16, 16)
			frames.add_frame(walk_names[dir_col], a)

	# Idle.png 64×16: COLUMNA = dirección, 1 sola fila (1 frame por dirección)
	# Mismo orden de columnas: abajo=0, arriba=1, izquierda=2, derecha=3
	var idle_names := ["idle_down", "idle_up", "idle_left", "idle_right"]
	for dir_col: int in 4:
		frames.add_animation(idle_names[dir_col])
		frames.set_animation_speed(idle_names[dir_col], 1.0)
		frames.set_animation_loop(idle_names[dir_col], true)
		var a := AtlasTexture.new()
		a.atlas  = idle_tex
		a.region = Rect2(dir_col * 16, 0, 16, 16)
		frames.add_frame(idle_names[dir_col], a)

	_sprite.sprite_frames = frames
	_sprite.play("idle_down")
