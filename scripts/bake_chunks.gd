## Convierte un PNG de Pixelorama en escenas de chunk 64×64 en scenes/chunks/.
## Uso: abrir world.tscn → Script Editor → File → Open → este script → ▶
## Cambiar MAP_PATH al archivo que se quiere procesar.
@tool
extends EditorScript

const MAP_PATH   := "res://assets/maps/world_400x400.png"
const CHUNK_SIZE := 64
const TILE_PX    := 16
const CHUNK_DIR  := "res://scenes/chunks/"
const DATA_PATH  := "res://resources/world_data.json"

# Tilesets existentes en resources/
const TS_PATH_FL := "res://resources/path_tileset.tres"
const TS_CITY_FL := "res://resources/city_floor_tileset.tres"
const TS_CAVE_WL := "res://resources/cave_wall_tileset.tres"
const TS_BUILDING := "res://resources/city_building_tileset.tres"
# Tilesets que bake_chunks crea si no existen
const TS_FLOOR   := "res://resources/floor_tileset.tres"
const TS_NATURE  := "res://resources/nature_tileset.tres"
# Tileset de terrenos con transiciones (creado por setup_tilesets.gd)
const TS_TERRAIN := "res://resources/world_terrain_tileset.tres"

# Paleta (hex sin #)
const GRASS      := "4caf50"
const FOREST     := "1b5e20"
const PINK_GRASS := "f48fb1"
const PINK_FOR   := "ad1457"
const SNOW       := "ffffff"
const ROCK       := "757575"
const SAND       := "ffb74d"
const DARK_GRASS := "556b2f"
const WATER      := "2196f3"
const DIRT_ROAD  := "8d6e63"
const STONE_ST   := "b0bec5"
const WALL       := "000000"
const HOUSE      := "f44336"
const DOOR       := "ff9800"
const CAVE       := "9c27b0"
const SPAWN      := "ffeb3b"
const POI        := "00bcd4"

# Tile coords
# FloorLayer source 0 (TilesetField.png 5×15): interior = col 1, fila central
const _FL_GRASS      := Vector2i(1, 4)
const _FL_SAND       := Vector2i(1, 1)
const _FL_DARK       := Vector2i(1, 7)   # ← VERIFICAR en TilesetField.png
const _FL_PINK       := Vector2i(1, 10)  # ← VERIFICAR
const _FL_SNOW       := Vector2i(1, 13)  # ← VERIFICAR
# PathLayer source 0 (TilesetFloor.png)
const _PA_DIRT       := Vector2i(1, 7)
# StreetLayer source 0 (TinyTown 12×11): adoquín gris confirmado en CLAUDE.md
const _ST_ADO        := Vector2i(0, 8)
# NatureLayer source 0 (TilesetNature.png 24×21)
const _NA_BUSH_GRN   := Vector2i(2, 9)   # arbusto verde (confirmado standalone)
const _NA_BUSH_PINK  := Vector2i(5, 9)   # arbusto rosa ← VERIFICAR
const _NA_ROCK       := Vector2i(15, 8)  # roca (filas 6-10, cols 15-23) ← VERIFICAR
# WallLayer source 0 (TinyDungeon 12×11)
const _WA_WALL       := Vector2i(0, 0)   # roca con colisión (confirmado)

var _img:     Image
var _W:       int
var _H:       int
var _houses:  Array  = []   # [{rect, door_dir}]
var _markers: Dictionary = {"spawn": [], "cave": [], "poi": []}
var _palette: Dictionary = {}   # int_key → {fl, pa, st, na, wa, walkable, marker}

# Hashes de colores con terrain connect (precalculados en _build_palette)
var _hk_grass:  int
var _hk_forest: int
var _hk_water:  int
var _hk_dark:   int


