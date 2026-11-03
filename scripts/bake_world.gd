@tool
extends EditorScript

## Genera y guarda en world.tscn TODOS los tiles del mapa y asigna los TileSet.
##
## Cómo usarlo (ejecutar UNA SOLA VEZ):
##   1. Abre world.tscn en el editor de Godot.
##   2. Abre este archivo en el editor de scripts.
##   3. Pulsa ▶ (Ejecutar) en la barra de herramientas del editor de scripts.
##   4. Guarda la escena con Ctrl+S.
##   Después puedes editar los tiles a mano en el editor de TileMap.
##
## ADVERTENCIA: Sobreescribe los datos actuales de todos los TileMapLayer.

# ── Carpeta de tilesets ──────────────────────────────────────────────────────
const DIR       := "res://resources/tilesets/"
const T_FLOOR   := DIR + "floor_tileset.tres"
const T_NATURE  := DIR + "nature_tileset.tres"
const T_PATH    := DIR + "path_tileset.tres"
const T_BUILD   := DIR + "building_tileset.tres"
const T_CFLOOR  := DIR + "city_floor_tileset.tres"
const T_CBUILD  := DIR + "city_building_tileset.tres"
const T_CWALL   := DIR + "cave_wall_tileset.tres"
const T_CFLR    := DIR + "cave_floor_tileset.tres"

# ── Texturas ─────────────────────────────────────────────────────────────────
const A_FIELD   := "res://assets/Backgrounds/Tilesets/TilesetField.png"
const A_NATURE  := "res://assets/Backgrounds/Tilesets/TilesetNature.png"
const A_FLOORX  := "res://assets/Backgrounds/Tilesets/TilesetFloor.png"
const A_HOUSE   := "res://assets/Backgrounds/Tilesets/TilesetHouse.png"
const A_VILLAGE := "res://assets/Backgrounds/Tilesets/TilesetVillageAbandoned.png"
const A_TT      := "res://assets/kenney/kenney_tiny-town/Tilemap/tilemap_packed.png"
const A_TD      := "res://assets/kenney/kenney_tiny-dungeon/Tilemap/tilemap_packed.png"

# ── Tiles clave ───────────────────────────────────────────────────────────────
const GRASS_TILE      := Vector2i(1, 4)   # TilesetField col1 fila4 — pasto interior
const CAVE_WALL_TILE  := Vector2i(0, 0)   # TD col0 fila0 — roca oscura (con colisión)
const CAVE_FLOOR_TILE := Vector2i(0, 1)   # TD col0 fila1 — piedra clara (sin colisión)
const CITY_ADO_TILE   := Vector2i(0, 8)   # TT col0 fila8 — adoquín gris sólido

# ── Geometría del mapa ────────────────────────────────────────────────────────
const MAP_W   := 40
const MAP_H   := 25
const CAVE_OX := 250   # 4000 / 16  (offset en tiles para la cueva)
const CAVE_W  := 40
const CAVE_H  := 30

const SQ_BITS := [0, 3, 4, 7, 8, 11, 12, 15]   # CellNeighbor válidos en grid cuadrada


# ─────────────────────────────────────────────────────────────────────────────
func _run() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or root.name != "World":
		printerr("[BakeWorld] Abre world.tscn antes de ejecutar este script.")
		return

	var fl  := root.get_node_or_null("FloorLayer")    as TileMapLayer
	var nl  := root.get_node_or_null("NatureLayer")   as TileMapLayer
	var pl  := root.get_node_or_null("PathLayer")     as TileMapLayer
	var bl  := root.get_node_or_null("BuildingLayer") as TileMapLayer
	var cfl := root.get_node_or_null("CityFloorLayer")    as TileMapLayer
	var cbl := root.get_node_or_null("CityBuildingLayer") as TileMapLayer
	var cwl := root.get_node_or_null("CaveWallLayer")  as TileMapLayer
	var cfll:= root.get_node_or_null("CaveFloorLayer") as TileMapLayer

	if fl == null or cwl == null:
		printerr("[BakeWorld] No se encontraron todos los TileMapLayer.")
		return

	# Crear carpeta si no existe
	var dir := DirAccess.open("res://resources")
	if dir and not dir.dir_exists("tilesets"):
		dir.make_dir("tilesets")

	# ── 1. Crear y asignar tilesets ──────────────────────────────────────────
	fl.tile_set   = _make_floor_ts()
	nl.tile_set   = _make_nature_ts()
	pl.tile_set   = _make_path_ts()
	bl.tile_set   = _make_building_ts()
	cfl.tile_set  = _make_city_floor_ts()
	cbl.tile_set  = _make_city_build_ts()
	cwl.tile_set  = _make_cave_wall_ts()
	cfll.tile_set = _make_cave_floor_ts()

	# ── 2. Generar tiles de suelo principal (40×25 pasto) ─────────────────────
	fl.clear()
	for y: int in MAP_H:
		for x: int in MAP_W:
			fl.set_cell(Vector2i(x, y), 0, GRASS_TILE)

	# ── 3. Generar tiles de ciudad ────────────────────────────────────────────
	cfl.clear()
	cbl.clear()
	_bake_city(cfl, cbl)

	# ── 4. Generar tiles de cueva (perímetro + salas + túneles) ───────────────
	cwl.clear()
	cfll.clear()
	_bake_cave(cwl, cfll)

	get_editor_interface().mark_scene_as_unsaved()
	print("[BakeWorld] ✓ Mapa generado. Guarda con Ctrl+S.")


