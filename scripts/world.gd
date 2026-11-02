extends Node2D

# ─── Referencia de tiles (para pintar a mano en el editor) ───────────────────
#
# FloorLayer  →  resources/tilesets/floor_tileset.tres  (TilesetField.png, 5×15)
#   Pasto interior:  Vector2i(1, 4)  — Terrain 0 "Pasto"
#   Arena interior:  Vector2i(1, 1)  — Terrain 1 "Arena"
#   Organización: cada terreno = 5 cols × 3 filas; col 1 = tile interior sólido.
#   Filas 0-2 arena | 3-5 pasto | 6-8 pasto oscuro | 9-11 rosa | 12-14 nieve
#
# NatureLayer → resources/tilesets/nature_tileset.tres  (TilesetNature.png, 24×21)
#   STANDALONE SEGUROS (pintar sueltos):
#     Arbustos redondos:  fila 9,  cols 2-10
#     Flores amarillas:   fila 10, cols 0-1
#   NO STANDALONE (partes de composición multi-tile):
#     Árboles grandes: filas 0-5, cols 0-14  (copa 2×3 + tronco)
#     Rocas grandes:   filas 6-10, cols 15-23
#
# PathLayer   →  resources/tilesets/path_tileset.tres   (TilesetFloor.png, 22×26)
#   Tierra marrón (camino): Vector2i(1, 7) — Terrain 0 "Tierra"
#   Otros terrenos confirmados (col=1 = tile interior sólido):
#     Arena naranja Vector2i(1, 1)  | Nieve Vector2i(1, 15) | Agua/hielo Vector2i(1, 22)
#
# BuildingLayer → resources/tilesets/building_tileset.tres
#   Source 0: TilesetHouse.png (33×23)  — edificios japoneses y occidentales
#   Source 1: TilesetVillageAbandoned.png (20×12) — piedra con musgo
#   Añadir colisión: abrir el .tres en Inspector → seleccionar tile → Physics → dibujar.
#
# CityFloorLayer    → resources/tilesets/city_floor_tileset.tres  (Tiny Town 12×11)
#   Adoquín gris:    Vector2i(0, 8) — Terrain 0 "Adoquín"
#
# CityBuildingLayer → resources/tilesets/city_building_tileset.tres  (Tiny Town 12×11)
#   Casa naranja: techo Vector2i(4,4) | cumbrera ▽ Vector2i(7,5) | pared Vector2i(1,6)
#   Casa gris:    techo Vector2i(0,4) | cumbrera ▽ Vector2i(3,5) | pared Vector2i(5,8)
#   Árbol: Vector2i(3,0)
#
# CaveWallLayer  → resources/tilesets/cave_wall_tileset.tres  (Tiny Dungeon 12×11)
#   Roca con colisión: Vector2i(0,0)   ← único tile con colisión
#   Resto de tiles: decoración sin colisión, pintables libremente
#
# CaveFloorLayer → resources/tilesets/cave_floor_tileset.tres  (Tiny Dungeon 12×11)
#   Suelo piedra:  Vector2i(0,1)  (sin colisión — el jugador camina sobre él)

const MAP_W := 40
const MAP_H := 25

const CAVE_OFFSET_X := 4000
const CAVE_OFFSET_Y := 0
const CAVE_W        := 40
const CAVE_H        := 30

# Boca de entrada (mapa principal): sprite 3×3 TilesetReliefDetail cols 3-5, filas 7-9
#   tile top-left = world tile (34,12); apertura = col 35, fila 13
#   trigger = pixel (568, 216);  llegada desde cueva = pixel (568, 264)  (+3 filas)
const _ENT_TL          := Vector2i(34, 12)
const _ENT_TRIGGER_PX  := Vector2(568.0, 216.0)
const _WORLD_ARRIVE_PX := Vector2(568.0, 264.0)

# Boca de salida (cueva): tile local top-left (18,25)
#   apertura local fila 27 → world pixel center (4312, 440)
#   llegada al entrar = pixel (4312, 392)  (−3 filas del trigger)
const _EXIT_TL_LOCAL   := Vector2i(18, 25)
const _EXIT_TRIGGER_PX := Vector2(4312.0, 440.0)
const _CAVE_ARRIVE_PX  := Vector2(4312.0, 392.0)

