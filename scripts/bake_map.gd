## Convierte un PNG (cada píxel = 1 tile) en tiles en world.tscn.
## Uso: abre world.tscn → Script Editor → ▶
## El PNG va en res://assets/maps/world_map.png
## Para probar usa primero gen_test_map.gd y ajusta MAP_PATH a la ruta del test.
@tool
extends EditorScript

const MAP_PATH := "res://assets/maps/world_map.png"

# ── Tilesets guardados ────────────────────────────────────────────────────────
const DIR_TS  := "res://resources/tilesets/"
const TS_FL   := DIR_TS + "map_floor.tres"
const TS_PL   := DIR_TS + "map_path.tres"
const TS_NL   := DIR_TS + "map_nature.tres"
const TS_WL   := DIR_TS + "map_wall.tres"
const TS_BL   := DIR_TS + "map_build.tres"

# ── Texturas ─────────────────────────────────────────────────────────────────
const A_FIELD := "res://assets/Backgrounds/Tilesets/TilesetField.png"
const A_FLOOR := "res://assets/Backgrounds/Tilesets/TilesetFloor.png"
const A_NAT   := "res://assets/Backgrounds/Tilesets/TilesetNature.png"
const A_TT    := "res://assets/kenney/kenney_tiny-town/Tilemap/tilemap_packed.png"
const A_TD    := "res://assets/kenney/kenney_tiny-dungeon/Tilemap/tilemap_packed.png"

# ── Coordenadas en FloorLayer (src 0 = TilesetField 5×15, src 1 = TilesetFloor 22×26) ──
# Confirmados en bake_world.gd:
const TF_GRASS      := [0, Vector2i(1,  4)]
const TF_SAND       := [0, Vector2i(1,  1)]
const TF_DIRT_BG    := [0, Vector2i(1,  4)]  # fondo bajo camino tierra (mismo pasto)
# Estimados — verificar en el editor ajustando estas constantes:
const TF_SNOW       := [1, Vector2i(1, 11)]  # ← VERIFICAR fila nieve en TilesetFloor
const TF_DARK_GRASS := [1, Vector2i(1, 15)]  # ← VERIFICAR fila pasto oscuro
const TF_PINK_GRASS := [1, Vector2i(12, 2)]  # ← VERIFICAR mitad derecha TilesetFloor

# ── PathLayer (src 0 = TilesetFloor, src 1 = TinyTown 12×11) ─────────────────
# Confirmados:
const TP_DIRT  := [0, Vector2i(1, 7)]   # tierra marrón
const TP_STONE := [1, Vector2i(0, 8)]   # adoquín gris

# ── WallLayer  (src 0 = TinyDungeon 12×11, colisión) ─────────────────────────
const TW_WALL  := [0, Vector2i(0, 0)]   # roca oscura (confirmado)
const TW_WATER := [0, Vector2i(3, 8)]   # ← VERIFICAR tile agua en TinyDungeon

# ── NatureLayer (src 0 = TilesetNature 24×21, decorativo) ────────────────────
const TN_TREE_GREEN := [0, Vector2i(0, 0)]  # ← VERIFICAR árbol verde
const TN_TREE_PINK  := [0, Vector2i(3, 0)]  # ← VERIFICAR árbol rosa
const TN_TREE_SNOW  := [0, Vector2i(2, 0)]  # ← VERIFICAR árbol nevado
const TN_ROCK_ORE   := [0, Vector2i(14,2)]  # ← VERIFICAR roca mineral

# ── BuildingLayer TinyTown (src 0 = TinyTown 12×11, colisión en paredes) ─────
# Casa naranja (de bake_world.gd, confirmado):
const HOUSE_ROOF  := [Vector2i(4,4), Vector2i(4,4), Vector2i(4,4)]
const HOUSE_GABLE := [Vector2i(4,5), Vector2i(7,5), Vector2i(6,5)]
const HOUSE_WALL  := [Vector2i(0,6), Vector2i(1,6), Vector2i(2,6)]

