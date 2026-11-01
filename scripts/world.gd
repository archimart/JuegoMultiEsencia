extends Node2D

# ─── Clasificación de TilesetField.png (80×240 px, 5 cols × 15 filas de 16×16) ──
#   Cada terreno ocupa exactamente 5 columnas × 3 filas.
#   col=1 es el tile INTERIOR SÓLIDO (seguro de usar solo).
#   col=0 y col=2 son bordes izq/der; cols=3-4 son esquinas interiores.
#   → Usar SOLO la columna 1 de cada bloque para relleno de suelo.
#
#   Fila 0-2:  Arena naranja  │  Fila 3-5: PASTO VERDE ← correcto para suelo
#   Fila 6-8:  Pasto oscuro   │  Fila 9-11: Rosa
#   Fila 12-14: Nieve
#
# ─── Clasificación de TilesetNature.png (384×336 px, 24 cols × 21 filas de 16×16) ─
#   STANDALONE SEGUROS (objeto completo en 1 tile, se pueden poner sueltos):
#     Arbustos redondos verdes: fila 9,  cols 2-10
#     Flores amarillas:         fila 10, cols 0-1
#
#   NO STANDALONE (partes de composición multi-tile, NO poner sueltos):
#     Árboles grandes:   filas 0-5,  cols 0-14  (copa 2×3 tiles + tronco)
#     Rocas grandes:     filas 6-10, cols 15-23 (3-4 tiles de ancho)
#     Tocones de árbol:  filas 7-8,  cols 0-3   (2×2 tiles)
#
# ─── TilesetFloor.png (352×417 px, 22 cols × 26 filas de 16×16) ─────────────────
#   Col=10 y col=21 son separadores transparentes; grupos activos: cols 0-9 y 11-20.
#   TERRENOS CONFIRMADOS (col=1 = tile sólido de relleno):
#     Filas  0-4:  Arena naranja   — Vector2i(1, 1)
#     Filas  5-9:  Tierra marrón   — Vector2i(1, 7)  ← Terrain "Tierra" en PathLayer
#     Filas 14-18: Nieve/blanco    — Vector2i(1, 15)
#     Filas 20-24: Agua/hielo cyan — Vector2i(1, 22)
#   Para añadir transiciones suaves tierra↔pasto, configurar los tiles de borde
#   (col=0 es el tile izquierdo del grupo; cols 3-4 son esquinas) en el editor TileSet:
#     Seleccionar tile → pestaña "Terrain" → asignar bits en la rosa de peering.
#
# ─── TilesetHouse.png (528×368 px, 33 cols × 23 filas de 16×16) ────────────────
#   Principal para BuildingLayer. Zonas de referencia:
#     Filas  0-7,  cols  0-15: Fachadas de edificios japoneses (tejados, muros, puertas)
#     Filas  0-4,  cols 17-32: Edificio grande occidental + granero
#     Filas  7-10, cols  0-7:  Cercas y verjas (madera, azul)
#     Filas 10-14, cols  0-10: Estatuas, barriles, pozos, faroles
#     Filas 14-22, cols  0-15: Más edificios y estructuras
#   COLISIONES: en editor → TileSet → seleccionar tile de pared → Physics → dibujar polígono.
#
# ─── TilesetVillageAbandoned.png (320×192 px, 20 cols × 12 filas de 16×16) ─────
#   Source 1 de BuildingLayer. Muros de piedra con musgo (filas 2-6) útiles para
#   decoración de pueblo viejo o zona ruinosa.

# Tile de suelo: col=1 (interior sólido), fila=4 (centro del bloque pasto verde 3-5)
const GRASS_TILE := Vector2i(1, 4)

# Tiles verificados de TilesetNature (para uso manual en el editor o futuro código):
#   Vector2i(0, 10) = arbusto redondo verde (standalone seguro, objeto completo 1×1)
#   Vector2i(3,  9) = pieza de borde naranja/marrón (NO standalone, parte de cliff)

