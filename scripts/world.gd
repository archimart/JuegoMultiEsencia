extends Node2D

# ─── Tiles de referencia (solo para documentación del editor) ─────────────────
#
# FloorLayer  →  resources/floor_tileset.tres  (TilesetField.png, 5×15)
# NatureLayer →  resources/nature_tileset.tres (TilesetNature.png, 24×21)
# PathLayer   →  resources/path_tileset.tres   (TilesetFloor.png, 22×26)
# StreetLayer →  resources/city_floor_tileset.tres (Tiny Town 12×11)
# WallLayer   →  resources/cave_wall_tileset.tres  (Tiny Dungeon 12×11)
# BuildingLayer → resources/city_building_tileset.tres (Tiny Town 12×11)
#   Casa naranja: techo (4,4) | cumbrera (4,5)/(7,5)/(6,5) | pared (0,6)/(1,6)/(2,6)
#   Casa gris:    techo (0,4) | cumbrera (0,5)/(3,5)/(2,5) | pared (4,6)/(5,6)/(6,6)

# ─── Cueva ────────────────────────────────────────────────────────────────────
const CAVE_OFFSET_X := 4000
const CAVE_OFFSET_Y := 0
const CAVE_W        := 40
const CAVE_H        := 30

# Boca de entrada al mundo de chunks (tile 99,25 = pixel 1584,400)
#   Sprite 3×3 top-left = pixel (1568,384);  trigger = fila inferior de la apertura
const _CAVE_ENT_WORLD_TL := Vector2(1568.0, 384.0)
const _ENT_TRIGGER_PX    := Vector2(1584.0, 416.0)
const _WORLD_ARRIVE_PX   := Vector2(1584.0, 448.0)   # reaparece 2 tiles al sur

# Boca de salida (dentro de la cueva, posición fija en x=4000+)
const _EXIT_TL_LOCAL   := Vector2i(18, 25)
const _EXIT_TRIGGER_PX := Vector2(4312.0, 440.0)
const _CAVE_ARRIVE_PX  := Vector2(4312.0, 392.0)

# Árboles interactivos en el mundo de chunks (fuera del pueblo 80-119, 80-119)
const _CHUNK_TREES: Array[Vector2i] = [
	Vector2i(20, 12), Vector2i(30, 8),   Vector2i(45, 15),
	Vector2i(12, 28), Vector2i(35, 22),  Vector2i(55, 30),
	Vector2i(70, 18), Vector2i(15, 50),  Vector2i(60, 55),
	Vector2i(130, 25),Vector2i(150, 40), Vector2i(165, 20),
	Vector2i(30, 130),Vector2i(50, 150), Vector2i(170, 160),
]

# Minas de la cueva (coordenadas locales de tile)
const _ORE_TILES := [
	Vector2i(17,20), Vector2i(21,22), Vector2i(23,25),
	Vector2i(10,11), Vector2i(14,12),
	Vector2i(3,16),  Vector2i(6,20),
	Vector2i(31,20), Vector2i(34,23),
	Vector2i(35,10),
]

@onready var _player:    Node2D = $Player
@onready var _companion          = $Companion

var _cave_modulate:   CanvasModulate = null
var _cave_light:      PointLight2D   = null
var _cave_ent_area:   Area2D         = null
var _cave_exit_area:  Area2D         = null
var _in_cave:         bool           = false
var _transitioning:   bool           = false

var _tree_scene:      PackedScene = preload("res://scenes/tree.tscn")
var _table_scene:     PackedScene = preload("res://scenes/crafting_table.tscn")
var _chest_scene:     PackedScene = preload("res://scenes/chest.tscn")
var _hud_scene:       PackedScene = preload("res://scenes/hud.tscn")
var _spawner_scene:   PackedScene = preload("res://scenes/spawner.tscn")
var _safe_zone_scene: PackedScene = preload("res://scenes/safe_zone.tscn")
var _city_npc_scene:  PackedScene = preload("res://scenes/city_npc.tscn")
var _ore_node_scene:  PackedScene = preload("res://scenes/ore_node.tscn")

var _chunk_world:   bool         = false
var _surface_cm:    ChunkManager = null
var _cave_cm:       ChunkManager = null
var _debug_overlay: CanvasLayer  = null


func _ready() -> void:
	_chunk_world = FileAccess.file_exists(
		ProjectSettings.globalize_path("res://scenes/chunks/chunk_0_0_0.tscn"))
	if not has_node("/root/FX") or not has_node("/root/SFX"):
		push_error("[World] Autoloads FX/SFX no encontrados. Recarga el proyecto.")
	_register_input_actions()
	if not _chunk_world:
		_show_no_chunks_error()
		return
	_build_cave_zone()
	_spawn_chunk_world_objects()
	_spawn_interactive_trees()
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
	_init_chunk_managers()