# Densidades de objetos naturales (1 por cada N tiles de ese tipo)
const TREE_DENSITY := 5
const ORE_DENSITY  := 8

# Margen de zona segura alrededor de las calles de piedra (en tiles)
const SAFE_MARGIN := 3

const SQ_BITS := [0, 3, 4, 7, 8, 11, 12, 15]


# ─────────────────────────────────────────────────────────────────────────────
func _run() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or root.name != "World":
		printerr("[BakeMap] Abre world.tscn antes de ejecutar."); return

	# Obtener (o crear) capas
	var fl  := _get_layer(root, "FloorLayer");    if fl  == null: return
	var pl  := _get_layer(root, "PathLayer");     if pl  == null: return
	var nl  := _get_layer(root, "NatureLayer");   if nl  == null: return
	var bl  := _get_layer(root, "BuildingLayer"); if bl  == null: return
	var wl  := _get_or_add_layer(root, "WallLayer", 1)  # capa 1 = mundo

	# Cargar imagen
	if not FileAccess.file_exists(MAP_PATH):
		printerr("[BakeMap] No se encontró %s" % MAP_PATH)
		printerr("[BakeMap] Ejecuta gen_test_map.gd para crear el mapa de prueba.")
		return

	var img := Image.load_from_file(ProjectSettings.globalize_path(MAP_PATH))
	if img == null:
		printerr("[BakeMap] Error al cargar la imagen."); return

	var W: int = img.get_width()
	var H: int = img.get_height()

	# ── Fase 1: validar colores ───────────────────────────────────────────────
	var palette := _build_palette()
	var unknowns: Dictionary = {}
	for y: int in H:
		for x: int in W:
			var k := _pk(img, x, y)
			if not palette.has(k):
				var hex := _key_to_hex(k)
				unknowns[hex] = unknowns.get(hex, [])
				if (unknowns[hex] as Array).size() < 3:
					(unknowns[hex] as Array).append(Vector2i(x, y))
	if not unknowns.is_empty():
		printerr("[BakeMap] Colores desconocidos en el PNG (máx. 3 coords por color):")
		for hex: String in unknowns:
			printerr("  #%s → %s" % [hex.to_upper(), unknowns[hex]])
		return

	# ── Fase 2: crear tilesets ────────────────────────────────────────────────
	_ensure_dir(DIR_TS)
	fl.tile_set = _make_floor_ts()
	pl.tile_set = _make_path_ts()
	nl.tile_set = _make_nature_ts()
	wl.tile_set = _make_wall_ts()
	bl.tile_set = _make_build_ts()

	# ── Fase 3: limpiar capas ─────────────────────────────────────────────────
	fl.clear(); pl.clear(); nl.clear(); bl.clear(); wl.clear()

	# ── Fase 4: colocar tiles ─────────────────────────────────────────────────
	var region_map:   Dictionary = {}   # Vector2i → String (nombre de región)
	var house_pixels: Dictionary = {}   # Vector2i → true
	var door_pixels:  Dictionary = {}   # Vector2i → true
	var markers:      Dictionary = {}   # tipo → Array[Vector2i]

	for y: int in H:
		for x: int in W:
			var pos  := Vector2i(x, y)
			var k    := _pk(img, x, y)
			var info: Dictionary = palette[k]

			match info.get("type", ""):
				"terrain":
					_place_terrain(fl, nl, pos, info, region_map)
				"road":
					_place_road(pl, fl, pos, info, region_map)
				"block":
					_place_block(wl, pos, info, region_map)
				"house":
					house_pixels[pos] = true
					region_map[pos]   = "pueblo"
				"door":
					door_pixels[pos] = true
				"cave", "spawn", "poi":
					var t: String = info.type
					if not markers.has(t):
						markers[t] = []
					(markers[t] as Array).append(pos)
					# Colocar pasto bajo el marcador para que no quede vacío
					fl.set_cell(pos, 0, TF_GRASS[1])

	# ── Fase 5: casas ─────────────────────────────────────────────────────────
	_process_houses(fl, bl, house_pixels, door_pixels)

	# ── Fase 6: zona segura ───────────────────────────────────────────────────
	var safe_tiles := _calc_safe_zone(pl, SAFE_MARGIN)

	# ── Fase 7: guardar datos de región ──────────────────────────────────────
	_save_world_data(region_map, markers, safe_tiles, W, H)

	get_editor_interface().mark_scene_as_unsaved()
	print("[BakeMap] ✓ %d×%d tiles. %d regiones. %d tiles seguros. Guarda con Ctrl+S." \
			% [W, H, region_map.size(), safe_tiles.size()])