# CellNeighbor válidos para tiles cuadrados con TERRAIN_MODE_MATCH_CORNERS_AND_SIDES.
# El enum TileSet.CellNeighbor tiene 16 valores; los de hex (1,2,5,6,9,10,13,14) son inválidos en square.
const _SQUARE_BITS := [0, 3, 4, 7, 8, 11, 12, 15]  # RIGHT,BR,BOTTOM,BL,LEFT,TL,TOP,TR

const MAP_W := 40
const MAP_H := 25

const INTERACTIVE_TREES: Array[Vector2i] = [
	Vector2i(8, 6),  Vector2i(12, 5),  Vector2i(15, 8),
	Vector2i(9, 14), Vector2i(20, 6),  Vector2i(25, 10),
	Vector2i(30, 7), Vector2i(28, 16), Vector2i(18, 18),
	Vector2i(10, 19), Vector2i(33, 12), Vector2i(22, 3),
]

@onready var _floor:     TileMapLayer = $FloorLayer
@onready var _nature:    TileMapLayer = $NatureLayer
@onready var _path:      TileMapLayer = $PathLayer
@onready var _buildings: TileMapLayer = $BuildingLayer
@onready var _player:    Node2D       = $Player
@onready var _companion               = $Companion

var _tree_scene:      PackedScene = preload("res://scenes/tree.tscn")
var _table_scene:     PackedScene = preload("res://scenes/crafting_table.tscn")
var _chest_scene:     PackedScene = preload("res://scenes/chest.tscn")
var _hud_scene:       PackedScene = preload("res://scenes/hud.tscn")
var _spawner_scene:   PackedScene = preload("res://scenes/spawner.tscn")
var _safe_zone_scene: PackedScene = preload("res://scenes/safe_zone.tscn")


func _ready() -> void:
	if not has_node("/root/FX") or not has_node("/root/SFX"):
		push_error("[World] Autoloads FX/SFX no encontrados. Recarga el proyecto (Project → Reload Current Project).")
	_register_input_actions()
	_setup_floor_tileset()
	_setup_nature_tileset()
	_setup_path_tileset()
	_setup_building_tileset()
	_generate_map()
	_add_border_walls()
	_spawn_interactive_trees()
	_spawn_safe_zone()
	_spawn_crafting_table()
	_spawn_chest()
	_spawn_spawner()
	# Aplicar raza seleccionada (null = arranca directo desde world.tscn en el editor)
	var race = GameState.selected_race
	if race != null:
		_player.setup_race(race)
		_companion.data = race.companion_data
	else:
		_companion.data = preload("res://resources/companion_hawk.tres")
	_spawn_hud()
	_companion.set_target(_player)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F3:
			print_rich("[color=cyan][DEBUG F3] Día/noche: no implementado aún[/color]")
		KEY_F4:
			print_rich("[color=cyan][DEBUG F4] Jefe: no implementado aún[/color]")
		KEY_F5:
			print_rich("[color=cyan][DEBUG F5] Objeto raro: no implementado aún[/color]")
		KEY_F6:
			print_rich("[color=cyan][DEBUG F6] Ataque al pueblo: no implementado aún[/color]")
		KEY_F7:
			_companion.add_xp(10)
			print_rich("[color=cyan][DEBUG F7] +10 XP al compañero[/color]")


func _register_input_actions() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.keycode = KEY_E
		InputMap.action_add_event("interact", ev)

	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", ev)