func _show_no_chunks_error() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	var label := Label.new()
	label.text = "ERROR: No se encontraron chunks del mundo.\n\nEjecutar scripts/bake_chunks.gd desde el editor:\n  1. Abrir world.tscn\n  2. Script Editor → File → Open → bake_chunks.gd\n  3. Presionar ▶ (Run)"
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(label)
	add_child(cl)
	push_error("[World] chunk_0_0_0.tscn no existe. Ejecutar bake_chunks.gd primero.")


# ─── Chunk Managers ───────────────────────────────────────────────────────────

func _init_chunk_managers() -> void:
	var spawn := _chunk_read_spawn()
	if spawn != Vector2.ZERO:
		_player.global_position    = spawn
		_companion.global_position = spawn + Vector2(16.0, 0.0)

	var world_px := _chunk_world_px()
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left   = 0
		cam.limit_right  = world_px.x
		cam.limit_top    = 0
		cam.limit_bottom = world_px.y

	_surface_cm = preload("res://scripts/chunk_manager.gd").new()
	_surface_cm.name         = "ChunkManager"
	_surface_cm.layer        = 0
	_surface_cm.world_offset = Vector2.ZERO
	add_child(_surface_cm)

	var cave_path := ProjectSettings.globalize_path("res://scenes/chunks/chunk_1_0_0.tscn")
	if FileAccess.file_exists(cave_path):
		_cave_cm = preload("res://scripts/chunk_manager.gd").new()
		_cave_cm.name         = "CaveChunkManager"
		_cave_cm.layer        = 1
		_cave_cm.world_offset = Vector2(float(CAVE_OFFSET_X), float(CAVE_OFFSET_Y))
		add_child(_cave_cm)
		_cave_cm.set_layer_active(false)
	else:
		push_warning("[World] chunk_1_0_0.tscn no encontrado. Ejecutar gen_cave_chunk.gd.")

	print("[World] Chunks iniciados — mundo %d×%d px, spawn %s, cueva=%s" % [
		world_px.x, world_px.y, spawn, _cave_cm != null])


func _chunk_read_spawn() -> Vector2:
	const PATH := "res://resources/world_data.json"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(PATH)):
		return Vector2.ZERO
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return Vector2.ZERO
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary:
		return Vector2.ZERO
	var spawns: Array = data.get("markers", {}).get("spawn", [])
	if spawns.is_empty():
		return Vector2.ZERO
	var s: Dictionary = spawns[0]
	return Vector2(float(s.get("x", 0)), float(s.get("y", 0)))


func _chunk_world_px() -> Vector2i:
	const PATH := "res://resources/world_data.json"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(PATH)):
		return Vector2i(3200, 3200)
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return Vector2i(3200, 3200)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not data is Dictionary:
		return Vector2i(3200, 3200)
	var ws: Dictionary = data.get("world_size", {})
	return Vector2i(ws.get("tiles_w", 200) * 16, ws.get("tiles_h", 200) * 16)


# ─── Loop y entrada ───────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _cave_light != null and _cave_light.visible:
		_cave_light.global_position = _player.global_position
	_update_debug_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F3: _toggle_debug_overlay()
		KEY_F7:
			_companion.add_xp(10)
			print_rich("[color=cyan][DEBUG F7] +10 XP al compañero[/color]")


func _toggle_debug_overlay() -> void:
	if _debug_overlay != null:
		_debug_overlay.queue_free()
		_debug_overlay = null
		return
	_debug_overlay = CanvasLayer.new()
	_debug_overlay.layer = 90
	var label := Label.new()
	label.name = "Info"
	label.position = Vector2(6.0, 6.0)
	label.add_theme_color_override("font_color", Color.CYAN)
	label.add_theme_font_size_override("font_size", 9)
	_debug_overlay.add_child(label)
	add_child(_debug_overlay)
	_update_debug_overlay()


func _update_debug_overlay() -> void:
	if _debug_overlay == null:
		return
	var label := _debug_overlay.get_node_or_null("Info") as Label
	if label == null:
		return
	var cm: ChunkManager = _cave_cm if _in_cave else _surface_cm
	var layer_str  := "mina" if _in_cave else "superficie"
	var chunk_str  := "—"
	var n_loaded   := 0
	var coords_str := ""
	if cm != null:
		var cc: Vector2i = cm.world_to_chunk(_player.global_position)
		chunk_str  = str(cc)
		n_loaded   = cm.loaded_count()
		coords_str = cm.loaded_coords_str()
	label.text = "[ F3 — Chunks Debug ]\nCapa: %s  |  Chunk: %s\nCargados: %d\n%s" % [
		layer_str, chunk_str, n_loaded, coords_str]


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


