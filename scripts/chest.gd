extends Node2D

const CHEST_TEX    := "res://assets/Items/Treasure/LittleTreasureChest.png"
const OPEN_TEX     := "res://assets/Items/Treasure/BigTreasureChest.png"
const MENU_SCENE   := "res://scenes/chest_menu.tscn"

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area:   Area2D   = $Area2D

var chest_inventory: Dictionary = {}   # persiste mientras el nodo exista

var _player:    Node2D = null
var _menu_open: bool   = false


func _ready() -> void:
	_sprite.texture  = load(CHEST_TEX)
	_sprite.centered = true
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _menu_open:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_menu()


func _open_menu() -> void:
	_menu_open = true
	_sprite.texture = load(OPEN_TEX)
	var menu: Node = load(MENU_SCENE).instantiate()
	menu.setup(_player, self)
	menu.closed.connect(_on_menu_closed)
	get_tree().current_scene.add_child(menu)


func _on_menu_closed() -> void:
	_menu_open = false
	_sprite.texture = load(CHEST_TEX)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
