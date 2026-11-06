extends CharacterBody2D

const SHEET := "res://assets/Actor/Character/Noble/SpriteSheet.png"
const SHEET_COLS := 4
const SHEET_ROWS := 1
const FRAME_W    := 16
const FRAME_H    := 16

@onready var _sprite: Sprite2D        = $Sprite2D
@onready var _area:   Area2D          = $Area2D
@onready var _lbl:    Label           = $Label

var _player:    Node2D        = null
var _menu_open: bool          = false
var _shop_scene: PackedScene  = preload("res://scenes/shop_menu.tscn")


func _ready() -> void:
	var tex: Texture2D = load(SHEET)
	_sprite.texture    = tex
	_sprite.hframes    = SHEET_COLS
	_sprite.vframes    = SHEET_ROWS
	_sprite.frame      = 0          # cara al sur
	_sprite.centered   = false
	_sprite.offset     = Vector2(0.0, -FRAME_H)

	var shape := CircleShape2D.new()
	shape.radius = 20.0
	$Area2D/CollisionShape2D.shape = shape

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_lbl.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _menu_open:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_shop()


func _open_shop() -> void:
	_menu_open = true
	var menu: Node = _shop_scene.instantiate()
	menu.setup(_player)
	menu.closed.connect(func() -> void: _menu_open = false)
	get_tree().current_scene.add_child(menu)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		_lbl.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_lbl.visible = false
