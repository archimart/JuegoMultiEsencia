class_name CityNPC
extends StaticBody2D

@export var npc_name:      String = "NPC"
@export var atlas_region:  Rect2  = Rect2(0, 112, 16, 16)
@export var shop_scene:    String = ""   # ruta .tscn si este NPC abre tienda

const _TD := "res://assets/kenney/kenney_tiny-dungeon/Tilemap/tilemap_packed.png"

var _player:    Node2D = null
var _menu_open: bool   = false
var _hint_lbl:  Label  = null


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 1
	collision_mask  = 0

	var atlas := AtlasTexture.new()
	atlas.atlas  = load(_TD)
	atlas.region = atlas_region
	$Sprite2D.texture = atlas

	var circle := CircleShape2D.new()
	circle.radius = 5.0
	$CollisionShape2D.shape = circle

	if shop_scene != "":
		_setup_interact_area()


func _setup_interact_area() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 2   # capa Jugadores

	var shape_node := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 22.0
	shape_node.shape = circ
	area.add_child(shape_node)
	add_child(area)

	area.body_entered.connect(_on_player_enter)
	area.body_exited.connect(_on_player_exit)

	_hint_lbl = Label.new()
	_hint_lbl.text               = "[E] %s" % npc_name
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 6)
	_hint_lbl.position           = Vector2(-25.0, -18.0)
	_hint_lbl.custom_minimum_size = Vector2(50.0, 0.0)
	_hint_lbl.visible            = false
	add_child(_hint_lbl)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _menu_open or shop_scene == "":
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_shop()


func _open_shop() -> void:
	if not ResourceLoader.exists(shop_scene):
		return
	_menu_open = true
	var packed: PackedScene = load(shop_scene)
	var menu: Node = packed.instantiate()
	if menu.has_method("setup"):
		menu.call("setup", _player)
	if menu.has_signal("closed"):
		menu.closed.connect(func() -> void: _menu_open = false)
	get_tree().current_scene.add_child(menu)


func _on_player_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		if _hint_lbl != null:
			_hint_lbl.visible = true


func _on_player_exit(body: Node2D) -> void:
	if body == _player:
		_player = null
		if _hint_lbl != null:
			_hint_lbl.visible = false