func _run() -> void:
	print("[BakeChunks] Iniciando…  MAP_PATH=", MAP_PATH)
	var abs_path := ProjectSettings.globalize_path(MAP_PATH)
	if not FileAccess.file_exists(abs_path):
		printerr("[BakeChunks] Archivo no encontrado: ", abs_path)
		return

	_img = Image.load_from_file(abs_path)
	if _img == null:
		printerr("[BakeChunks] Error cargando imagen: ", abs_path)
		return
	_W = _img.get_width()
	_H = _img.get_height()
	print("[BakeChunks] Imagen cargada: %d×%d px" % [_W, _H])

	_build_palette()

	if not _validate():
		return

	_detect_houses_and_markers()

	var ts_fl := _get_or_create_floor_ts()
	var ts_pa := load(TS_PATH_FL) as TileSet
	var ts_st := load(TS_CITY_FL) as TileSet
	var ts_na := _get_or_create_nature_ts()
	var ts_wa := load(TS_CAVE_WL) as TileSet
	var ts_bu := load(TS_BUILDING) as TileSet
	var ts_terrain: TileSet = null
	if FileAccess.file_exists(ProjectSettings.globalize_path(TS_TERRAIN)):
		ts_terrain = load(TS_TERRAIN)
	else:
		push_warning("[BakeChunks] world_terrain_tileset.tres no existe. Ejecutar setup_tilesets.gd primero.")

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(CHUNK_DIR))

	var ncx := ceili(float(_W) / float(CHUNK_SIZE))
	var ncy := ceili(float(_H) / float(CHUNK_SIZE))
	var count := 0

	for cy: int in ncy:
		for cx: int in ncx:
			_bake_chunk(cx, cy, ts_fl, ts_pa, ts_st, ts_na, ts_wa, ts_bu, ts_terrain)
			count += 1

	_save_world_data(ncx, ncy)
	print("[BakeChunks] ✓ %d chunks (%d×%d), %d casas" % [
		count, ncx, ncy, _houses.size()])
	print("[BakeChunks] Mapa: %d×%d tiles  |  spawn: %s  |  cuevas: %s" % [
		_W, _H, _markers.spawn, _markers.cave])


# ─── Paleta ───────────────────────────────────────────────────────────────────

func _build_palette() -> void:
	# Precalcular hashes de terrenos con terrain connect
	_hk_grass  = _hk(GRASS)
	_hk_forest = _hk(FOREST)
	_hk_water  = _hk(WATER)
	_hk_dark   = _hk(DARK_GRASS)

	# Cada entrada: "fl"=floor, "pa"=path, "st"=street, "na"=nature, "wa"=wall
	# Grass, Forest, Water, Dark_Grass NO tienen "fl": los maneja TerrainLayer
	_palette = {
		_hk(GRASS):      {},                            # → TerrainLayer (set 0, terrain 0)
		_hk(FOREST):     {"na": _NA_BUSH_GRN},          # → TerrainLayer + arbustos
		_hk(PINK_GRASS): {"fl": _FL_PINK},
		_hk(PINK_FOR):   {"fl": _FL_PINK, "na": _NA_BUSH_PINK},
		_hk(SNOW):       {"fl": _FL_SNOW},
		_hk(ROCK):       {"fl": _FL_SNOW, "na": _NA_ROCK},
		_hk(SAND):       {"fl": _FL_SAND},
		_hk(DARK_GRASS): {},                            # → TerrainLayer (set 1, terrain 1)
		_hk(WATER):      {"wa": _WA_WALL},              # → TerrainLayer visual + wall colisión
		_hk(DIRT_ROAD):  {"fl": _FL_GRASS, "pa": _PA_DIRT},
		_hk(STONE_ST):   {"fl": _FL_GRASS, "st": _ST_ADO},
		_hk(WALL):       {"wa": _WA_WALL},
		_hk(HOUSE):      {},
		_hk(DOOR):       {},
		_hk(CAVE):       {"fl": _FL_GRASS, "marker": "cave"},
		_hk(SPAWN):      {"fl": _FL_GRASS, "marker": "spawn"},
		_hk(POI):        {"fl": _FL_GRASS, "marker": "poi"},
	}


func _validate() -> bool:
	var errors: Dictionary = {}
	for y: int in _H:
		for x: int in _W:
			var k := _pk(x, y)
			if not _palette.has(k):
				if not errors.has(k): errors[k] = []
				if errors[k].size() < 3: errors[k].append(Vector2i(x, y))
	if errors.is_empty(): return true
	printerr("[BakeChunks] Colores desconocidos (detener):")
	for k in errors:
		printerr("  #%06x  en: %s" % [k, errors[k]])
	return false


