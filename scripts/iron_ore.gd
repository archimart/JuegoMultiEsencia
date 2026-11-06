extends Node2D

enum OreState { INTACT, DEPLETED }

const ORE_TEX       := "res://assets/Objects/IronOre.png"
const DEPLETED_TEX  := "res://assets/Objects/IronOreDepleted.png"
const MINERAL_DROP  := 2       # cantidad de mineral que cae
const REGROW_TIME   := 90.0    # segundos hasta que reaparece
const REGROW_RETRY  := 5.0

@export var state: OreState = OreState.INTACT

@onready var _sprite:    Sprite2D         = $Sprite2D
@onready var _col_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var _area:      Area2D           = $Area2D

var _player:       Node2D = null
var _regrow_timer: float  = 0.0


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_apply_state()


func _set_state(new_state: OreState) -> void:
	state = new_state
	_apply_state()


func _apply_state() -> void:
	match state:
		OreState.INTACT:
			_sprite.texture = load(ORE_TEX)
			_sprite.offset  = Vector2(0, -24)
			_sprite.scale   = Vector2.ONE
			_col_shape.disabled = false
			set_process(false)
			_sprite.scale = Vector2(0.15, 0.15)
			var tw := create_tween()
			tw.tween_property(_sprite, "scale", Vector2.ONE, 0.3) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		OreState.DEPLETED:
			_sprite.texture = load(DEPLETED_TEX)
			_sprite.offset  = Vector2(0, -24)
			_sprite.scale   = Vector2.ONE
			_col_shape.disabled = true
			_regrow_timer = REGROW_TIME
			set_process(true)


func _process(delta: float) -> void:
	_regrow_timer -= delta
	if _regrow_timer <= 0.0:
		_try_regrow()


func _try_regrow() -> void:
	if _player != null:
		_regrow_timer = REGROW_RETRY
		return
	_set_state(OreState.INTACT)


func _unhandled_input(event: InputEvent) -> void:
	if state != OreState.INTACT or _player == null:
		return
	if event.is_action_pressed("interact"):
		_mine()


func _mine() -> void:
	if _player.inventory.get("pickaxe", 0) <= 0:
		if _player.has_signal("notice_requested"):
			_player.notice_requested.emit("Necesitas un pico para minar")
		return
	if _player.has_method("collect_item"):
		_player.collect_item("mineral", MINERAL_DROP)
	_set_state(OreState.DEPLETED)
	FX.particles(global_position + Vector2(0, -16), "mine")
	SFX.play("mine")
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.4, 0.6, 0.3), 0.07)
	tw.tween_property(_sprite, "modulate", Color.WHITE,          0.09)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