func _setup_floor_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# Terrain Set 0: permite pintar transiciones pasto↔arena con el pincel de terrain
	# Modo MATCH_CORNERS_AND_SIDES: Godot elige la pieza correcta según los 8 vecinos.
	# Terrain 0 = Pasto verde (TilesetField filas 3-5)
	# Terrain 1 = Arena naranja (TilesetField filas 0-2)
	# Los tiles de borde/esquina se deben configurar en el editor TileSet
	# para que las transiciones funcionen; ver sección "Cómo pintar terrain" al final.
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0)                                # terrain 0 = Pasto
	ts.set_terrain_name(0, 0, "Pasto")
	ts.set_terrain_color(0, 0, Color(0.35, 0.72, 0.18))
	ts.add_terrain(0)                                # terrain 1 = Arena
	ts.set_terrain_name(0, 1, "Arena")
	ts.set_terrain_color(0, 1, Color(0.90, 0.62, 0.30))

	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/Backgrounds/Tilesets/TilesetField.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)

	# Tile interior de pasto: todos los peering bits = terrain 0 (pasto rodeado de pasto)
	src.create_tile(GRASS_TILE)
	var grass_td: TileData = src.get_tile_data(GRASS_TILE, 0)
	grass_td.terrain_set = 0
	grass_td.terrain = 0
	for bit: int in _SQUARE_BITS:
		grass_td.set_terrain_peering_bit(bit, 0)

	# Tile interior de arena: todos los peering bits = terrain 1
	var sand_tile := Vector2i(1, 1)
	src.create_tile(sand_tile)
	var sand_td: TileData = src.get_tile_data(sand_tile, 0)
	sand_td.terrain_set = 0
	sand_td.terrain = 1
	for bit: int in _SQUARE_BITS:
		sand_td.set_terrain_peering_bit(bit, 1)

	_floor.tile_set = ts


func _setup_nature_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/Backgrounds/Tilesets/TilesetNature.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)

	# Tiles verificados standalone (objeto completo 1×1):
	#   (0,10) = arbusto redondo verde — crea tile con colisión para usarlo a mano
	var bush := Vector2i(0, 10)
	src.create_tile(bush)
	_add_full_collision(src.get_tile_data(bush, 0))

	_nature.tile_set = ts


func _add_full_collision(tile_data: TileData) -> void:
	var poly := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, poly)


func _generate_map() -> void:
	# Suelo completo en pasto verde sólido
	for y: int in MAP_H:
		for x: int in MAP_W:
			_floor.set_cell(Vector2i(x, y), 0, GRASS_TILE)
	# La decoración de NatureLayer se coloca a mano en el editor.


func _add_border_walls() -> void:
	# Paredes invisibles en los 4 bordes del mapa: el jugador no puede salir.
	# Reemplazan al antiguo borde de tiles de árbol que usaba piezas multi-tile rotas.
	var body := StaticBody2D.new()
	add_child(body)

	var walls := [
		# [size, position_center]
		[Vector2(MAP_W * 16 + 32, 16), Vector2(MAP_W * 8,      -8)],
		[Vector2(MAP_W * 16 + 32, 16), Vector2(MAP_W * 8,      MAP_H * 16 + 8)],
		[Vector2(16, MAP_H * 16 + 32), Vector2(-8,             MAP_H * 8)],
		[Vector2(16, MAP_H * 16 + 32), Vector2(MAP_W * 16 + 8, MAP_H * 8)],
	]
	for wall: Array in walls:
		var shape := CollisionShape2D.new()
		var rect  := RectangleShape2D.new()
		rect.size      = wall[0]
		shape.position = wall[1]
		shape.shape    = rect
		body.add_child(shape)


func _spawn_interactive_trees() -> void:
	for tile_pos: Vector2i in INTERACTIVE_TREES:
		var tree: Node2D = _tree_scene.instantiate()
		tree.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 8)
		add_child(tree)


func _spawn_safe_zone() -> void:
	var zone: Node2D = _safe_zone_scene.instantiate()
	# Centro geométrico de la zona segura (0,0)-(160,128)
	zone.position = Vector2(80.0, 64.0)
	add_child(zone)


func _spawn_crafting_table() -> void:
	var table: Node2D = _table_scene.instantiate()
	# Tile (5, 4) dentro de la zona segura
	table.position = Vector2(5 * 16 + 8, 4 * 16 + 8)
	add_child(table)