# ─── Casas y marcadores ───────────────────────────────────────────────────────

func _detect_houses_and_markers() -> void:
	var house_k := _hk(HOUSE)
	var door_k  := _hk(DOOR)
	var visited: Dictionary = {}

	for y: int in _H:
		for x: int in _W:
			var pk := _pk(x, y)
			if pk == _hk(CAVE):
				_markers.cave.append({"x": x * TILE_PX, "y": y * TILE_PX})
			elif pk == _hk(SPAWN):
				_markers.spawn.append({"x": x * TILE_PX, "y": y * TILE_PX})
			elif pk == _hk(POI):
				_markers.poi.append({"x": x * TILE_PX, "y": y * TILE_PX})

			if pk != house_k or visited.has(Vector2i(x, y)):
				continue

			# Flood-fill grupo de casa
			var group: Array[Vector2i] = []
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			while not queue.is_empty():
				var cur: Vector2i = queue.pop_front()
				if visited.has(cur): continue
				visited[cur] = true
				group.append(cur)
				for nb: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nxt := cur + nb
					if nxt.x >= 0 and nxt.x < _W and nxt.y >= 0 and nxt.y < _H:
						if not visited.has(nxt) and _pk(nxt.x, nxt.y) == house_k:
							queue.append(nxt)

			# Bounding rect
			var mn: Vector2i = group[0]; var mx: Vector2i = group[0]
			for p: Vector2i in group:
				mn.x = mini(mn.x, p.x); mn.y = mini(mn.y, p.y)
				mx.x = maxi(mx.x, p.x); mx.y = maxi(mx.y, p.y)
			var rect := Rect2i(mn.x, mn.y, mx.x - mn.x + 1, mx.y - mn.y + 1)

			# Buscar puerta adyacente
			var door_dir := "south"
			for p: Vector2i in group:
				for nb: Vector2i in [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]:
					var np := p + nb
					if np.x < 0 or np.x >= _W or np.y < 0 or np.y >= _H: continue
					if _pk(np.x, np.y) != door_k: continue
					if np.y > mx.y:   door_dir = "south"
					elif np.y < mn.y: door_dir = "north"
					elif np.x > mx.x: door_dir = "east"
					else:             door_dir = "west"
			_houses.append({"rect": rect, "door_dir": door_dir})


# ─── Bake chunk individual ────────────────────────────────────────────────────