# ─── Paleta ───────────────────────────────────────────────────────────────────
func _build_palette() -> Dictionary:
	# type:     terrain | road | block | house | door | cave | spawn | poi
	# region:   nombre de región para spawners
	# walkable: bool
	# floor:    [src, Vector2i] para FloorLayer  (terrain y road)
	# nature:   [src, Vector2i] para NatureLayer  (decorativo)
	# resource: "tree" | "ore" | null
	# density:  int (1 de cada N tiles se convierte en recurso)
	return {
		_hk("4CAF50"): {type="terrain", region="pradera",  walkable=true,  floor=TF_GRASS,      nature=null,          resource=null},
		_hk("1B5E20"): {type="terrain", region="pradera",  walkable=true,  floor=TF_GRASS,      nature=TN_TREE_GREEN, resource="tree",  density=TREE_DENSITY},
		_hk("F48FB1"): {type="terrain", region="elfico",   walkable=true,  floor=TF_PINK_GRASS, nature=null,          resource=null},
		_hk("AD1457"): {type="terrain", region="elfico",   walkable=true,  floor=TF_PINK_GRASS, nature=TN_TREE_PINK,  resource="tree",  density=TREE_DENSITY},
		_hk("FFFFFF"): {type="terrain", region="montaña",  walkable=true,  floor=TF_SNOW,       nature=null,          resource=null},
		_hk("757575"): {type="terrain", region="montaña",  walkable=true,  floor=TF_SNOW,       nature=TN_ROCK_ORE,   resource="ore",   density=ORE_DENSITY},
		_hk("FFB74D"): {type="terrain", region="arida",    walkable=true,  floor=TF_SAND,       nature=null,          resource=null},
		_hk("556B2F"): {type="terrain", region="pantano",  walkable=true,  floor=TF_DARK_GRASS, nature=null,          resource=null},
		_hk("2196F3"): {type="block",   region="comun",    walkable=false, wall=TW_WATER},
		_hk("8D6E63"): {type="road",    region="comun",    walkable=true,  path=TP_DIRT,        floor_bg=TF_DIRT_BG},
		_hk("B0BEC5"): {type="road",    region="pueblo",   walkable=true,  path=TP_STONE,       floor_bg=TF_GRASS},
		_hk("000000"): {type="block",   region="comun",    walkable=false, wall=TW_WALL},
		_hk("F44336"): {type="house",   region="pueblo",   walkable=false},
		_hk("FF9800"): {type="door",    region="pueblo",   walkable=true},
		_hk("9C27B0"): {type="cave",    region="comun",    walkable=true},
		_hk("FFEB3B"): {type="spawn",   region="comun",    walkable=true},
		_hk("00BCD4"): {type="poi",     region="comun",    walkable=true},
	}


# ─── Colocación de tiles ──────────────────────────────────────────────────────

func _place_terrain(fl: TileMapLayer, nl: TileMapLayer,
		pos: Vector2i, info: Dictionary, region_map: Dictionary) -> void:
	region_map[pos] = info.region
	var f: Array = info.floor
	fl.set_cell(pos, f[0], f[1])

	# Recurso natural (árbol, roca) según densidad
	if info.nature != null and info.has("density"):
		if _hash_pos(pos) % int(info.density) == 0:
			var n: Array = info.nature
			nl.set_cell(pos, n[0], n[1])