# ─── Objetos del pueblo central ───────────────────────────────────────────────

func _spawn_chunk_world_objects() -> void:
	# Zona segura centrada en el pueblo (tile 99,99 = pixel 1584,1584)
	var zone: Node2D = _safe_zone_scene.instantiate()
	zone.position = Vector2(1584.0, 1584.0)
	add_child(zone)

	# Mesa de crafteo y cofre al sur del centro (tile 96,103 y 98,103)
	var table: Node2D = _table_scene.instantiate()
	table.position = Vector2(1536.0, 1648.0)
	add_child(table)

	var chest: Node2D = _chest_scene.instantiate()
	chest.position = Vector2(1568.0, 1648.0)
	add_child(chest)

	# NPCs a ambos lados del centro (tiles 94,100 y 104,100)
	var merchant: CityNPC = _city_npc_scene.instantiate()
	merchant.npc_name     = "Comerciante"
	merchant.atlas_region = Rect2(0, 96, 16, 16)
	merchant.position     = Vector2(1504.0, 1600.0)
	add_child(merchant)

	var sage: CityNPC = _city_npc_scene.instantiate()
	sage.npc_name     = "Sabio"
	sage.atlas_region = Rect2(0, 112, 16, 16)
	sage.position     = Vector2(1664.0, 1600.0)
	add_child(sage)


func _spawn_interactive_trees() -> void:
	for tile: Vector2i in _CHUNK_TREES:
		var tree: Node2D = _tree_scene.instantiate()
		tree.position = Vector2(tile.x * 16.0 + 8.0, tile.y * 16.0 + 8.0)
		add_child(tree)


func _spawn_spawner() -> void:
	add_child(_spawner_scene.instantiate())


func _spawn_hud() -> void:
	var hud = _hud_scene.instantiate()
	add_child(hud)
	hud.set_player(_player)
	hud.set_companion(_companion)


# ─── Cueva (sprites, triggers, iluminación — tiles vienen de chunk_1_0_0) ─────

func _build_cave_zone() -> void:
	# Boca de salida dentro de la cueva (posición fija al lado de x=4000)
	var exit_tl := Vector2(
		float(CAVE_OFFSET_X) + float(_EXIT_TL_LOCAL.x) * 16.0,
		float(CAVE_OFFSET_Y) + float(_EXIT_TL_LOCAL.y) * 16.0
	)
	_place_cave_mouth(exit_tl)
	_add_cave_mouth_walls(exit_tl, false)
	_cave_exit_area = _make_trigger_area(_EXIT_TRIGGER_PX)
	_cave_exit_area.body_entered.connect(_on_cave_exit_body_entered)
	add_child(_cave_exit_area)

	# Boca de entrada en el mundo de chunks (norte del pueblo, tile 99,25)
	_place_cave_mouth(_CAVE_ENT_WORLD_TL)
	_add_cave_mouth_walls(_CAVE_ENT_WORLD_TL)
	_cave_ent_area = _make_trigger_area(_ENT_TRIGGER_PX)
	_cave_ent_area.body_entered.connect(_on_cave_entrance_body_entered)
	add_child(_cave_ent_area)

	# Iluminación de cueva (local, no sincronizada)
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
		[Vector2(16.0, 48.0), world_tl + Vector2(8.0,  24.0)],
		[Vector2(16.0, 48.0), world_tl + Vector2(40.0, 24.0)],
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

	# Intercambiar capas mientras la pantalla está en negro
	if enter_cave and _cave_cm != null:
		_cave_cm.preload_around(arrive_pos)
		_surface_cm.set_layer_active(false)
		_cave_cm.set_layer_active(true)
	elif not enter_cave and _surface_cm != null:
		_surface_cm.preload_around(arrive_pos)
		if _cave_cm != null:
			_cave_cm.set_layer_active(false)
		_surface_cm.set_layer_active(true)

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
		var wpx := _chunk_world_px()
		cam.limit_left   = 0
		cam.limit_right  = wpx.x
		cam.limit_top    = 0
		cam.limit_bottom = wpx.y
		_cave_modulate.color = Color(1.0, 1.0, 1.0)
		_cave_light.visible  = false

	_in_cave = enter_cave

	var tw2 := create_tween()
	tw2.tween_property(rect, "color:a", 0.0, 0.3)
	await tw2.finished

	overlay.queue_free()
	_transitioning = false


func _spawn_cave_ores() -> void:
	for tp: Vector2i in _ORE_TILES:
		var ore: Node2D = _ore_node_scene.instantiate()
		ore.position = Vector2(CAVE_OFFSET_X + tp.x * 16.0 + 8.0, tp.y * 16.0 + 8.0)
		add_child(ore)
