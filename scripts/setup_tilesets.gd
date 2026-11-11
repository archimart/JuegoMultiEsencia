## Crea res://resources/world_terrain_tileset.tres a partir de los PNGs de PixelLab.
## Ejecutar UNA VEZ antes de bake_chunks.gd (Script Editor → ▶).
## Detecta automáticamente los terrain peering bits muestreando los píxeles de cada tile.
@tool
extends EditorScript

const TILES_DIR := "res://assets/Tiles/"
const WORLD_TS  := "res://resources/world_terrain_tileset.tres"

# Tile size: original 32×32 → se reduce a 16×16 para coincidir con el resto del juego
const TSRC := 32
const TDST := 16

# [png, hex_A, hex_B, nombre_A, nombre_B]
# Terrain set 0: Pasto ↔ Bosque
# Terrain set 1: Agua  ↔ Pantano
const SOURCES: Array = [
	[
		"pixellab-tileset-flat-vibrant-green-grass-field-4caf50-tone-dense-dark-green-godot-f5f434a7.png",
		"4caf50", "1b5e20", "Pasto", "Bosque"
	],
	[
		"pixellab-tileset-clear-blue-lake-water-2196f3-tone-gentle-pixel-murky-dark-ol-godot-9afb6972.png",
		"2196f3", "556b2f", "Agua", "Pantano"
	],
]


func _run() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TDST, TDST)

	for i: int in SOURCES.size():
		_add_source(ts, i, SOURCES[i])

	var err := ResourceSaver.save(ts, WORLD_TS)
	if err == OK:
		print("[SetupTS] ✓ Guardado: ", WORLD_TS)
		print("[SetupTS]   → Ahora ejecutar bake_chunks.gd para regenerar los chunks.")
	else:
		printerr("[SetupTS] Error %d guardando %s" % [err, WORLD_TS])


func _add_source(ts: TileSet, set_id: int, cfg: Array) -> void:
	var abs_path := ProjectSettings.globalize_path(TILES_DIR + cfg[0])
	if not FileAccess.file_exists(abs_path):
		printerr("[SetupTS] PNG no encontrado: ", abs_path)
		return

	var orig := Image.load_from_file(abs_path)
	if orig == null:
		printerr("[SetupTS] No se pudo cargar: ", abs_path)
		return

	# Reducir a la mitad (32→16 px por tile) con interpolación Nearest para pixel art
	orig.resize(orig.get_width() / 2, orig.get_height() / 2, Image.INTERPOLATE_NEAREST)

	var color_a := Color.html(cfg[1])
	var color_b := Color.html(cfg[2])

	# Terrain set con 2 terrenos (A=0, B=1)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(set_id, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(set_id)
	ts.set_terrain_name(set_id, 0, cfg[3])
	ts.set_terrain_color(set_id, 0, color_a)
	ts.add_terrain(set_id)
	ts.set_terrain_name(set_id, 1, cfg[4])
	ts.set_terrain_color(set_id, 1, color_b)

	# Atlas source con la textura reducida
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(orig)
	src.texture_region_size = Vector2i(TDST, TDST)
	ts.add_source(src)  # source ID == set_id

	var cols := orig.get_width() / TDST
	var rows := orig.get_height() / TDST
	var n    := 0

	for ty: int in rows:
		for tx: int in cols:
			if _is_empty(orig, tx, ty):
				continue

			var ac := Vector2i(tx, ty)
			src.create_tile(ac)
			var td: TileData = src.get_tile_data(ac, 0)
			td.terrain_set = set_id

			# Terreno dominante en el centro del tile
			td.terrain = _pick(orig, tx, ty, 5, 5, 10, 10, color_a, color_b)

			# 8 peering bits: esquinas y lados muestreados en los bordes del tile
			td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
				_pick(orig, tx, ty, 0, 0, 2, 2, color_a, color_b))
			td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE,
				_pick(orig, tx, ty, 5, 0, 10, 2, color_a, color_b))
			td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
				_pick(orig, tx, ty, 13, 0, 15, 2, color_a, color_b))
			td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
				_pick(orig, tx, ty, 13, 5, 15, 10, color_a, color_b))
			td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
				_pick(orig, tx, ty, 13, 13, 15, 15, color_a, color_b))
			td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
				_pick(orig, tx, ty, 5, 13, 10, 15, color_a, color_b))
			td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
				_pick(orig, tx, ty, 0, 13, 2, 15, color_a, color_b))
			td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE,
				_pick(orig, tx, ty, 0, 5, 2, 10, color_a, color_b))
			n += 1

	print("[SetupTS] Set %d (%s↔%s): %d tiles — %s" % [
		set_id, cfg[3], cfg[4], n, cfg[0].left(50)])


# ── Helpers ───────────────────────────────────────────────────────────────────

func _is_empty(img: Image, tx: int, ty: int) -> bool:
	return _avg(img, tx, ty, 5, 5, 10, 10).get_luminance() < 0.08


# Devuelve 0 (terrain A) o 1 (terrain B) según qué color está más cerca
func _pick(img: Image, tx: int, ty: int,
		x0: int, y0: int, x1: int, y1: int, a: Color, b: Color) -> int:
	var c := _avg(img, tx, ty, x0, y0, x1, y1)
	var da := (c.r - a.r)**2 + (c.g - a.g)**2 + (c.b - a.b)**2
	var db := (c.r - b.r)**2 + (c.g - b.g)**2 + (c.b - b.b)**2
	return 0 if da <= db else 1


func _avg(img: Image, tx: int, ty: int, x0: int, y0: int, x1: int, y1: int) -> Color:
	var r := 0.0; var g := 0.0; var b := 0.0; var n := 0
	var ox := tx * TDST; var oy := ty * TDST
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var px := ox + x; var py := oy + y
			if px >= img.get_width() or py >= img.get_height():
				continue
			var c := img.get_pixel(px, py)
			r += c.r; g += c.g; b += c.b; n += 1
	return Color(r / n, g / n, b / n) if n > 0 else Color.BLACK
