## Genera un PNG del mundo con transiciones orgánicas entre biomas.
## Cambiar W y H para generar mapas más grandes.
## Ejecutar: Script Editor → ▶ (con cualquier escena abierta).
@tool
extends EditorScript

# ── Tamaño del mapa (tiles) ────────────────────────────────────────────────────
const W       := 400
const H       := 400
const FEATHER := 16   # píxeles de mezcla en bordes entre biomas

# ── Paleta ────────────────────────────────────────────────────────────────────
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

# Zonas (se calculan en _run, se usan en _px_biome)
var _mountain_end: int
var _north_trans:  int
var _mid_start:    int
var _south_start:  int
var _west_end:     int
var _east_start:   int
var _city_x0: int
var _city_x1: int
var _city_y0: int
var _city_y1: int
var _cx: int
var _cy: int


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://assets/maps"))

	var out := "res://assets/maps/world_%dx%d.png" % [W, H]
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)

	# ── Zonas proporcionales ────────────────────────────────────────────────────
	_mountain_end = int(H * 0.20)
	_north_trans  = int(H * 0.17)
	_mid_start    = int(H * 0.20)
	_south_start  = int(H * 0.75)
	_west_end     = int(W * 0.32)
	_east_start   = int(W * 0.68)
	_city_x0 = int(W * 0.38); _city_x1 = int(W * 0.62)
	_city_y0 = int(H * 0.38); _city_y1 = int(H * 0.62)
	_cx = (_city_x0 + _city_x1) / 2
	_cy = (_city_y0 + _city_y1) / 2

	# ── 1. Relleno de biomas con transiciones ───────────────────────────────────
	for y: int in range(1, H - 1):
		for x: int in range(1, W - 1):
			img.set_pixel(x, y, Color.html(_px_biome(x, y)))

	# ── 2. Lagos ────────────────────────────────────────────────────────────────
	_fill_ellipse(img, int(W * 0.78), int(H * 0.84), int(W * 0.07), int(H * 0.04), WATER)
	_fill_ellipse(img, int(W * 0.15), int(H * 0.55), int(W * 0.03), int(H * 0.02), WATER)
	_fill_ellipse(img, int(W * 0.82), int(H * 0.45), int(W * 0.03), int(H * 0.02), WATER)

	# ── 3. Caminos ──────────────────────────────────────────────────────────────
	for y: int in range(0, H):
		for x: int in range(_cx - 2, _cx + 3):
			if x < 1 or x >= W - 1: continue
			if _is(img, x, y, STONE_ST) or _is(img, x, y, WALL): continue
			img.set_pixel(x, y, Color.html(DIRT_ROAD))

	for y: int in range(_cy - 2, _cy + 3):
		for x: int in range(0, W):
			if _is(img, x, y, STONE_ST) or _is(img, x, y, WALL): continue
			img.set_pixel(x, y, Color.html(DIRT_ROAD))

	_draw_road(img, int(W * 0.20), int(H * 0.12), int(W * 0.25), int(H * 0.22))

	# ── 4. Ciudad ───────────────────────────────────────────────────────────────
	for y: int in range(_city_y0, _city_y1):
		for x: int in range(_city_x0, _city_x1):
			img.set_pixel(x, y, Color.html(STONE_ST))

	var cw := _city_x1 - _city_x0
	var ch := _city_y1 - _city_y0
	_place_house(img, _city_x0 + int(cw*0.05), _city_y0 + int(ch*0.05), int(cw*0.12), int(ch*0.10), "south")
	_place_house(img, _city_x0 + int(cw*0.22), _city_y0 + int(ch*0.05), int(cw*0.10), int(ch*0.10), "south")
	_place_house(img, _city_x0 + int(cw*0.60), _city_y0 + int(ch*0.05), int(cw*0.12), int(ch*0.12), "south")
	_place_house(img, _city_x0 + int(cw*0.05), _city_y0 + int(ch*0.55), int(cw*0.10), int(ch*0.10), "east")
	_place_house(img, _city_x0 + int(cw*0.60), _city_y0 + int(ch*0.55), int(cw*0.14), int(ch*0.12), "north")
	_place_house(img, _city_x0 + int(cw*0.75), _city_y0 + int(ch*0.25), int(cw*0.10), int(ch*0.10), "west")

	# ── 5. Cuevas ───────────────────────────────────────────────────────────────
	img.set_pixel(_cx, int(H * 0.10), Color.html(CAVE))
	img.set_pixel(int(W * 0.20), int(H * 0.12), Color.html(CAVE))

	# ── 6. Marcadores ───────────────────────────────────────────────────────────
	img.set_pixel(_cx, _cy, Color.html(SPAWN))
	img.set_pixel(int(W * 0.78), int(H * 0.50), Color.html(POI))
	img.set_pixel(int(W * 0.18), int(H * 0.48), Color.html(POI))
	img.set_pixel(int(W * 0.25), int(H * 0.82), Color.html(POI))
	img.set_pixel(int(W * 0.72), int(H * 0.82), Color.html(POI))

	# ── 7. Muro en borde ────────────────────────────────────────────────────────
	for i: int in W:
		img.set_pixel(i, 0,   Color.html(WALL))
		img.set_pixel(i, H-1, Color.html(WALL))
	for i: int in H:
		img.set_pixel(0,   i, Color.html(WALL))
		img.set_pixel(W-1, i, Color.html(WALL))

	var err := img.save_png(ProjectSettings.globalize_path(out))
	if err != OK:
		printerr("[GenMap] Error %d guardando %s" % [err, out])
		return
	print("[GenMap] ✓ Guardado: %s  (%d×%d tiles)" % [out, W, H])
	print("[GenMap] Chunks: %d×%d  |  Actualizar MAP_PATH en bake_chunks.gd a: %s" % [
		ceili(float(W)/64), ceili(float(H)/64), out])


