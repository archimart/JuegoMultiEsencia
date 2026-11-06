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

# Minas de la cueva (coordenadas locales de tile, offset CAVE_OFFSET_X)
const _ORE_TILES := [
	Vector2i(17,20), Vector2i(21,22), Vector2i(23,25),
	Vector2i(10,11), Vector2i(14,12),
	Vector2i(3,16),  Vector2i(6,20),
	Vector2i(31,20), Vector2i(34,23),
	Vector2i(35,10),
]

# Vetas en la superficie: zona norte (montañas) y bordes del mapa
const _SURFACE_ORE_TILES: Array[Vector2i] = [
	# Norte (cerca de la boca de la cueva, tile 99,25)
	Vector2i(90, 10), Vector2i(96, 8),  Vector2i(103, 11),
	Vector2i(110, 7), Vector2i(85, 14),
	# Oeste (zona montañosa)
	Vector2i(8, 55),  Vector2i(10, 70), Vector2i(7, 90),
	# Este (zona montañosa)
	Vector2i(188, 60),Vector2i(190, 80),Vector2i(185, 100),
]

@onready var _player: Node2D = $Player

var _cave_modulate:   CanvasModulate = null
var _cave_light:      PointLight2D   = null
var _cave_ent_area:   Area2D         = null
var _cave_exit_area:  Area2D         = null
var _in_cave:         bool           = false
var _transitioning:   bool           = false

var _pause_scene:     PackedScene = preload("res://scenes/pause_menu.tscn")
var _pause_menu:      CanvasLayer = null

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
var _trainer:       Node2D       = null
var _trainer_panel: CanvasLayer  = null
var _help_panel:    CanvasLayer  = null

# ─── Minimapa ─────────────────────────────────────────────────────────────────
const _MM_PX   := 80    # tamaño en pantalla (px de viewport)
const _MM_ZOOM := 0.14  # muestra _MM_PX/_MM_ZOOM ≈ 571 px del mundo (~2 chunks)
const _MM_PAD  := 4

var _minimap_sv:  SubViewport = null
var _minimap_cam: Camera2D    = null
var _minimap_off: Vector2     = Vector2.ZERO
var _mm_markers:  Array       = []  # [{dot: ColorRect, pos: Vector2, comp: bool}]


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
	_spawn_surface_ores()
	var race = GameState.selected_race
	if race != null:
		_player.setup_race(race)
	_spawn_hud()
	var cls = GameState.selected_class
	if cls != null:
		_player.setup_class(cls)
	_init_chunk_managers()
	_setup_minimap()


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
	# Los límites de cámara van primero para que sean correctos cuando se mueve al jugador
	var world_px := _chunk_world_px()
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left   = 0
		cam.limit_right  = world_px.x
		cam.limit_top    = 0
		cam.limit_bottom = world_px.y

	# Centro del pueblo (marcador amarillo del mapa, tile 99,99)
	const VILLAGE_CENTER := Vector2(1584.0, 1584.0)
	var spawn := _chunk_read_spawn()
	if spawn == Vector2.ZERO:
		spawn = VILLAGE_CENTER
	_player.global_position = spawn
	_player.respawn_pos     = spawn

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
	if _minimap_cam != null and is_instance_valid(_player):
		_minimap_cam.global_position = _player.global_position
		_mm_update_markers()
	_update_debug_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if OS.is_debug_build():
		match event.keycode:
			KEY_F3: _toggle_debug_overlay()
	var _ui_open: bool = has_node("/root/UIManager") and UIManager.is_menu_open()
	if event.is_action_pressed("ui_cancel") and not _ui_open \
			and (_pause_menu == null or not is_instance_valid(_pause_menu)):
		get_viewport().set_input_as_handled()
		_open_pause()
		return
	if event.is_action_pressed("help"):
		_toggle_help_panel()
		return
	if event.is_action_pressed("interact"):
		if _trainer != null and is_instance_valid(_trainer):
			if _player.global_position.distance_to(_trainer.global_position) < 40.0:
				_toggle_trainer_panel()
				return


