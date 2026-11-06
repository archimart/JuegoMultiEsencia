extends Node2D

const ANVIL_TEX := "res://assets/Items/Tool/Anvil.png"

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area:   Area2D   = $Area2D

var _player:    Node2D        = null
var _menu_open: bool          = false
var _menu_scene: PackedScene  = preload("res://scenes/crafting_menu.tscn")
var _recipes:   Array[RecipeData] = []


func _ready() -> void:
	_sprite.texture  = load(ANVIL_TEX)
	_sprite.centered = true
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_load_recipes()


func _load_recipes() -> void:
	var bow: RecipeData           = load("res://resources/recipe_bow.tres")
	var arrows: RecipeData        = load("res://resources/recipe_arrows.tres")
	var iron_ingot: RecipeData    = load("res://resources/recipe_iron_ingot.tres")
	var iron_sword: RecipeData    = load("res://resources/recipe_iron_sword.tres")
	var pickaxe: RecipeData       = load("res://resources/recipe_pickaxe.tres")
	var health_potion: RecipeData = load("res://resources/recipe_health_potion.tres")
	_recipes = [bow, arrows, iron_ingot, iron_sword, pickaxe, health_potion]


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _menu_open:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_menu()


func _open_menu() -> void:
	_menu_open = true
	var menu: Node = _menu_scene.instantiate()
	menu.setup(_player, _recipes)
	menu.closed.connect(func() -> void: _menu_open = false)
	get_tree().current_scene.add_child(menu)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