# ─── Tilesets ─────────────────────────────────────────────────────────────────

func _make_floor_ts() -> TileSet:
	if ResourceLoader.exists(T_FLOOR):
		return load(T_FLOOR)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0); ts.set_terrain_name(0, 0, "Pasto")
	ts.set_terrain_color(0, 0, Color(0.35, 0.72, 0.18))
	ts.add_terrain(0); ts.set_terrain_name(0, 1, "Arena")
	ts.set_terrain_color(0, 1, Color(0.90, 0.62, 0.30))
	var src := _atlas_src(ts, A_FIELD)
	_fill_atlas(src, 5, 15)                # TilesetField.png: 5 cols × 15 filas
	_set_terrain(src, GRASS_TILE, 0, 0)    # pasto interior
	_set_terrain(src, Vector2i(1, 1), 0, 1)  # arena interior
	ResourceSaver.save(ts, T_FLOOR)
	return ts


func _make_nature_ts() -> TileSet:
	if ResourceLoader.exists(T_NATURE):
		return load(T_NATURE)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := _atlas_src(ts, A_NATURE)
	_fill_atlas(src, 24, 21)               # TilesetNature.png: 24 cols × 21 filas
	_full_coll(src.get_tile_data(Vector2i(0, 10), 0))  # arbusto standalone
	ResourceSaver.save(ts, T_NATURE)
	return ts


func _make_path_ts() -> TileSet:
	if ResourceLoader.exists(T_PATH):
		return load(T_PATH)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0); ts.set_terrain_name(0, 0, "Tierra")
	ts.set_terrain_color(0, 0, Color(0.74, 0.47, 0.35))
	var src := _atlas_src(ts, A_FLOORX)
	_fill_atlas(src, 22, 26)               # TilesetFloor.png: 22 cols × 26 filas
	_set_terrain(src, Vector2i(1, 7), 0, 0)   # tierra marrón interior
	ResourceSaver.save(ts, T_PATH)
	return ts


func _make_building_ts() -> TileSet:
	if ResourceLoader.exists(T_BUILD):
		return load(T_BUILD)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src_h := _atlas_src(ts, A_HOUSE,   0)   # source 0: TilesetHouse.png
	var src_v := _atlas_src(ts, A_VILLAGE, 1)   # source 1: TilesetVillageAbandoned.png
	_fill_atlas(src_h, 33, 23)
	_fill_atlas(src_v, 20, 12)
	# Colisiones se añaden a mano en el editor (Inspector del .tres → Physics).
	ResourceSaver.save(ts, T_BUILD)
	return ts


func _make_city_floor_ts() -> TileSet:
	if ResourceLoader.exists(T_CFLOOR):
		return load(T_CFLOOR)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0); ts.set_terrain_name(0, 0, "Adoquín")
	ts.set_terrain_color(0, 0, Color(0.58, 0.58, 0.62))
	var src := _atlas_src(ts, A_TT)
	_fill_atlas(src, 12, 11)
	_set_terrain(src, CITY_ADO_TILE, 0, 0)
	ResourceSaver.save(ts, T_CFLOOR)
	return ts


