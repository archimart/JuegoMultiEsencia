## Genera la cueva como chunk_1_0_0.tscn (capa 1 del sistema de chunks).
## Uso: abrir world.tscn → Script Editor → File → Open → este archivo → ▶
@tool
extends EditorScript

const CHUNK_DIR := "res://scenes/chunks/"
const CAVE_W    := 40
const CAVE_H    := 30

const _CAVE_RECTS := [
	Rect2i(14,17,12,11), Rect2i(8,9,9,6),   Rect2i(1,12,9,12),
	Rect2i(29,16,9,11),  Rect2i(5,2,9,5),   Rect2i(15,15,3,2),
	Rect2i(10,19,4,3),   Rect2i(26,19,3,3), Rect2i(9,7,3,2),
	Rect2i(33,14,3,2),   Rect2i(1,7,4,5),   Rect2i(33,8,5,6),
]

const _CWALL  := Vector2i(0, 0)
const _CFLOOR := Vector2i(0, 1)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHUNK_DIR))

	var ts_wall  := load("res://resources/cave_wall_tileset.tres")  as TileSet
	var ts_floor := load("res://resources/cave_floor_tileset.tres") as TileSet
	if ts_wall == null or ts_floor == null:
		printerr("[GenCave] No se encontraron cave_wall_tileset.tres o cave_floor_tileset.tres")
		return

	var root := Node2D.new()
	root.name = "Chunk"
	root.set_script(load("res://scripts/chunk.gd"))
	root.set("chunk_x",      0)
	root.set("chunk_y",      0)
	root.set("layer",        1)
	root.set("has_safe_zone", false)

	# WallLayer: fondo de roca con colisión
	var wl := TileMapLayer.new()
	wl.name            = "WallLayer"
	wl.tile_set        = ts_wall
	wl.y_sort_enabled  = true
	root.add_child(wl)
	wl.owner = root

	# FloorLayer: suelo de piedra solo en las salas
	var fl := TileMapLayer.new()
	fl.name     = "FloorLayer"
	fl.tile_set = ts_floor
	root.add_child(fl)
	fl.owner = root

	# Rellenar toda el área con pared
	for cy: int in CAVE_H:
		for cx: int in CAVE_W:
			wl.set_cell(Vector2i(cx, cy), 0, _CWALL)

	# Abrir salas: quitar pared, poner suelo
	for r: Rect2i in _CAVE_RECTS:
		for dy: int in r.size.y:
			for dx: int in r.size.x:
				var p := Vector2i(r.position.x + dx, r.position.y + dy)
				wl.erase_cell(p)
				fl.set_cell(p, 0, _CFLOOR)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, CHUNK_DIR + "chunk_1_0_0.tscn")
	if err != OK:
		printerr("[GenCave] Error guardando chunk_1_0_0.tscn: %d" % err)
		root.free()
		return
	root.free()
	print("[GenCave] ✓ chunk_1_0_0.tscn — %d salas, %d×%d tiles" % [
		_CAVE_RECTS.size(), CAVE_W, CAVE_H])
