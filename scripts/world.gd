extends Node2D

# TilesetField.png: 16×16 tiles, 5 cols × 15 filas
const GRASS_TILE := Vector2i(1, 1)

# TilesetNature.png: 16×16 tiles, 24 cols × 21 filas
const TREE_TILE  := Vector2i(1, 0)
const ROCK_TILE  := Vector2i(18, 4)

const MAP_W := 40
const MAP_H := 25

# Posiciones (en tiles) de los árboles interactivos que se pueden talar
const INTERACTIVE_TREES: Array[Vector2i] = [
	Vector2i(8, 6), Vector2i(12, 5), Vector2i(15, 8),
	Vector2i(9, 14), Vector2i(20, 6), Vector2i(25, 10),
	Vector2i(30, 7), Vector2i(28, 16), Vector2i(18, 18),
	Vector2i(10, 19), Vector2i(33, 12), Vector2i(22, 3),
]

@onready var _floor:   TileMapLayer = $FloorLayer
@onready var _nature:  TileMapLayer = $NatureLayer
@onready var _player:  Node2D       = $Player
@onready var _companion              = $Companion

var _tree_scene: PackedScene = preload("res://scenes/tree.tscn")
var _hud_scene:  PackedScene = preload("res://scenes/hud.tscn")


func _ready() -> void:
	_register_input_actions()
	_setup_floor_tileset()
	_setup_nature_tileset()
	_generate_map()
	_spawn_interactive_trees()
	_spawn_hud()
	_companion.target = _player


func _register_input_actions() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.keycode = KEY_E
		InputMap.action_add_event("interact", ev)


func _setup_floor_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/Backgrounds/Tilesets/TilesetField.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	src.create_tile(GRASS_TILE)
	_floor.tile_set = ts


func _setup_nature_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)

	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/Backgrounds/Tilesets/TilesetNature.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)

	src.create_tile(TREE_TILE)
	_add_full_collision(src.get_tile_data(TREE_TILE, 0))

	src.create_tile(ROCK_TILE)
	_add_full_collision(src.get_tile_data(ROCK_TILE, 0))

	_nature.tile_set = ts


func _add_full_collision(tile_data: TileData) -> void:
	var poly := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, poly)


func _generate_map() -> void:
	for y: int in MAP_H:
		for x: int in MAP_W:
			_floor.set_cell(Vector2i(x, y), 0, GRASS_TILE)

	for x: int in MAP_W:
		_nature.set_cell(Vector2i(x, 0), 0, TREE_TILE)
		_nature.set_cell(Vector2i(x, MAP_H - 1), 0, TREE_TILE)
	for y: int in MAP_H:
		_nature.set_cell(Vector2i(0, y), 0, TREE_TILE)
		_nature.set_cell(Vector2i(MAP_W - 1, y), 0, TREE_TILE)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i: int in 35:
		var x := rng.randi_range(2, MAP_W - 3)
		var y := rng.randi_range(2, MAP_H - 3)
		if x >= 18 and x <= 22 and y >= 10 and y <= 15:
			continue
		# No poner tile estático encima de una posición de árbol interactivo
		if Vector2i(x, y) in INTERACTIVE_TREES:
			continue
		var tile := TREE_TILE if rng.randf() > 0.35 else ROCK_TILE
		_nature.set_cell(Vector2i(x, y), 0, tile)


func _spawn_interactive_trees() -> void:
	for tile_pos: Vector2i in INTERACTIVE_TREES:
		var tree: Node2D = _tree_scene.instantiate()
		# Posición en píxeles: centro del tile
		tree.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
		add_child(tree)


func _spawn_hud() -> void:
	var hud = _hud_scene.instantiate()
	add_child(hud)
	hud.set_player(_player)