func _make_city_build_ts() -> TileSet:
	if ResourceLoader.exists(T_CBUILD):
		return load(T_CBUILD)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := _atlas_src(ts, A_TT)
	_fill_atlas(src, 12, 11)
	# Paredes casa naranja (cols 0-2, fila 6)
	for c: int in range(0, 3):
		_full_coll(src.get_tile_data(Vector2i(c, 6), 0))
	# Paredes casa gris (cols 4-6, fila 8)
	for c: int in range(4, 7):
		_full_coll(src.get_tile_data(Vector2i(c, 8), 0))
	# Vallas (cols 4-7, fila 6)
	for c: int in range(4, 8):
		_full_coll(src.get_tile_data(Vector2i(c, 6), 0))
	# Árbol standalone: colisión solo en el tronco (mitad inferior)
	var td_tree: TileData = src.get_tile_data(Vector2i(3, 0), 0)
	var trunk := PackedVector2Array([
		Vector2(-4.0, 0.0), Vector2(4.0, 0.0), Vector2(4.0, 8.0), Vector2(-4.0, 8.0)
	])
	td_tree.set_collision_polygons_count(0, 1)
	td_tree.set_collision_polygon_points(0, 0, trunk)
	# Muralla (filas 9-10, cols 0-5)
	for c: int in range(0, 6):
		_full_coll(src.get_tile_data(Vector2i(c, 9), 0))
		_full_coll(src.get_tile_data(Vector2i(c, 10), 0))
	ResourceSaver.save(ts, T_CBUILD)
	return ts


func _make_cave_wall_ts() -> TileSet:
	if ResourceLoader.exists(T_CWALL):
		return load(T_CWALL)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := _atlas_src(ts, A_TD)
	_fill_atlas(src, 12, 11)
	# Solo CAVE_WALL_TILE (0,0) tiene colisión; el resto son decoración.
	_full_coll(src.get_tile_data(CAVE_WALL_TILE, 0))
	ResourceSaver.save(ts, T_CWALL)
	return ts


func _make_cave_floor_ts() -> TileSet:
	if ResourceLoader.exists(T_CFLR):
		return load(T_CFLR)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := _atlas_src(ts, A_TD)
	_fill_atlas(src, 12, 11)
	ResourceSaver.save(ts, T_CFLR)
	return ts


# ─── Generación de tiles ──────────────────────────────────────────────────────

func _bake_city(cfl: TileMapLayer, cbl: TileMapLayer) -> void:
	# Casa naranja: techo ladrillo | cumbrera ▽ | pared con puerta
	_place_house(cbl, Vector2i(1, 1),
		[Vector2i(4,4), Vector2i(4,4), Vector2i(4,4)],
		[Vector2i(4,5), Vector2i(7,5), Vector2i(6,5)],
		[Vector2i(0,6), Vector2i(1,6), Vector2i(2,6)])
	# Casa gris: techo azul-gris | cumbrera ▽ | pared piedra
	_place_house(cbl, Vector2i(6, 1),
		[Vector2i(0,4), Vector2i(0,4), Vector2i(0,4)],
		[Vector2i(0,5), Vector2i(3,5), Vector2i(2,5)],
		[Vector2i(4,8), Vector2i(5,8), Vector2i(6,8)])
	# Adoquín frente a las casas (fila 4)
	for x: int in 10:
		cfl.set_cell(Vector2i(x, 4), 0, CITY_ADO_TILE)
	# Árboles decorativos
	cbl.set_cell(Vector2i(0, 2), 0, Vector2i(3, 0))
	cbl.set_cell(Vector2i(9, 2), 0, Vector2i(3, 0))


func _place_house(layer: TileMapLayer, origin: Vector2i,
		roof: Array, gable: Array, wall: Array) -> void:
	for i: int in 3:
		layer.set_cell(origin + Vector2i(i, 0), 0, roof[i])
		layer.set_cell(origin + Vector2i(i, 1), 0, gable[i])
		layer.set_cell(origin + Vector2i(i, 2), 0, wall[i])