func _bake_chunk(cx: int, cy: int,
		ts_fl: TileSet, ts_pa: TileSet, ts_st: TileSet,
		ts_na: TileSet, ts_wa: TileSet, ts_bu: TileSet,
		ts_terrain: TileSet) -> void:

	var start := Vector2i(cx * CHUNK_SIZE, cy * CHUNK_SIZE)
	var end   := Vector2i(mini(start.x + CHUNK_SIZE, _W), mini(start.y + CHUNK_SIZE, _H))
	if start.x >= _W or start.y >= _H: return

	var root := Node2D.new()
	root.name = "Chunk"
	root.set_script(load("res://scripts/chunk.gd"))
	root.set("chunk_x", cx)
	root.set("chunk_y", cy)

	# TerrainLayer va primero (más abajo en el stack)
	var ter: TileMapLayer = null
	if ts_terrain != null:
		ter = _make_layer(root, "TerrainLayer", ts_terrain)
		ter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var fl := _make_layer(root, "FloorLayer",    ts_fl)
	var pa := _make_layer(root, "PathLayer",     ts_pa)
	var st := _make_layer(root, "StreetLayer",   ts_st)
	var na := _make_layer(root, "NatureLayer",   ts_na, true)
	var wa := _make_layer(root, "WallLayer",     ts_wa)
	var bu := _make_layer(root, "BuildingLayer", ts_bu, true)

	# Colecciones para terrain connect
	var tc0a: Array[Vector2i] = []  # pasto   (set 0, terrain 0)
	var tc0b: Array[Vector2i] = []  # bosque  (set 0, terrain 1)
	var tc1a: Array[Vector2i] = []  # agua    (set 1, terrain 0)
	var tc1b: Array[Vector2i] = []  # pantano (set 1, terrain 1)

	var has_stone := false

	for py: int in range(start.y, end.y):
		for px: int in range(start.x, end.x):
			var lp  := Vector2i(px - start.x, py - start.y)
			var key := _pk(px, py)

			# Terrain connect
			if ts_terrain != null:
				if   key == _hk_grass:  tc0a.append(lp)
				elif key == _hk_forest: tc0b.append(lp)
				elif key == _hk_water:  tc1a.append(lp)
				elif key == _hk_dark:   tc1b.append(lp)

			var info: Dictionary = _palette.get(key, {})
			if info.is_empty(): continue
			if info.has("fl"): fl.set_cell(lp, 0, info["fl"])
			if info.has("pa"): pa.set_cell(lp, 0, info["pa"])
			if info.has("st"):
				st.set_cell(lp, 0, info["st"])
				has_stone = true
			if info.has("na"): na.set_cell(lp, 0, info["na"])
			if info.has("wa"): wa.set_cell(lp, 0, info["wa"])

	# Aplicar terrain connect (grass→forest y water→swamp con transiciones automáticas)
	if ter != null:
		if not tc0a.is_empty(): ter.set_cells_terrain_connect(tc0a, 0, 0)
		if not tc0b.is_empty(): ter.set_cells_terrain_connect(tc0b, 0, 1)
		if not tc1a.is_empty(): ter.set_cells_terrain_connect(tc1a, 1, 0)
		if not tc1b.is_empty(): ter.set_cells_terrain_connect(tc1b, 1, 1)

	# Casas que se solapan con este chunk
	for i: int in _houses.size():
		var house: Dictionary = _houses[i]
		var rect: Rect2i  = house.rect
		var chunk_rect := Rect2i(start.x, start.y, end.x - start.x, end.y - start.y)
		if not rect.intersects(chunk_rect): continue
		var ov := rect.intersection(chunk_rect)
		for hy: int in range(ov.position.y, ov.position.y + ov.size.y):
			for hx: int in range(ov.position.x, ov.position.x + ov.size.x):
				var lp := Vector2i(hx - start.x, hy - start.y)
				fl.set_cell(lp, 0, _FL_GRASS)
				st.set_cell(lp, 0, _ST_ADO)
				has_stone = true
		# Puerta: tile adyacente a la casa en la dirección correcta
		_place_door_tile(house, start, fl, st)
		# Edificio: tiles de paredes/techo Tiny Town
		_place_building_tiles(house, i, start, bu)

	root.set("has_safe_zone", has_stone)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed,
		CHUNK_DIR + "chunk_0_%d_%d.tscn" % [cx, cy])
	if err != OK:
		printerr("[BakeChunks] Error guardando chunk %d,%d: %d" % [cx, cy, err])
	root.free()


func _place_building_tiles(house: Dictionary, house_idx: int,
		start: Vector2i, bu: TileMapLayer) -> void:
	var rect: Rect2i  = house.rect
	var is_orange: bool = house_idx % 2 == 0

	# TinyTown: casa naranja = cols 0-2 / gris = cols 4-6
	var roof_tile := Vector2i(4, 4) if is_orange else Vector2i(0, 4)
	var ridge_l   := Vector2i(4, 5) if is_orange else Vector2i(0, 5)
	var ridge_m   := Vector2i(7, 5) if is_orange else Vector2i(3, 5)
	var ridge_r   := Vector2i(6, 5) if is_orange else Vector2i(2, 5)
	var wall_l    := Vector2i(0, 6) if is_orange else Vector2i(4, 6)
	var wall_m    := Vector2i(1, 6) if is_orange else Vector2i(5, 6)
	var wall_r    := Vector2i(2, 6) if is_orange else Vector2i(6, 6)

	var w: int = rect.size.x
	var h: int = rect.size.y

	for hy: int in h:
		for hx: int in w:
			var world_tile := Vector2i(rect.position.x + hx, rect.position.y + hy)
			var lp := Vector2i(world_tile.x - start.x, world_tile.y - start.y)
			if lp.x < 0 or lp.x >= CHUNK_SIZE or lp.y < 0 or lp.y >= CHUNK_SIZE:
				continue
			var col := 0 if hx == 0 else (2 if hx == w - 1 else 1)
			if hy == 0:
				bu.set_cell(lp, 0, roof_tile)
			elif hy == 1 and h > 2:
				bu.set_cell(lp, 0, [ridge_l, ridge_m, ridge_r][col])
			else:
				bu.set_cell(lp, 0, [wall_l, wall_m, wall_r][col])