const INTERACTIVE_TREES: Array[Vector2i] = [
	Vector2i(8, 6),  Vector2i(12, 5),  Vector2i(15, 8),
	Vector2i(9, 14), Vector2i(20, 6),  Vector2i(25, 10),
	Vector2i(30, 7), Vector2i(28, 16), Vector2i(18, 18),
	Vector2i(10, 19), Vector2i(33, 12), Vector2i(22, 3),
]

# Posiciones de minas en la cueva (coordenadas locales de tile dentro de la cueva)
const _ORE_TILES := [
	Vector2i(17,20), Vector2i(21,22), Vector2i(23,25),  # R1 Sala Entrada
	Vector2i(10,11), Vector2i(14,12),                    # R2 Sala Explorador
	Vector2i(3,16),  Vector2i(6,20),                     # R3 Caverna Oeste
	Vector2i(31,20), Vector2i(34,23),                    # R4 Alcoba Este
	Vector2i(35,10),                                     # DE2 Alcoba NE (rara)
]

# Texturas para generación de tiles en runtime
const _A_FIELD := "res://assets/Backgrounds/Tilesets/TilesetField.png"
const _A_FLRX  := "res://assets/Backgrounds/Tilesets/TilesetFloor.png"
const _A_NAT   := "res://assets/Backgrounds/Tilesets/TilesetNature.png"
const _A_HOUSE := "res://assets/Backgrounds/Tilesets/TilesetHouse.png"
const _A_TD    := "res://assets/kenney/kenney_tiny-dungeon/Tilemap/tilemap_packed.png"
const _A_TT    := "res://assets/kenney/kenney_tiny-town/Tilemap/tilemap_packed.png"

const _GRASS  := Vector2i(1, 4)
const _CWALL  := Vector2i(0, 0)
const _CFLOOR := Vector2i(0, 1)
const _ADO    := Vector2i(0, 8)
const _CAVE_OX := 250   # CAVE_OFFSET_X / 16

const _CAVE_RECTS := [
	Rect2i(14,17,12,11), Rect2i(8,9,9,6),   Rect2i(1,12,9,12),
	Rect2i(29,16,9,11),  Rect2i(5,2,9,5),   Rect2i(15,15,3,2),
	Rect2i(10,19,4,3),   Rect2i(26,19,3,3), Rect2i(9,7,3,2),
	Rect2i(33,14,3,2),   Rect2i(1,7,4,5),   Rect2i(33,8,5,6),
]

# Ciudad (Pueblo) — al oeste del mundo principal
const CITY_OFFSET_X := -2000   # borde izquierdo en píxeles
const CITY_W        := 30      # tiles de ancho
const CITY_H        := 25      # tiles de alto (igual que el mundo)
const CITY_OX       := -125    # CITY_OFFSET_X / 16 en tiles

const _CITY_ENTER_PX      := Vector2(4.0,     200.0)    # trigger borde izq del mundo
const _CITY_ARRIVE_PX     := Vector2(-1552.0, 200.0)    # llegada dentro de la ciudad
const _CITY_EXIT_PX       := Vector2(-1528.0, 200.0)    # trigger salida (lado derecho ciudad)
const _WORLD_FROM_CITY_PX := Vector2(24.0,    200.0)    # llegada al volver al mundo

@onready var _player:    Node2D = $Player
@onready var _companion          = $Companion

var _cave_modulate:  CanvasModulate = null
var _cave_light:     PointLight2D   = null
var _cave_ent_area:  Area2D         = null
var _cave_exit_area:  Area2D = null
var _town_enter_area: Area2D = null
var _town_exit_area:  Area2D = null
var _in_cave:         bool   = false
var _in_town:         bool   = false
var _transitioning:   bool   = false

var _tree_scene:      PackedScene = preload("res://scenes/tree.tscn")
var _table_scene:     PackedScene = preload("res://scenes/crafting_table.tscn")
var _chest_scene:     PackedScene = preload("res://scenes/chest.tscn")
var _hud_scene:       PackedScene = preload("res://scenes/hud.tscn")
var _spawner_scene:   PackedScene = preload("res://scenes/spawner.tscn")
var _safe_zone_scene: PackedScene = preload("res://scenes/safe_zone.tscn")
var _city_npc_scene:  PackedScene = preload("res://scenes/city_npc.tscn")
var _ore_node_scene:  PackedScene = preload("res://scenes/ore_node.tscn")