func _place_road(pl: TileMapLayer, fl: TileMapLayer,
		pos: Vector2i, info: Dictionary, region_map: Dictionary) -> void:
	region_map[pos] = info.region
	# Fondo de suelo bajo el camino (para que no haya huecos si el camino es transparente)
	if info.has("floor_bg"):
		var fb: Array = info.floor_bg
		fl.set_cell(pos, fb[0], fb[1])
	var p: Array = info.path
	pl.set_cell(pos, p[0], p[1])


func _place_block(wl: TileMapLayer,
		pos: Vector2i, info: Dictionary, region_map: Dictionary) -> void:
	region_map[pos] = info.region
	var w: Array = info.wall
	wl.set_cell(pos, w[0], w[1])


# ─── Casas ────────────────────────────────────────────────────────────────────

func _process_houses(fl: TileMapLayer, bl: TileMapLayer,
		house_pixels: Dictionary, door_pixels: Dictionary) -> void:
	var visited: Dictionary = {}

	for start: Variant in house_pixels:
		var start_pos: Vector2i = start
		if visited.has(start_pos): continue

		# Flood-fill para encontrar el rectángulo de esta casa
		var group: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start_pos]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_back()
			if visited.has(cur): continue
			visited[cur] = true
			group.append(cur)
			for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var nb: Vector2i = cur + d
				if house_pixels.has(nb) and not visited.has(nb):
					queue.append(nb)

		# Bounding rect del grupo
		var min_x: int = group[0].x; var max_x: int = group[0].x
		var min_y: int = group[0].y; var max_y: int = group[0].y
		for p: Vector2i in group:
			if p.x < min_x: min_x = p.x
			if p.x > max_x: max_x = p.x
			if p.y < min_y: min_y = p.y
			if p.y > max_y: max_y = p.y

		# Buscar puerta dentro del grupo o en el borde del rect
		var door_pos := Vector2i(-1, -1)
		var orientation := "south"  # por defecto
		for p: Vector2i in group:
			if door_pixels.has(p):
				door_pos = p
				break

		if door_pos != Vector2i(-1, -1):
			if door_pos.y == max_y: orientation = "south"
			elif door_pos.y == min_y: orientation = "north"
			elif door_pos.x == min_x: orientation = "west"
			elif door_pos.x == max_x: orientation = "east"

		# Colocar tiles de casa (actualmente solo orientación sur, 3 tiles de ancho)
		_place_house_south(fl, bl, Vector2i(min_x, min_y), max_x - min_x + 1, max_y - min_y + 1)


func _place_house_south(fl: TileMapLayer, bl: TileMapLayer,
		origin: Vector2i, w: int, h: int) -> void:
	# Fondo de pasto bajo la casa
	for dy: int in h:
		for dx: int in w:
			fl.set_cell(origin + Vector2i(dx, dy), 0, TF_GRASS[1])

	# Tiles de casa de TinyTown (3 columnas confirmadas de bake_world.gd)
	# Si la casa es más ancha, repetir el tile central de techo
	for dx: int in w:
		var col_idx: int = clampi(dx, 0, 2)  # 0=izq, 1=centro, 2=der
		if dx > 0 and dx < w - 1: col_idx = 1
		elif dx == w - 1 and w > 1: col_idx = 2

		# Fila 0: techo
		bl.set_cell(origin + Vector2i(dx, 0), 0, HOUSE_ROOF[col_idx])
		# Filas intermedias: cumbrera repetida
		for dy: int in range(1, h - 1):
			bl.set_cell(origin + Vector2i(dx, dy), 0, HOUSE_GABLE[col_idx])
		# Última fila: pared con puerta
		if h > 1:
			bl.set_cell(origin + Vector2i(dx, h - 1), 0, HOUSE_WALL[col_idx])
		else:
			bl.set_cell(origin + Vector2i(dx, 0), 0, HOUSE_WALL[col_idx])