func _bake_cave(wl: TileMapLayer, fl: TileMapLayer) -> void:
	# Paso 1: rellenar todo con roca (perímetro + interior)
	for y: int in CAVE_H:
		for x: int in CAVE_W:
			wl.set_cell(Vector2i(CAVE_OX + x, y), 0, CAVE_WALL_TILE)

	# Paso 2: tallar áreas transitables
	#
	#  Mapa de la cueva (40×30 tiles, coordenadas locales):
	#
	#   col:  0    5    10   15   20   25   30   35   39
	#   fila:
	#    0   ████████████████████████████████████████████
	#    2   █    ┌──R5 Sala Secreta──┐                 █
	#    7   █ ┌DE1┐  T4  ┌──R2──────┤  ┌────DE2──────┐█
	#    9   █ │   │      │ Explorad.│  │  Alcoba NE   ││█
	#   12   █ ┌───R3 Caverna Oeste──┘  │  (sin salida)││█
	#   14   █ │                    T1  └──────T5───────┘█
	#   16   █ │                    │       ┌──R4 Este──┐ █
	#   17   █ │               ┌───R1 Entr.─┤           │ █
	#   19   █ └────T2──────────┤            └───────────┘ █
	#   24   █                  │ ← jugador llega aquí     █
	#   27   █                  └──[BOCA SALIDA]           █
	#   29   ████████████████████████████████████████████
	#
	var rects: Array[Rect2i] = [
		Rect2i(14, 17, 12, 11),  # R1 - Sala de Entrada        cols 14-25, filas 17-27
		Rect2i( 8,  9,  9,  6),  # R2 - Sala del Explorador    cols  8-16, filas  9-14
		Rect2i( 1, 12,  9, 12),  # R3 - Caverna Oeste          cols  1- 9, filas 12-23
		Rect2i(29, 16,  9, 11),  # R4 - Alcoba Este            cols 29-37, filas 16-26
		Rect2i( 5,  2,  9,  5),  # R5 - Sala Secreta           cols  5-13, filas  2- 6  (sin salida)
		Rect2i(15, 15,  3,  2),  # T1 - R1 ↔ R2 (norte, 3 tiles ancho)
		Rect2i(10, 19,  4,  3),  # T2 - R3 ↔ R1 (oeste-este,  4 tiles ancho)
		Rect2i(26, 19,  3,  3),  # T3 - R1 ↔ R4 (este,        3 tiles ancho)
		Rect2i( 9,  7,  3,  2),  # T4 - R5 ↔ R2 (norte-sur,   3 tiles ancho)
		Rect2i(33, 14,  3,  2),  # T5 - R4 ↔ DE2 (norte,      3 tiles ancho)
		Rect2i( 1,  7,  4,  5),  # DE1 - alcoba NO             cols  1- 4, filas  7-11  (sin salida)
		Rect2i(33,  8,  5,  6),  # DE2 - alcoba NE             cols 33-37, filas  8-13  (sin salida)
	]

	for r: Rect2i in rects:
		for dy: int in r.size.y:
			for dx: int in r.size.x:
				var wx := CAVE_OX + r.position.x + dx
				var wy := r.position.y + dy
				wl.erase_cell(Vector2i(wx, wy))
				fl.set_cell(Vector2i(wx, wy), 0, CAVE_FLOOR_TILE)


# ─── Helpers ──────────────────────────────────────────────────────────────────

# Crea un TileSetAtlasSource con la textura dada y lo añade al TileSet.
func _atlas_src(ts: TileSet, tex_path: String, src_id: int = 0) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(tex_path)
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, src_id)
	return src


# Crea todos los tiles en la rejilla del atlas (para que el editor los muestre).
func _fill_atlas(src: TileSetAtlasSource, cols: int, rows: int) -> void:
	for row: int in rows:
		for col: int in cols:
			if not src.has_tile(Vector2i(col, row)):
				src.create_tile(Vector2i(col, row))


# Asigna bits de terrain a un tile (el tile ya debe existir en el atlas).
func _set_terrain(src: TileSetAtlasSource, coords: Vector2i,
		ts_idx: int, t_idx: int) -> void:
	var td: TileData = src.get_tile_data(coords, 0)
	td.terrain_set = ts_idx
	td.terrain     = t_idx
	for bit: int in SQ_BITS:
		td.set_terrain_peering_bit(bit, t_idx)


# Polígono de colisión cuadrado completo para un tile 16×16.
func _full_coll(td: TileData) -> void:
	if td == null:
		return
	var poly := PackedVector2Array([
		Vector2(-8.0, -8.0), Vector2(8.0, -8.0),
		Vector2(8.0,  8.0),  Vector2(-8.0, 8.0),
	])
	td.set_collision_polygons_count(0, 1)
	td.set_collision_polygon_points(0, 0, poly)