func _ready() -> void:
	if not has_node("/root/FX") or not has_node("/root/SFX"):
		push_error("[World] Autoloads FX/SFX no encontrados. Recarga el proyecto (Project → Reload Current Project).")
	_register_input_actions()
	_ensure_tiles()
	_add_border_walls()
	_spawn_interactive_trees()
	_spawn_safe_zone()
	_build_cave_zone()
	_build_town_zone()
	_spawn_city_npcs()
	_spawn_crafting_table()
	_spawn_chest()
	_spawn_spawner()
	_spawn_cave_ores()
	var race = GameState.selected_race
	if race != null:
		_player.setup_race(race)
		_companion.data = race.companion_data
	else:
		_companion.data = preload("res://resources/companion_hawk.tres")
	_spawn_hud()
	_companion.set_target(_player)


func _process(_delta: float) -> void:
	if _cave_light != null and _cave_light.visible:
		_cave_light.global_position = _player.global_position


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


func _add_border_walls() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	var walls := [
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
	zone.position = Vector2(80.0, 64.0)
	add_child(zone)


func _spawn_crafting_table() -> void:
	var table: Node2D = _table_scene.instantiate()
	table.position = Vector2(5 * 16 + 8, 4 * 16 + 8)
	add_child(table)


func _spawn_chest() -> void:
	var chest: Node2D = _chest_scene.instantiate()
	chest.position = Vector2(7 * 16 + 8, 4 * 16 + 8)
	add_child(chest)


func _spawn_spawner() -> void:
	add_child(_spawner_scene.instantiate())


func _spawn_hud() -> void:
	var hud = _hud_scene.instantiate()
	add_child(hud)
	hud.set_player(_player)
	hud.set_companion(_companion)


func _spawn_city_npcs() -> void:
	var merchant: CityNPC = _city_npc_scene.instantiate()
	merchant.npc_name     = "Comerciante"
	merchant.atlas_region = Rect2(0, 96, 16, 16)
	merchant.position     = Vector2(2 * 16 + 8, 5 * 16 + 8)
	add_child(merchant)

	var quest_npc: CityNPC = _city_npc_scene.instantiate()
	quest_npc.npc_name    = "Sabio"
	quest_npc.atlas_region = Rect2(0, 112, 16, 16)
	quest_npc.position    = Vector2(7 * 16 + 8, 5 * 16 + 8)
	add_child(quest_npc)


# ─── Cueva (solo elementos dinámicos: sprites, triggers, iluminación) ─────────
# Los tiles de paredes y suelo de la cueva están baked en world.tscn.
# Ejecutar scripts/bake_world.gd si necesitas regenerarlos.

func _build_cave_zone() -> void:
	# ── Boca de salida (dentro de la cueva) ───────────────────────────────────
	var exit_tl := Vector2(
		float(CAVE_OFFSET_X) + float(_EXIT_TL_LOCAL.x) * 16.0,
		float(CAVE_OFFSET_Y) + float(_EXIT_TL_LOCAL.y) * 16.0
	)
	_place_cave_mouth(exit_tl)
	_add_cave_mouth_walls(exit_tl, false)   # sin techo — el jugador sale desde arriba
	_cave_exit_area = _make_trigger_area(_EXIT_TRIGGER_PX)
	_cave_exit_area.body_entered.connect(_on_cave_exit_body_entered)
	add_child(_cave_exit_area)

	# ── Boca de entrada (mapa principal) ──────────────────────────────────────
	var ent_tl := Vector2(float(_ENT_TL.x) * 16.0, float(_ENT_TL.y) * 16.0)
	_place_cave_mouth(ent_tl)
	_add_cave_mouth_walls(ent_tl)
	_cave_ent_area = _make_trigger_area(_ENT_TRIGGER_PX)
	_cave_ent_area.body_entered.connect(_on_cave_entrance_body_entered)
	add_child(_cave_ent_area)

	# ── Iluminación (local por cliente, no sincronizada) ──────────────────────
	_cave_modulate = CanvasModulate.new()
	_cave_modulate.color = Color(1.0, 1.0, 1.0)
	add_child(_cave_modulate)

	_cave_light = PointLight2D.new()
	_cave_light.energy         = 1.2
	_cave_light.texture_scale  = 4.0
	_cave_light.shadow_enabled = false
	_cave_light.visible        = false
	_cave_light.texture        = _make_radial_light_texture(128)
	add_child(_cave_light)


func _place_cave_mouth(world_tl: Vector2) -> void:
	var tex := load("res://assets/Backgrounds/Tilesets/TilesetReliefDetail.png") as Texture2D
	for row: int in 3:
		for col: int in 3:
			var sp  := Sprite2D.new()
			var atl := AtlasTexture.new()
			atl.atlas  = tex
			atl.region = Rect2((3 + col) * 16.0, (7 + row) * 16.0, 16.0, 16.0)
			sp.texture  = atl
			sp.position = world_tl + Vector2(col * 16.0 + 8.0, row * 16.0 + 8.0)
			add_child(sp)


func _add_cave_mouth_walls(world_tl: Vector2, add_top_wall: bool = true) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask  = 0
	add_child(body)
	var walls: Array = [
		[Vector2(16.0, 48.0), world_tl + Vector2(8.0,  24.0)],   # columna izq
		[Vector2(16.0, 48.0), world_tl + Vector2(40.0, 24.0)],   # columna der
	]
	if add_top_wall:
		walls.append([Vector2(48.0, 16.0), world_tl + Vector2(24.0, 8.0)])
	for data: Array in walls:
		var sh   := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size      = data[0]
		sh.position    = data[1]
		sh.shape       = rect
		body.add_child(sh)


func _make_trigger_area(center_px: Vector2, size: Vector2 = Vector2(14.0, 10.0)) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	area.position        = center_px
	var sh   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	sh.shape  = rect
	area.add_child(sh)
	return area


func _make_radial_light_texture(size: int) -> ImageTexture:
	var img    := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var half   := size / 2.0
	for y: int in size:
		for x: int in size:
			var dist  := Vector2(x, y).distance_to(center) / half
			var alpha := clampf(1.0 - dist * dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


func _on_cave_entrance_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or body != _player or _transitioning:
		return
	_transitioning = true
	_do_cave_transition(_CAVE_ARRIVE_PX, true)


func _on_cave_exit_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or body != _player or _transitioning:
		return
	_transitioning = true
	_do_cave_transition(_WORLD_ARRIVE_PX, false)


func _do_cave_transition(arrive_pos: Vector2, enter_cave: bool) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 99
	var rect := ColorRect.new()
	rect.color    = Color(0.0, 0.0, 0.0, 0.0)
	rect.size     = Vector2(640.0, 360.0)
	rect.position = Vector2.ZERO
	overlay.add_child(rect)
	add_child(overlay)

	var tw1 := create_tween()
	tw1.tween_property(rect, "color:a", 1.0, 0.3)
	await tw1.finished

	_player.position    = arrive_pos
	_companion.position = arrive_pos + Vector2(-16.0, 0.0)
	_player.velocity    = Vector2.ZERO

	var cam: Camera2D = _player.get_node("Camera2D")
	if enter_cave:
		cam.limit_left   = CAVE_OFFSET_X
		cam.limit_right  = CAVE_OFFSET_X + CAVE_W * 16
		cam.limit_top    = CAVE_OFFSET_Y
		cam.limit_bottom = CAVE_OFFSET_Y + CAVE_H * 16
		_cave_modulate.color        = Color(0.15, 0.10, 0.15)
		_cave_light.visible         = true
		_cave_light.global_position = _player.global_position
	else:
		cam.limit_left   = 0
		cam.limit_right  = MAP_W * 16
		cam.limit_top    = 0
		cam.limit_bottom = MAP_H * 16
		_cave_modulate.color = Color(1.0, 1.0, 1.0)
		_cave_light.visible  = false

	_in_cave = enter_cave

	var tw2 := create_tween()
	tw2.tween_property(rect, "color:a", 0.0, 0.3)
	await tw2.finished

	overlay.queue_free()
	_transitioning = false


# ── Minas de la cueva ─────────────────────────────────────────────────────────

func _spawn_cave_ores() -> void:
	for tp: Vector2i in _ORE_TILES:
		var ore: Node2D = _ore_node_scene.instantiate()
		ore.position = Vector2(CAVE_OFFSET_X + tp.x * 16.0 + 8.0, tp.y * 16.0 + 8.0)
		add_child(ore)


# ── Generación de tiles en runtime (solo si bake_world.gd no se ha ejecutado) ─

func _ensure_tiles() -> void:
	var fl: TileMapLayer = $FloorLayer
	if fl.tile_set != null and not fl.get_used_cells().is_empty():
		return

	fl.tile_set = _rt_simple_ts(_A_FIELD, 5, 15)
	($NatureLayer       as TileMapLayer).tile_set = _rt_simple_ts(_A_NAT,   24, 21)
	($PathLayer         as TileMapLayer).tile_set = _rt_simple_ts(_A_FLRX,  22, 26)
	($BuildingLayer     as TileMapLayer).tile_set = _rt_simple_ts(_A_HOUSE, 33, 23)
	($CityFloorLayer    as TileMapLayer).tile_set = _rt_simple_ts(_A_TT,    12, 11)
	($CaveFloorLayer    as TileMapLayer).tile_set = _rt_simple_ts(_A_TD,    12, 11)

	var ts_cb := TileSet.new()
	ts_cb.tile_size = Vector2i(16, 16)
	ts_cb.add_physics_layer()
	ts_cb.set_physics_layer_collision_layer(0, 1)
	var src_cb := _rt_atlas(ts_cb, _A_TT, 12, 11)
	var poly_sq := PackedVector2Array([
		Vector2(-8.0,-8.0), Vector2(8.0,-8.0), Vector2(8.0,8.0), Vector2(-8.0,8.0)])
	for c: int in [0, 1, 2]:   # paredes casa naranja (fila 6)
		var td := src_cb.get_tile_data(Vector2i(c, 6), 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, poly_sq)
	for c: int in [4, 5, 6]:   # paredes casa gris (fila 8)
		var td := src_cb.get_tile_data(Vector2i(c, 8), 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, poly_sq)
	($CityBuildingLayer as TileMapLayer).tile_set = ts_cb

	var ts_cw := TileSet.new()
	ts_cw.tile_size = Vector2i(16, 16)
	ts_cw.add_physics_layer()
	ts_cw.set_physics_layer_collision_layer(0, 1)
	var src_cw := _rt_atlas(ts_cw, _A_TD, 12, 11)
	var td_w: TileData = src_cw.get_tile_data(_CWALL, 0)
	td_w.set_collision_polygons_count(0, 1)
	td_w.set_collision_polygon_points(0, 0, poly_sq)
	($CaveWallLayer as TileMapLayer).tile_set = ts_cw

	for y: int in MAP_H:
		for x: int in MAP_W:
			fl.set_cell(Vector2i(x, y), 0, _GRASS)
	_rt_gen_city()
	_rt_gen_cave()
	_rt_gen_town()


func _rt_simple_ts(tex: String, cols: int, rows: int) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	_rt_atlas(ts, tex, cols, rows)
	return ts


func _rt_atlas(ts: TileSet, tex: String, cols: int, rows: int, id: int = 0) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(tex)
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, id)
	for r: int in rows:
		for c: int in cols:
			src.create_tile(Vector2i(c, r))
	return src


func _rt_gen_cave() -> void:
	var cwl:  TileMapLayer = $CaveWallLayer
	var cfll: TileMapLayer = $CaveFloorLayer
	for y: int in CAVE_H:
		for x: int in CAVE_W:
			cwl.set_cell(Vector2i(_CAVE_OX + x, y), 0, _CWALL)
	for r: Rect2i in _CAVE_RECTS:
		for dy: int in r.size.y:
			for dx: int in r.size.x:
				var wx := _CAVE_OX + r.position.x + dx
				var wy := r.position.y + dy
				cwl.erase_cell(Vector2i(wx, wy))
				cfll.set_cell(Vector2i(wx, wy), 0, _CFLOOR)


func _rt_gen_city() -> void:
	var cfl: TileMapLayer = $CityFloorLayer
	var cbl: TileMapLayer = $CityBuildingLayer
	var h1r := [Vector2i(4,4), Vector2i(4,4), Vector2i(4,4)]
	var h1g := [Vector2i(4,5), Vector2i(7,5), Vector2i(6,5)]
	var h1w := [Vector2i(0,6), Vector2i(1,6), Vector2i(2,6)]
	var h2r := [Vector2i(0,4), Vector2i(0,4), Vector2i(0,4)]
	var h2g := [Vector2i(0,5), Vector2i(3,5), Vector2i(2,5)]
	var h2w := [Vector2i(4,8), Vector2i(5,8), Vector2i(6,8)]
	for i: int in 3:
		cbl.set_cell(Vector2i(1 + i, 1), 0, h1r[i])
		cbl.set_cell(Vector2i(1 + i, 2), 0, h1g[i])
		cbl.set_cell(Vector2i(1 + i, 3), 0, h1w[i])
		cbl.set_cell(Vector2i(6 + i, 1), 0, h2r[i])
		cbl.set_cell(Vector2i(6 + i, 2), 0, h2g[i])
		cbl.set_cell(Vector2i(6 + i, 3), 0, h2w[i])
	for x: int in 10:
		cfl.set_cell(Vector2i(x, 4), 0, _ADO)
	cbl.set_cell(Vector2i(0, 2), 0, Vector2i(3, 0))
	cbl.set_cell(Vector2i(9, 2), 0, Vector2i(3, 0))


func _rt_gen_town() -> void:
	var cfl: TileMapLayer = $CityFloorLayer
	for y: int in CITY_H:
		for x: int in CITY_W:
			cfl.set_cell(Vector2i(CITY_OX + x, y), 0, _ADO)


# ── Ciudad / Pueblo ───────────────────────────────────────────────────────────

func _build_town_zone() -> void:
	_town_enter_area = _make_trigger_area(_CITY_ENTER_PX, Vector2(10.0, 80.0))
	_town_enter_area.body_entered.connect(_on_town_enter_body_entered)
	add_child(_town_enter_area)

	_town_exit_area = _make_trigger_area(_CITY_EXIT_PX, Vector2(10.0, 80.0))
	_town_exit_area.body_entered.connect(_on_town_exit_body_entered)
	add_child(_town_exit_area)

	_place_building(
		"res://assets/utils/pueblo/Gremio 64x64.png",
		Vector2(float(CITY_OFFSET_X) + 100.0, 192.0),
		Vector2(0.0, -32.0), Vector2(56.0, 52.0))

	_place_building(
		"res://assets/utils/pueblo/Mercaderes 128x128.png",
		Vector2(float(CITY_OFFSET_X) + 290.0, 224.0),
		Vector2(0.0, -64.0), Vector2(110.0, 90.0))


func _place_building(tex_path: String, base_pos: Vector2,
		spr_offset: Vector2, coll_size: Vector2) -> void:
	var node := Node2D.new()
	node.position = base_pos

	var spr := Sprite2D.new()
	spr.texture        = load(tex_path)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.offset         = spr_offset
	node.add_child(spr)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask  = 0
	var sh   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size      = coll_size
	sh.position    = Vector2(0.0, spr_offset.y)
	sh.shape       = rect
	body.add_child(sh)
	node.add_child(body)

	add_child(node)


func _on_town_enter_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or body != _player or _transitioning:
		return
	_transitioning = true
	_do_town_transition(_CITY_ARRIVE_PX, true)


func _on_town_exit_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or body != _player or _transitioning:
		return
	_transitioning = true
	_do_town_transition(_WORLD_FROM_CITY_PX, false)


func _do_town_transition(arrive_pos: Vector2, enter_town: bool) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 99
	var rect := ColorRect.new()
	rect.color    = Color(0.0, 0.0, 0.0, 0.0)
	rect.size     = Vector2(640.0, 360.0)
	rect.position = Vector2.ZERO
	overlay.add_child(rect)
	add_child(overlay)

	var tw1 := create_tween()
	tw1.tween_property(rect, "color:a", 1.0, 0.3)
	await tw1.finished

	_player.position    = arrive_pos
	_companion.position = arrive_pos + Vector2(16.0, 0.0)
	_player.velocity    = Vector2.ZERO

	var cam: Camera2D = _player.get_node("Camera2D")
	if enter_town:
		cam.limit_left   = CITY_OFFSET_X
		cam.limit_right  = CITY_OFFSET_X + CITY_W * 16
		cam.limit_top    = 0
		cam.limit_bottom = CITY_H * 16
	else:
		cam.limit_left   = 0
		cam.limit_right  = MAP_W * 16
		cam.limit_top    = 0
		cam.limit_bottom = MAP_H * 16

	_in_town = enter_town

	var tw2 := create_tween()
	tw2.tween_property(rect, "color:a", 0.0, 0.3)
	await tw2.finished

	overlay.queue_free()
	_transitioning = false