# ─── Zona segura ──────────────────────────────────────────────────────────────

func _calc_safe_zone(pl: TileMapLayer, margin: int) -> Dictionary:
	# Recoger tiles de calle de piedra
	var seeds: Array[Vector2i] = []
	for cell: Vector2i in pl.get_used_cells():
		if pl.get_cell_source_id(cell) == TP_STONE[0] \
				and pl.get_cell_atlas_coords(cell) == TP_STONE[1]:
			seeds.append(cell)

	# BFS expandiendo margin tiles en 4 direcciones
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for s: Vector2i in seeds:
		visited[s] = 0
		frontier.append(s)

	for dist: int in range(1, margin + 1):
		var next: Array[Vector2i] = []
		for pos: Vector2i in frontier:
			for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var nb: Vector2i = pos + d
				if not visited.has(nb):
					visited[nb] = dist
					next.append(nb)
		frontier = next

	return visited


# ─── Guardar datos de región ──────────────────────────────────────────────────

func _save_world_data(region_map: Dictionary, markers: Dictionary,
		safe_tiles: Dictionary, w: int, h: int) -> void:
	var rm: Dictionary = {}
	for k: Variant in region_map:
		var v2: Vector2i = k
		rm["%d,%d" % [v2.x, v2.y]] = region_map[k]

	var safe: Dictionary = {}
	for k: Variant in safe_tiles:
		var v2: Vector2i = k
		safe["%d,%d" % [v2.x, v2.y]] = safe_tiles[k]

	var mk: Dictionary = {}
	for type: String in markers:
		mk[type] = []
		for p: Vector2i in (markers[type] as Array):
			(mk[type] as Array).append({"x": p.x, "y": p.y})

	var data := {
		"map_size": {"w": w, "h": h},
		"tile_size": 16,
		"regions": rm,
		"safe_zone": safe,
		"markers": mk,
	}

	var file := FileAccess.open("res://resources/world_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[BakeMap] Datos guardados en res://resources/world_data.json")


# ─── Tilesets ─────────────────────────────────────────────────────────────────

func _make_floor_ts() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	# Terrain set para auto-conexión de bordes
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	for tname: String in ["Pasto","Arena","Nieve","PastoOscuro","PastoRosa"]:
		ts.add_terrain(0)
		ts.set_terrain_name(0, ts.get_terrains_count(0) - 1, tname)

	# Source 0: TilesetField.png  (5×15)
	var s0 := _atlas(ts, A_FIELD, 0); _fill_atlas(s0, 5, 15)
	_set_terrain(s0, TF_GRASS[1],      0, 0)   # Pasto
	_set_terrain(s0, TF_SAND[1],       0, 1)   # Arena

	# Source 1: TilesetFloor.png (22×26)
	var s1 := _atlas(ts, A_FLOOR, 1); _fill_atlas(s1, 22, 26)
	_set_terrain(s1, TF_SNOW[1],       0, 2)   # Nieve
	_set_terrain(s1, TF_DARK_GRASS[1], 0, 3)   # PastoOscuro
	_set_terrain(s1, TF_PINK_GRASS[1], 0, 4)   # PastoRosa

	ResourceSaver.save(ts, TS_FL)
	return ts


func _make_path_ts() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0); ts.set_terrain_name(0, 0, "Tierra")
	ts.add_terrain(0); ts.set_terrain_name(0, 1, "Adoquin")

	# Source 0: TilesetFloor.png
	var s0 := _atlas(ts, A_FLOOR, 0); _fill_atlas(s0, 22, 26)
	_set_terrain(s0, TP_DIRT[1], 0, 0)

	# Source 1: TinyTown
	var s1 := _atlas(ts, A_TT, 1); _fill_atlas(s1, 12, 11)
	_set_terrain(s1, TP_STONE[1], 0, 1)

	ResourceSaver.save(ts, TS_PL)
	return ts