func _open_pause() -> void:
	_pause_menu = _pause_scene.instantiate()
	_pause_menu.resume_requested.connect(func() -> void: _pause_menu = null)
	add_child(_pause_menu)


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
	if not InputMap.has_action("companions"):
		InputMap.add_action("companions")
		var ev := InputEventKey.new()
		ev.keycode = KEY_C
		InputMap.action_add_event("companions", ev)
	if not InputMap.has_action("help"):
		InputMap.add_action("help")
		var ev := InputEventKey.new()
		ev.keycode = KEY_H
		InputMap.action_add_event("help", ev)


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
	merchant.shop_scene   = "res://scenes/shop_menu.tscn"
	merchant.position     = Vector2(1504.0, 1600.0)
	add_child(merchant)

	var sage: CityNPC = _city_npc_scene.instantiate()
	sage.npc_name     = "Sabio"
	sage.atlas_region = Rect2(0, 112, 16, 16)
	sage.position     = Vector2(1664.0, 1600.0)
	add_child(sage)

	# Establo de compañeros (tile 100,105 = pixel 1600,1680)
	var stable: CityNPC = _city_npc_scene.instantiate()
	stable.npc_name     = "Establo — [C] compañeros"
	stable.atlas_region = Rect2(0, 128, 16, 16)
	stable.position     = Vector2(1600.0, 1680.0)
	add_child(stable)

	# Entrenador de clase (tile 101,100 = pixel 1616,1600)
	var trainer: CityNPC = _city_npc_scene.instantiate()
	trainer.npc_name     = "Entrenador — [E]"
	trainer.atlas_region = Rect2(16, 128, 16, 16)
	trainer.position     = Vector2(1616.0, 1600.0)
	add_child(trainer)
	_trainer = trainer


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

	_player.position = arrive_pos
	_player.velocity = Vector2.ZERO

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


func _spawn_surface_ores() -> void:
	for tp: Vector2i in _SURFACE_ORE_TILES:
		var ore: Node2D = _ore_node_scene.instantiate()
		ore.position = Vector2(tp.x * 16.0 + 8.0, tp.y * 16.0 + 8.0)
		add_child(ore)


# ── Entrenador de clase ───────────────────────────────────────────────────────

const CLASS_PATHS: Array[String] = [
	"res://resources/class_warrior.tres",
	"res://resources/class_archer.tres",
	"res://resources/class_mage.tres",
]
const TRAINER_COST := 50

func _toggle_trainer_panel() -> void:
	if _trainer_panel != null and is_instance_valid(_trainer_panel):
		_trainer_panel.queue_free()
		_trainer_panel = null
		return
	_open_trainer_panel()


func _open_trainer_panel() -> void:
	_trainer_panel = CanvasLayer.new()
	_trainer_panel.layer = 10
	add_child(_trainer_panel)

	const W := 280.0
	const H := 170.0
	var vp  := get_viewport().get_visible_rect().size

	var bg := Panel.new()
	bg.position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)
	bg.size     = Vector2(W, H)
	bg.add_theme_stylebox_override("panel", _dark_sb())
	_trainer_panel.add_child(bg)

	var title := Label.new()
	title.text     = "Entrenador  (costo: %d oro)" % TRAINER_COST
	title.position = Vector2(0.0, 6.0)
	title.size     = Vector2(W, 14.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	bg.add_child(title)

	var classes: Array = []
	for path: String in CLASS_PATHS:
		if ResourceLoader.exists(path):
			classes.append(load(path))

	const CW  := 72.0
	const GAP := 12.0
	var total := float(classes.size()) * CW + float(max(0, classes.size() - 1)) * GAP
	var sx    := (W - total) * 0.5

	for i: int in classes.size():
		var cls  = classes[i]
		var card := Panel.new()
		card.position = Vector2(sx + i * (CW + GAP), 24.0)
		card.size     = Vector2(CW, 110.0)
		card.add_theme_stylebox_override("panel", _card_sb())
		bg.add_child(card)

		var icon := Label.new()
		match str(cls.get("weapon_id")):
			"sword": icon.text = "⚔"
			"bow":   icon.text = "🏹"
			"staff": icon.text = "✨"
		icon.position = Vector2(0.0, 6.0)
		icon.size     = Vector2(CW, 26.0)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 20)
		card.add_child(icon)

		var lbl := Label.new()
		lbl.text     = str(cls.get("class_label"))
		lbl.position = Vector2(2.0, 34.0)
		lbl.size     = Vector2(CW - 4.0, 12.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.85))
		card.add_child(lbl)

		var cur_label: String = ""
		var cur_cls = GameState.selected_class
		if cur_cls != null and str(cur_cls.get("class_label")) == str(cls.get("class_label")):
			cur_label = "(actual)"
		var cur_lbl := Label.new()
		cur_lbl.text     = cur_label
		cur_lbl.position = Vector2(2.0, 48.0)
		cur_lbl.size     = Vector2(CW - 4.0, 10.0)
		cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cur_lbl.add_theme_font_size_override("font_size", 6)
		cur_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5))
		card.add_child(cur_lbl)

		var btn := Button.new()
		btn.text     = "Elegir"
		btn.position = Vector2(8.0, 84.0)
		btn.size     = Vector2(CW - 16.0, 18.0)
		btn.add_theme_font_size_override("font_size", 7)
		btn.pressed.connect(_on_trainer_class_chosen.bind(cls))
		card.add_child(btn)

	var close := Button.new()
	close.text     = "✕ Cerrar"
	close.position = Vector2(W - 66.0, H - 22.0)
	close.size     = Vector2(58.0, 16.0)
	close.add_theme_font_size_override("font_size", 7)
	close.pressed.connect(_toggle_trainer_panel)
	bg.add_child(close)