func _spawn_chest() -> void:
	var chest: Node2D = _chest_scene.instantiate()
	# Tile (7, 4) dentro de la zona segura, junto a la mesa de crafteo
	chest.position = Vector2(7 * 16 + 8, 4 * 16 + 8)
	add_child(chest)


func _spawn_spawner() -> void:
	var spawner: Node2D = _spawner_scene.instantiate()
	add_child(spawner)


func _spawn_hud() -> void:
	var hud = _hud_scene.instantiate()
	add_child(hud)
	hud.set_player(_player)
	hud.set_companion(_companion)


func _setup_path_tileset() -> void:
	const SAVE_PATH := "res://resources/path_tileset.tres"
	if ResourceLoader.exists(SAVE_PATH):
		_path.tile_set = load(SAVE_PATH)
		return

	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# Terrain Set 0: Tierra — camino marrón que se pinta sobre el pasto del FloorLayer.
	# Con TERRAIN_MODE_MATCH_CORNERS_AND_SIDES Godot elige la pieza de transición correcta
	# según los 8 vecinos, siempre que esos tiles tengan sus peering bits configurados.
	# De momento solo el tile sólido interior está configurado; para transiciones suaves
	# añadir los tiles de borde en el editor TileSet → pestaña Terrain → rosa de bits,
	# guardar el .tres y el archivo persistirá en las siguientes ejecuciones.
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0)
	ts.set_terrain_name(0, 0, "Tierra")
	ts.set_terrain_color(0, 0, Color(0.74, 0.47, 0.35))

	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/Backgrounds/Tilesets/TilesetFloor.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)

	# Tile sólido de tierra marrón (col=1, fila=7 — confirmado R=189,G=121,B=89).
	# Todos los peering bits = 0 → Godot lo usa cuando el tile está rodeado de tierra.
	_register_terrain_fill_tile(src, Vector2i(1, 7), 0, 0)

	ResourceSaver.save(ts, SAVE_PATH)
	_path.tile_set = ts


func _setup_building_tileset() -> void:
	const SAVE_PATH := "res://resources/building_tileset.tres"
	if ResourceLoader.exists(SAVE_PATH):
		_buildings.tile_set = load(SAVE_PATH)
		return

	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# Capa de física 0: colisiones de paredes de edificios (layer=1 Mundo, mask=0).
	# Para añadir colisión a un tile de pared: abrir resources/building_tileset.tres en el
	# Inspector → seleccionar el tile → pestaña Physics → dibujar polígono de colisión.
	# El archivo .tres persiste entre ejecuciones, así que los cambios no se pierden.
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	# Source 0: TilesetHouse.png — edificios, cercas y decoración de pueblo activo.
	var src_house := TileSetAtlasSource.new()
	src_house.texture = load("res://assets/Backgrounds/Tilesets/TilesetHouse.png")
	src_house.texture_region_size = Vector2i(16, 16)
	ts.add_source(src_house, 0)

	# Source 1: TilesetVillageAbandoned.png — decoración adicional estilo ruinoso.
	var src_village := TileSetAtlasSource.new()
	src_village.texture = load("res://assets/Backgrounds/Tilesets/TilesetVillageAbandoned.png")
	src_village.texture_region_size = Vector2i(16, 16)
	ts.add_source(src_village, 1)

	ResourceSaver.save(ts, SAVE_PATH)
	_buildings.tile_set = ts


func _register_terrain_fill_tile(src: TileSetAtlasSource, coords: Vector2i,
		terrain_set: int, terrain_idx: int) -> void:
	src.create_tile(coords)
	var td: TileData = src.get_tile_data(coords, 0)
	td.terrain_set = terrain_set
	td.terrain     = terrain_idx
	for bit: int in _SQUARE_BITS:
		td.set_terrain_peering_bit(bit, terrain_idx)
