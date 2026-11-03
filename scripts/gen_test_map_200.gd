## Genera un PNG de 200×200 tiles con todos los terrenos de la paleta.
## Diseño: montañas al norte, pradera oeste, elfico este, desierto/pantano sur,
## pueblo de piedra en el centro (x 80-119, y 80-119), caminos cruzados.
## Ejecutar: Script Editor → ▶ (con cualquier escena abierta).
@tool
extends EditorScript

const OUT := "res://assets/maps/test_map_200x200.png"

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

const W := 200
const H := 200

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://assets/maps"))

	var img := Image.create(W, H, false, Image.FORMAT_RGB8)

	# ── Base: pasto ────────────────────────────────────────────────────────────
	img.fill(Color.html(GRASS))

	# ── Norte (y 0-79): montañas de nieve ─────────────────────────────────────
	for y: int in range(0, 80):
		for x: int in range(0, W):
			var c: String = SNOW
			# parches de roca con mineral
			if (x + y * 3) % 11 < 2 and y > 10:
				c = ROCK
			# banda de transición sur de montañas: pasto sencillo
			if y >= 65:
				c = GRASS
			img.set_pixel(x, y, Color.html(c))

	# ── Entrada de cueva en las montañas (sobre el camino norte) ──────────────
	img.set_pixel(99, 25, Color.html(CAVE))

	# ── Oeste (x 0-69, y 80-149): pradera con bosque ──────────────────────────
	for y: int in range(80, 150):
		for x: int in range(0, 70):
			var c: String = GRASS
			if (x * 7 + y * 3) % 13 < 3:
				c = FOREST
			img.set_pixel(x, y, Color.html(c))

	# ── Este (x 130-199, y 80-149): bosque élfico ─────────────────────────────
	for y: int in range(80, 150):
		for x: int in range(130, W):
			var c: String = PINK_GRASS
			if (x * 5 + y * 7) % 11 < 3:
				c = PINK_FOR
			img.set_pixel(x, y, Color.html(c))

	# ── Sur-oeste (x 0-99, y 150-199): desierto ───────────────────────────────
	for y: int in range(150, H):
		for x: int in range(0, 100):
			img.set_pixel(x, y, Color.html(SAND))

	# ── Sur-este (x 100-199, y 150-199): pantano ─────────────────────────────
	for y: int in range(150, H):
		for x: int in range(100, W):
			img.set_pixel(x, y, Color.html(DARK_GRASS))

	# ── Lago pequeño en el pantano ────────────────────────────────────────────
	for y: int in range(162, 175):
		for x: int in range(148, 162):
			img.set_pixel(x, y, Color.html(WATER))

	# ── Camino vertical (x 97-101) que cruza todo el mapa ─────────────────────
	for y: int in range(0, H):
		for x: int in range(97, 103):
			if _is_stone(img, x, y): continue
			img.set_pixel(x, y, Color.html(DIRT_ROAD))

	# ── Camino horizontal (y 97-101) que cruza todo el mapa ───────────────────
	for y: int in range(97, 103):
		for x: int in range(0, W):
			if _is_stone(img, x, y): continue
			img.set_pixel(x, y, Color.html(DIRT_ROAD))

	# ── Pueblo (calle de piedra) en el centro: x 80-119, y 80-119 ─────────────
	for y: int in range(80, 120):
		for x: int in range(80, 120):
			img.set_pixel(x, y, Color.html(STONE_ST))

	# ── Casas en el pueblo ────────────────────────────────────────────────────
	_place_house(img, 83, 83, 5, 4, "south")
	_place_house(img, 91, 83, 4, 4, "south")
	_place_house(img, 83, 91, 4, 4, "east")
	_place_house(img, 108, 84, 5, 5, "south")
	_place_house(img, 107, 107, 6, 5, "north")

	# ── Marcadores ────────────────────────────────────────────────────────────
	img.set_pixel(99, 99, Color.html(SPAWN))     # spawn central
	img.set_pixel(158, 100, Color.html(POI))     # POI élfico
	img.set_pixel(40,  120, Color.html(POI))     # POI pradera

	# ── Muro en borde (1 px) ──────────────────────────────────────────────────
	for i: int in W:
		img.set_pixel(i, 0,   Color.html(WALL))
		img.set_pixel(i, H-1, Color.html(WALL))
	for i: int in H:
		img.set_pixel(0,   i, Color.html(WALL))
		img.set_pixel(W-1, i, Color.html(WALL))

	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	if err != OK:
		printerr("[GenMap200] Error %d guardando %s" % [err, OUT])
		return
	print("[GenMap200] ✓ Guardado: %s  (%d×%d tiles)" % [OUT, W, H])
	print("[GenMap200] Chunks: %d×%d = %d  (tamaño chunk: 64 tiles)" % [
		ceili(float(W)/64), ceili(float(H)/64),
		ceili(float(W)/64) * ceili(float(H)/64)])


func _place_house(img: Image, x: int, y: int, w: int, h: int, door_side: String) -> void:
	for ry: int in h:
		for rx: int in w:
			img.set_pixel(x + rx, y + ry, Color.html(HOUSE))
	# Puerta en el centro del lado indicado
	var mx := x + w / 2
	var my := y + h / 2
	match door_side:
		"south": img.set_pixel(mx, y + h,     Color.html(DOOR))
		"north": img.set_pixel(mx, y - 1,     Color.html(DOOR))
		"east":  img.set_pixel(x + w, my,     Color.html(DOOR))
		"west":  img.set_pixel(x - 1, my,     Color.html(DOOR))


func _is_stone(img: Image, x: int, y: int) -> bool:
	var c := img.get_pixel(x, y)
	var key := (roundi(c.r * 255) << 16) | (roundi(c.g * 255) << 8) | roundi(c.b * 255)
	return key == int("0x" + STONE_ST)