func _toggle_help_panel() -> void:
	if _help_panel != null and is_instance_valid(_help_panel):
		_help_panel.queue_free()
		_help_panel = null
		return
	_help_panel = CanvasLayer.new()
	_help_panel.layer = 20
	add_child(_help_panel)

	const W := 260.0
	const H := 230.0
	var vp  := get_viewport().get_visible_rect().size

	var bg := Panel.new()
	bg.position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)
	bg.size     = Vector2(W, H)
	bg.add_theme_stylebox_override("panel", _dark_sb())
	_help_panel.add_child(bg)

	var title := Label.new()
	title.text     = "Ayuda — Controles"
	title.position = Vector2(0.0, 6.0)
	title.size     = Vector2(W, 14.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	bg.add_child(title)

	var sep := ColorRect.new()
	sep.position = Vector2(8.0, 22.0)
	sep.size     = Vector2(W - 16.0, 1.0)
	sep.color    = Color(0.3, 0.3, 0.4)
	bg.add_child(sep)

	# Dos columnas: izquierda=teclas, derecha=combate
	var left_lines: Array[String] = [
		"Mover:       Flechas / WASD",
		"Atacar:      Clic izquierdo",
		"Interactuar: E",
		"Inventario:  I / Tab",
		"Compañeros:  C",
		"Cambiar:     [  /  ]",
		"Ayuda:       H",
		"",
		"Debug (solo desarrollo):",
		"F1: +madera/flechas/arco",
		"F3: info de chunks",
		"F7: +XP al compañero",
		"F8: +esencias heart/raccoon",
	]
	var right_lines: Array[String] = [
		"Combate:",
		"• Clic izq para disparar flechas",
		"• El compañero ataca si te golpean",
		"• Mata criaturas: oro + XP + esencias",
		"• Acumular esencias desbloquea",
		"  nuevos compañeros (panel C)",
		"• El pueblo regenera vida",
		"• Al morir sueltas la mochila",
		"  (dura 5 min en el suelo)",
		"",
		"Clases:",
		"Arquero: ataca a distancia",
		"Guerrero/Mago: próximamente",
	]

	for i: int in left_lines.size():
		var lbl := Label.new()
		lbl.text     = left_lines[i]
		lbl.position = Vector2(10.0, 27.0 + i * 13.0)
		lbl.size     = Vector2(W * 0.5 - 12.0, 12.0)
		lbl.add_theme_font_size_override("font_size", 7)
		var is_section := left_lines[i].ends_with(":") or left_lines[i].is_empty()
		lbl.add_theme_color_override("font_color",
				Color(1.0, 0.9, 0.5) if is_section else Color(0.88, 0.88, 0.82))
		bg.add_child(lbl)

	var vsep := ColorRect.new()
	vsep.position = Vector2(W * 0.5, 24.0)
	vsep.size     = Vector2(1.0, H - 48.0)
	vsep.color    = Color(0.3, 0.3, 0.4)
	bg.add_child(vsep)

	for i: int in right_lines.size():
		var lbl := Label.new()
		lbl.text         = right_lines[i]
		lbl.position     = Vector2(W * 0.5 + 6.0, 27.0 + i * 13.0)
		lbl.size         = Vector2(W * 0.5 - 10.0, 12.0)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 7)
		var is_header := (i == 0 or i == 10)
		lbl.add_theme_color_override("font_color",
				Color(1.0, 0.9, 0.5) if is_header else Color(0.88, 0.88, 0.82))
		bg.add_child(lbl)

	var close := Button.new()
	close.text     = "✕  Cerrar  (H)"
	close.position = Vector2(W * 0.5 - 48.0, H - 20.0)
	close.size     = Vector2(96.0, 15.0)
	close.add_theme_font_size_override("font_size", 7)
	close.pressed.connect(_toggle_help_panel)
	bg.add_child(close)


