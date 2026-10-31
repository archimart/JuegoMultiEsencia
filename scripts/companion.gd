extends CharacterBody2D

const PARROT_TEX     := "res://assets/Actor/Animal/Parrot/SpriteSheetRed.png"
const FOLLOW_DIST    := 28.0
const SPEED          := 90.0
const FLIP_THRESHOLD := 5.0   # velocidad mínima para cambiar el flip (evita parpadeo)

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: Node2D = null


func _ready() -> void:
	_build_frames()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_target := target.global_position - global_position
	if to_target.length() > FOLLOW_DIST:
		velocity = to_target.normalized() * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * delta * 6.0)
	move_and_slide()

	# Solo voltea el sprite cuando hay movimiento real (sin look_at ni rotation)
	if velocity.length() > FLIP_THRESHOLD:
		_sprite.flip_h = velocity.x < 0.0


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	var tex: Texture2D = load(PARROT_TEX)
	# SpriteSheetRed.png 32×16: columnas = frames de vuelo (2 frames), 1 sola dirección
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