func _place_door_tile(house: Dictionary, start: Vector2i,
		fl: TileMapLayer, st: TileMapLayer) -> void:
	var rect: Rect2i = house.rect
	var door_tile: Vector2i
	match house.door_dir:
		"south": door_tile = Vector2i(rect.position.x + rect.size.x / 2, rect.end.y)
		"north": door_tile = Vector2i(rect.position.x + rect.size.x / 2, rect.position.y - 1)
		"east":  door_tile = Vector2i(rect.end.x, rect.position.y + rect.size.y / 2)
		"west":  door_tile = Vector2i(rect.position.x - 1, rect.position.y + rect.size.y / 2)

	var lp := Vector2i(door_tile.x - start.x, door_tile.y - start.y)
	if lp.x < 0 or lp.x >= CHUNK_SIZE or lp.y < 0 or lp.y >= CHUNK_SIZE:
		return
	fl.set_cell(lp, 0, _FL_GRASS)
	st.set_cell(lp, 0, _ST_ADO)


# ─── Tilesets ─────────────────────────────────────────────────────────────────

func _make_layer(parent: Node2D, layer_name: String, ts: TileSet,
		y_sort: bool = false, _collision: bool = false) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name     = layer_name
	layer.tile_set = ts
	if y_sort:
		layer.y_sort_enabled = true
	# La capa de colisión la configura el TileSet (physics_layer), no el nodo.
	parent.add_child(layer)
	layer.owner = parent
	return layer


func _get_or_create_floor_ts() -> TileSet:
	if FileAccess.file_exists(ProjectSettings.globalize_path(TS_FLOOR)):
		return load(TS_FLOOR)
	var ts  := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/Backgrounds/Tilesets/TilesetField.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	for atlas: Vector2i in [_FL_GRASS, _FL_SAND, _FL_DARK, _FL_PINK, _FL_SNOW]:
		src.create_tile(atlas)
	ResourceSaver.save(ts, TS_FLOOR)
	print("[BakeChunks] Creado: ", TS_FLOOR)
	return ts


func _get_or_create_nature_ts() -> TileSet:
	if FileAccess.file_exists(ProjectSettings.globalize_path(TS_NATURE)):
		return load(TS_NATURE)
	var ts  := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/Backgrounds/Tilesets/TilesetNature.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	for atlas: Vector2i in [_NA_BUSH_GRN, _NA_BUSH_PINK, _NA_ROCK]:
		src.create_tile(atlas)
	ResourceSaver.save(ts, TS_NATURE)
	print("[BakeChunks] Creado: ", TS_NATURE)
	return ts


# ─── World data ───────────────────────────────────────────────────────────────

func _save_world_data(ncx: int, ncy: int) -> void:
	var houses_out: Array = []
	for h: Dictionary in _houses:
		var r: Rect2i = h.rect
		houses_out.append({
			"bounds": {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y},
			"door_dir": h.door_dir
		})

	var data := {
		"world_size": {"chunks_x": ncx, "chunks_y": ncy, "tiles_w": _W, "tiles_h": _H},
		"chunk_size": CHUNK_SIZE,
		"tile_px":    TILE_PX,
		"markers":    _markers,
		"houses":     houses_out,
	}

	var f := FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if f == null:
		printerr("[BakeChunks] No se pudo escribir world_data.json")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("[BakeChunks] Guardado: ", DATA_PATH)


# ─── Utilidades ───────────────────────────────────────────────────────────────

func _hk(hex: String) -> int:
	# Color.html() parsea hex de forma fiable; mismo método que _pk()
	var c := Color.html(hex)
	return (roundi(c.r * 255) << 16) | (roundi(c.g * 255) << 8) | roundi(c.b * 255)


func _pk(x: int, y: int) -> int:
	var c := _img.get_pixel(x, y)
	return (roundi(c.r * 255) << 16) | (roundi(c.g * 255) << 8) | roundi(c.b * 255)