func _make_nature_ts() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	# Sin capa de física: los árboles y rocas son decorativos aquí;
	# la colisión se maneja en sus escenas instanciadas (tree.tscn, ore_node.tscn).
	var s0 := _atlas(ts, A_NAT, 0); _fill_atlas(s0, 24, 21)
	ResourceSaver.save(ts, TS_NL)
	return ts


func _make_wall_ts() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	# Source 0: TinyDungeon (muros y agua como bloqueo)
	var s0 := _atlas(ts, A_TD, 0); _fill_atlas(s0, 12, 11)
	_full_coll(s0.get_tile_data(TW_WALL[1],  0))
	_full_coll(s0.get_tile_data(TW_WATER[1], 0))

	ResourceSaver.save(ts, TS_WL)
	return ts


func _make_build_ts() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var s0 := _atlas(ts, A_TT, 0); _fill_atlas(s0, 12, 11)
	# Colisión en tiles de pared (filas 6 y 9-10 de TinyTown)
	for c: int in range(0, 3):
		_full_coll(s0.get_tile_data(Vector2i(c, 6), 0))  # pared naranja
	for c: int in range(0, 6):
		_full_coll(s0.get_tile_data(Vector2i(c, 9), 0))  # muralla
		_full_coll(s0.get_tile_data(Vector2i(c,10), 0))

	ResourceSaver.save(ts, TS_BL)
	return ts


# ─── Helpers generales ────────────────────────────────────────────────────────

func _get_layer(root: Node, name: String) -> TileMapLayer:
	var n := root.get_node_or_null(name) as TileMapLayer
	if n == null:
		printerr("[BakeMap] No se encontró %s en world.tscn" % name)
	return n


func _get_or_add_layer(root: Node, layer_name: String, col_layer: int) -> TileMapLayer:
	var n := root.get_node_or_null(layer_name) as TileMapLayer
	if n != null:
		return n
	n = TileMapLayer.new()
	n.name            = layer_name
	n.collision_layer = col_layer
	n.collision_mask  = 0
	root.add_child(n, true)
	n.owner = root
	print("[BakeMap] Añadida nueva capa: %s" % layer_name)
	return n


func _ensure_dir(path: String) -> void:
	var abs := ProjectSettings.globalize_path(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)


func _hk(hex: String) -> int:
	var h := hex.to_lower().trim_prefix("#")
	return (h.substr(0,2).hex_to_int() << 16) \
		 | (h.substr(2,2).hex_to_int() <<  8) \
		 |  h.substr(4,2).hex_to_int()


func _key_to_hex(k: int) -> String:
	return "%06x" % k


func _pk(img: Image, x: int, y: int) -> int:
	var c := img.get_pixel(x, y)
	return (roundi(c.r * 255) << 16) \
		 | (roundi(c.g * 255) <<  8) \
		 |  roundi(c.b * 255)


func _hash_pos(pos: Vector2i) -> int:
	return abs(pos.x * 2654435761 ^ pos.y * 2246822519) & 0x7FFFFFFF


func _atlas(ts: TileSet, tex_path: String, src_id: int) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(tex_path)
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, src_id)
	return src


func _fill_atlas(src: TileSetAtlasSource, cols: int, rows: int) -> void:
	for row: int in rows:
		for col: int in cols:
			if not src.has_tile(Vector2i(col, row)):
				src.create_tile(Vector2i(col, row))


func _set_terrain(src: TileSetAtlasSource, coords: Vector2i,
		ts_idx: int, t_idx: int) -> void:
	var td: TileData = src.get_tile_data(coords, 0)
	if td == null: return
	td.terrain_set = ts_idx
	td.terrain     = t_idx
	for bit: int in SQ_BITS:
		td.set_terrain_peering_bit(bit, t_idx)


func _full_coll(td: TileData) -> void:
	if td == null: return
	var poly := PackedVector2Array([
		Vector2(-8,-8), Vector2(8,-8), Vector2(8,8), Vector2(-8,8),
	])
	td.set_collision_polygons_count(0, 1)
	td.set_collision_polygon_points(0, 0, poly)