func _on_trainer_class_chosen(cls: Resource) -> void:
	var gold: int = _player.inventory.get("gold", 0)
	if gold < TRAINER_COST:
		_player.notice_requested.emit("Se necesitan %d de oro" % TRAINER_COST)
		_toggle_trainer_panel()
		return
	_player.inventory["gold"] = gold - TRAINER_COST
	_player.setup_class(cls)
	GameState.selected_class = cls
	_player.inventory_changed.emit()
	_player.notice_requested.emit("Clase cambiada a %s" % str(cls.get("class_label")))
	_toggle_trainer_panel()


# ─── Minimapa ─────────────────────────────────────────────────────────────────

func _setup_minimap() -> void:
	_minimap_off = Vector2(640.0 - float(_MM_PX) - float(_MM_PAD), float(_MM_PAD))

	var cl := CanvasLayer.new()
	cl.layer = 3
	add_child(cl)

	# Borde exterior (1 px, azul oscuro)
	var border := ColorRect.new()
	border.position = _minimap_off - Vector2(1.0, 1.0)
	border.size     = Vector2(float(_MM_PX) + 2.0, float(_MM_PX) + 2.0)
	border.color    = Color(0.35, 0.50, 0.70, 1.0)
	cl.add_child(border)

	# Fondo oscuro del área interior (visible en zonas sin tiles)
	var bg := ColorRect.new()
	bg.position = _minimap_off
	bg.size     = Vector2(float(_MM_PX), float(_MM_PX))
	bg.color    = Color(0.08, 0.09, 0.12, 1.0)
	cl.add_child(bg)

	# SubViewport que comparte el mismo World2D: renderiza los mismos tiles
	_minimap_sv = SubViewport.new()
	_minimap_sv.size = Vector2i(_MM_PX, _MM_PX)
	_minimap_sv.disable_3d = true
	_minimap_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_minimap_sv.transparent_bg = true

	_minimap_cam = Camera2D.new()
	_minimap_cam.zoom = Vector2(_MM_ZOOM, _MM_ZOOM)
	_minimap_sv.add_child(_minimap_cam)

	var svc := SubViewportContainer.new()
	svc.stretch  = true
	svc.position = _minimap_off
	svc.size     = Vector2(float(_MM_PX), float(_MM_PX))
	svc.add_child(_minimap_sv)
	cl.add_child(svc)

	# Compartir mundo con el viewport principal para ver los tiles cargados
	_minimap_sv.world_2d = get_viewport().world_2d

	# Punto blanco fijo en el centro: siempre representa al jugador
	var pdot := ColorRect.new()
	pdot.size     = Vector2(3.0, 3.0)
	pdot.color    = Color.WHITE
	pdot.position = _minimap_off + Vector2(float(_MM_PX) * 0.5 - 1.5, float(_MM_PX) * 0.5 - 1.5)
	cl.add_child(pdot)

	# Marcadores con posición relativa al jugador
	_mm_add_marker(cl, Vector2(1584.0, 1584.0), Color(0.2, 1.0, 0.35), 4, false)  # pueblo
	_mm_add_marker(cl, _ENT_TRIGGER_PX,          Color(0.55, 0.22, 0.9), 3, false) # boca cueva


func _mm_add_marker(cl: CanvasLayer, world_pos: Vector2, color: Color, sz: int, follow_comp: bool) -> void:
	var dot := ColorRect.new()
	dot.size  = Vector2(float(sz), float(sz))
	dot.color = color
	cl.add_child(dot)
	_mm_markers.append({"dot": dot, "pos": world_pos, "comp": follow_comp})


func _mm_update_markers() -> void:
	var center := _minimap_off + Vector2(float(_MM_PX) * 0.5, float(_MM_PX) * 0.5)
	for m: Dictionary in _mm_markers:
		var dot: ColorRect = m["dot"]
		var wpos: Vector2 = m["pos"]
		var delta := wpos - _player.global_position
		var spos  := center + delta * _MM_ZOOM - dot.size * 0.5
		var inside := spos.x >= _minimap_off.x \
				  and spos.x + dot.size.x <= _minimap_off.x + float(_MM_PX) \
				  and spos.y >= _minimap_off.y \
				  and spos.y + dot.size.y <= _minimap_off.y + float(_MM_PX)
		dot.visible  = inside
		dot.position = spos


# ─── Helpers de estilo ────────────────────────────────────────────────────────

func _dark_sb() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	s.set_corner_radius_all(4)
	return s


func _card_sb() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.14, 0.14, 0.20, 1.0)
	s.border_color = Color(0.25, 0.25, 0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	return s