# ── Color de bioma para un pixel, con bordes orgánicos ───────────────────────
func _px_biome(x: int, y: int) -> String:
	# Dos semillas de ruido independientes para X e Y
	var ny := _noise(x, y)
	var nx := _noise(x + 9999, y + 3333)
	var np := _noise(x * 2 + 1, y * 3 + 7)   # ruido de parches de vegetación

	# Desplazamiento orgánico aplicado al pixel
	var jy := int((ny - 0.5) * FEATHER * 2.0)
	var jx := int((nx - 0.5) * FEATHER * 2.0)
	var yj := y + jy
	var xj := x + jx

	# Norte: montañas nevadas
	if yj < _mountain_end:
		if yj < _north_trans and np < 0.22:
			return ROCK
		return SNOW

	# Sur: desierto (SO) o pantano (SE)
	if yj >= _south_start:
		if xj < W / 2:
			return SAND
		return DARK_GRASS

	# Oeste: pradera con bosque
	if xj < _west_end and yj >= _mid_start:
		return FOREST if np < 0.38 else GRASS

	# Este: bosque élfico
	if xj >= _east_start and yj >= _mid_start:
		return PINK_FOR if np < 0.42 else PINK_GRASS

	# Pasto base con variación de oscuridad
	return GRASS


# ── Helpers ──────────────────────────────────────────────────────────────────

func _noise(x: int, y: int) -> float:
	var n: int = x * 1619 + y * 31337
	n = n ^ (n >> 13)
	n = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff
	return float(n) / float(0x7fffffff)


func _place_house(img: Image, x: int, y: int, w: int, h: int, door_side: String) -> void:
	if w < 2 or h < 2: return
	for ry: int in h:
		for rx: int in w:
			var px := x + rx; var py := y + ry
			if px < 1 or px >= W-1 or py < 1 or py >= H-1: continue
			img.set_pixel(px, py, Color.html(HOUSE))
	var mx := x + w / 2; var my := y + h / 2
	match door_side:
		"south": if y + h < H: img.set_pixel(mx, y + h, Color.html(DOOR))
		"north": if y - 1 >= 0: img.set_pixel(mx, y - 1, Color.html(DOOR))
		"east":  if x + w < W: img.set_pixel(x + w, my, Color.html(DOOR))
		"west":  if x - 1 >= 0: img.set_pixel(x - 1, my, Color.html(DOOR))


func _fill_ellipse(img: Image, ox: int, oy: int, rx: int, ry: int, col: String) -> void:
	for y: int in range(oy - ry, oy + ry + 1):
		for x: int in range(ox - rx, ox + rx + 1):
			if x < 1 or x >= W-1 or y < 1 or y >= H-1: continue
			var dx := float(x - ox) / float(rx)
			var dy := float(y - oy) / float(ry)
			if dx*dx + dy*dy <= 1.0:
				img.set_pixel(x, y, Color.html(col))


func _draw_road(img: Image, x0: int, y0: int, x1: int, y1: int) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	if steps == 0: return
	for i: int in steps + 1:
		var t := float(i) / float(steps)
		var x := roundi(lerp(float(x0), float(x1), t))
		var y := roundi(lerp(float(y0), float(y1), t))
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var px := x + dx; var py := y + dy
				if px < 1 or px >= W-1 or py < 1 or py >= H-1: continue
				if _is(img, px, py, STONE_ST) or _is(img, px, py, WALL): continue
				img.set_pixel(px, py, Color.html(DIRT_ROAD))


func _is(img: Image, x: int, y: int, hex: String) -> bool:
	return _pk(img, x, y) == _hk(hex)


func _hk(hex: String) -> int:
	var c := Color.html(hex)
	return (roundi(c.r*255) << 16) | (roundi(c.g*255) << 8) | roundi(c.b*255)


func _pk(img: Image, x: int, y: int) -> int:
	var c := img.get_pixel(x, y)
	return (roundi(c.r*255) << 16) | (roundi(c.g*255) << 8) | roundi(c.b*255)
