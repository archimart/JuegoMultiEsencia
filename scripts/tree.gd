extends Node2D

enum TreeState { ALIVE, STUMP }

const NATURE_TEX    := "res://assets/Backgrounds/Tilesets/TilesetNature.png"
const TREE_REGION   := Rect2(0, 0, 32, 31)
const STUMP_REGION  := Rect2(0, 134, 32, 23)
const WOOD_PER_CHOP := 2
const REGROW_TIME   := 60.0     # segundos hasta que el árbol vuelve a crecer
const REGROW_RETRY  := 5.0      # si hay jugador encima, reintentar en 5 s

# @export permite que el servidor fije el estado directamente en multijugador
@export var state: TreeState = TreeState.ALIVE

@onready var _sprite:    Sprite2D         = $Sprite2D
@onready var _col_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var _area:      Area2D           = $Area2D

var _player:       Node2D = null
var _regrow_timer: float  = 0.0


func _ready() -> void:
	_sprite.texture        = load(NATURE_TEX)
	_sprite.region_enabled = true
	_sprite.centered       = true
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_apply_state()


# ─── Estado ────────────────────────────────────────────────────────────────────

func _set_state(new_state: TreeState) -> void:
	state = new_state
	_apply_state()
	# Punto de extensión multijugador: añadir @rpc("authority") aquí para sincronizar.
	# Clientes solo llaman _apply_state(); el servidor llama _set_state() y lo replica.


func _apply_state() -> void:
	match state:
		TreeState.ALIVE:
			_sprite.region_rect = TREE_REGION
			_sprite.offset      = Vector2(0, -16)
			_sprite.scale       = Vector2.ONE
			_col_shape.disabled = false
			set_process(false)
			# Animación de crecimiento (también usada al regenerar)
			_sprite.scale = Vector2(0.15, 0.15)
			var tw := create_tween()
			tw.tween_property(_sprite, "scale", Vector2.ONE, 0.35) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		TreeState.STUMP:
			_sprite.region_rect = STUMP_REGION
			_sprite.offset      = Vector2(0, -12)
			_sprite.scale       = Vector2.ONE
			_col_shape.disabled = true     # el jugador puede caminar sobre el tocón
			_regrow_timer       = REGROW_TIME
			set_process(true)


# ─── Proceso de regeneración ───────────────────────────────────────────────────

func _process(delta: float) -> void:
	_regrow_timer -= delta
	if _regrow_timer <= 0.0:
		_try_regrow()


func _try_regrow() -> void:
	# No regenerar si hay un jugador encima del tocón
	if _player != null:
		_regrow_timer = REGROW_RETRY
		return
	_set_state(TreeState.ALIVE)


# ─── Interacción ───────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if state != TreeState.ALIVE or _player == null:
		return
	if event.is_action_pressed("interact"):
		_chop()


func _chop() -> void:
	if _player.has_method("collect_item"):
		_player.collect_item("wood", WOOD_PER_CHOP)
	_set_state(TreeState.STUMP)
	FX.particles(global_position, "chop")
	SFX.play("chop")
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.5, 0.4, 0.4), 0.07)
	tw.tween_property(_sprite, "modulate", Color.WHITE,           0.09)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
