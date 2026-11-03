## Genera un PNG de 30×20 con todos los colores de la paleta para probar bake_map.gd.
## Ejecutar desde el editor: Script Editor → ▶ (con world.tscn abierto o cualquier escena).
@tool
extends EditorScript

const OUT := "res://assets/maps/test_map_30x20.png"

# Paleta — mismos hex que en bake_map.gd
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


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://assets/maps"))

	var img := Image.create(30, 20, false, Image.FORMAT_RGB8)

	# ── Base: pasto ───────────────────────────────────────────────────────────
	img.fill(Color.html(GRASS))

	# ── Y 0-3: montañas (nieve) ───────────────────────────────────────────────
	for y: int in 4:
		for x: int in 30:
			img.set_pixel(x, y, Color.html(SNOW))
	# Roca con mineral (x 4-8, y 0-2)
	for y: int in range(0, 3):
		for x: int in range(4, 9):
			img.set_pixel(x, y, Color.html(ROCK))
	# Entrada de cueva
	img.set_pixel(14, 2, Color.html(CAVE))

	# ── Y 4-9: zona de pueblo ─────────────────────────────────────────────────
	for y: int in range(4, 10):
		# Camino de tierra de transición
		img.set_pixel(7,  y, Color.html(DIRT_ROAD))
		img.set_pixel(22, y, Color.html(DIRT_ROAD))
		# Calle de piedra central
		for x: int in range(8, 22):
			img.set_pixel(x, y, Color.html(STONE_ST))
		# Pasto rosa a la derecha
		for x: int in range(23, 30):
			img.set_pixel(x, y, Color.html(PINK_GRASS))

	# Casa (3×3) en la calle de piedra, Y 5-7 X 9-11
	for y: int in range(5, 8):
		for x: int in range(9, 12):
			img.set_pixel(x, y, Color.html(HOUSE))
	# Puerta en borde sur centro → la casa mira al sur
	img.set_pixel(10, 7, Color.html(DOOR))

	# Marcadores sobre la calle
	img.set_pixel(14, 6, Color.html(SPAWN))   # punto de aparición
	img.set_pixel(19, 8, Color.html(POI))      # punto de interés

	# ── Y 10-12: transiciones ─────────────────────────────────────────────────
	for y: int in range(10, 13):
		for x: int in range(0, 4):
			img.set_pixel(x, y, Color.html(FOREST))      # bosque verde
		img.set_pixel(7,  y, Color.html(DIRT_ROAD))
		for x: int in range(8, 22):
			img.set_pixel(x, y, Color.html(DIRT_ROAD))   # camino central
		img.set_pixel(22, y, Color.html(DIRT_ROAD))
		for x: int in range(23, 27):
			img.set_pixel(x, y, Color.html(PINK_FOR))    # bosque élfico
		for x: int in range(27, 30):
			img.set_pixel(x, y, Color.html(PINK_GRASS))

	# ── Y 13-15: arena / pasto oscuro ─────────────────────────────────────────
	for y: int in range(13, 16):
		for x: int in range(0, 10):
			img.set_pixel(x, y, Color.html(SAND))
		for x: int in range(20, 30):
			img.set_pixel(x, y, Color.html(DARK_GRASS))

	# ── Y 16: agua / muro ─────────────────────────────────────────────────────
	for x: int in range(0, 10):
		img.set_pixel(x, 16, Color.html(WATER))
	for x: int in range(20, 30):
		img.set_pixel(x, 16, Color.html(WALL))

	# Guardar
	var abs_path := ProjectSettings.globalize_path(OUT)
	var err := img.save_png(abs_path)
	if err != OK:
		printerr("[GenTestMap] Error %d al guardar %s" % [err, abs_path])
		return
	print("[GenTestMap] ✓ Guardado: %s  (30×20 px, %d colores de paleta)" % [OUT, 17])
	print("[GenTestMap] Ahora ejecuta bake_map.gd con world.tscn abierto.")
