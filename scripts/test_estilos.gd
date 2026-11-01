extends Node2D

# Escena de prueba SOLO para comparar estilos visuales — no forma parte del juego.
# Nota: Kenney Tiny Town NO incluye sprites de personajes; solo edificios y props.
# Los personajes de estilo Kenney vienen de Tiny Dungeon.

const HUNTER_IDLE := "res://assets/Actor/Character/Hunter/SeparateAnim/Idle.png"
const PARROT      := "res://assets/Actor/Animal/Parrot/SpriteSheetBlue.png"
const RACOON      := "res://assets/Actor/Monster/Racoon/SpriteSheet.png"

# Tiny Town: usamos PNGs individuales para evitar cálculos de Rect2
const TT := "res://assets/kenney/kenney_tiny-town/Tiles/"
# Edificio (casa naranja) — 3 cols × 3 filas:
#   fila 0: relleno techo (52×3)
#   fila 1: relleno-L (64), CUMBRERA ▽ (67), relleno-R (66)
#   fila 2: pared-L (72), pared-C (73), pared-R (74)
const TT_ROOF       := TT + "tile_0052.png"  # relleno techo naranja (fila 0)
const TT_FILL_L     := TT + "tile_0064.png"  # relleno techo izq (fila 1)
const TT_PEAK       := TT + "tile_0067.png"  # cumbrera ▽ naranja — identifica la casa
const TT_FILL_R     := TT + "tile_0066.png"  # relleno techo der (fila 1)
const TT_WALL_L     := TT + "tile_0072.png"  # pared ladrillo izq
const TT_WALL_C     := TT + "tile_0073.png"  # pared ladrillo centro
const TT_WALL_R     := TT + "tile_0074.png"  # pared ladrillo der
# Árbol y objetos (Tiny Town no tiene personajes)
const TT_TREE       := TT + "tile_0003.png"  # árbol dorado/otoño
const TT_HAMMER     := TT + "tile_0115.png"  # martillo
const TT_FORK       := TT + "tile_0116.png"  # horca/rastrillo

# Tiny Dungeon: usamos tilemap_packed.png (sin separación, 12×11 tiles de 16px)
# Coordenada = Rect2(col*16, row*16, 16, 16) donde tile_N → row=N//12, col=N%12
const TD := "res://assets/kenney/kenney_tiny-dungeon/Tilemap/tilemap_packed.png"
# Personajes (tiles 84-112 del pack, verificados visualmente)
const TD_MAGE      := Rect2(0,   112, 16, 16)  # tile 84 — mago morado con barba
const TD_FIGHTER   := Rect2(16,  112, 16, 16)  # tile 85 — guerrero marrón
const TD_GHOST     := Rect2(0,   144, 16, 16)  # tile 108 — fantasma verde
const TD_RED_DEMON := Rect2(32,  144, 16, 16)  # tile 110 — demonio rojo
# Objetos
const TD_CHEST     := Rect2(80,  112, 16, 16)  # tile 89 — cofre de madera
const TD_POT_RED   := Rect2(112, 144, 16, 16)  # tile 115 — poción roja
const TD_POT_BLUE  := Rect2(128, 144, 16, 16)  # tile 116 — poción azul

const S3 := Vector2(3.0, 3.0)  # 3× — cada tile 16px → 48px en pantalla

const C_BG    := Color(0.22, 0.42, 0.18)
const C_PANEL := Color(0.0, 0.0, 0.0, 0.45)
const C_DIV   := Color(0.6, 0.6, 0.6, 0.7)
const C_TITLE := Color(1.0, 0.90, 0.45)
const C_MUTED := Color(0.75, 0.80, 0.70)
const C_DIM   := Color(0.55, 0.60, 0.55)


func _ready() -> void:
	_draw_bg()
	_left_panel()
	_right_panel()


func _draw_bg() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.size  = Vector2(640.0, 360.0)
	add_child(bg)

	var div := ColorRect.new()
	div.color    = C_DIV
	div.position = Vector2(319.0, 18.0)
	div.size     = Vector2(2.0, 335.0)
	add_child(div)


func _left_panel() -> void:
	var p := ColorRect.new()
	p.color = C_PANEL; p.position = Vector2(4.0, 18.0); p.size = Vector2(313.0, 335.0)
	add_child(p)

	_lbl("NINJA ADVENTURE", Vector2(4.0, 24.0), 313.0, C_TITLE, 9)
	_lbl("pack de assets Ninja Adventure (CC0)", Vector2(4.0, 38.0), 313.0, C_MUTED, 6)

	_file(HUNTER_IDLE, Rect2(0, 0, 16, 16), Vector2(75.0, 160.0), S3)
	_lbl("Hunter\n(jugador)", Vector2(50.0, 192.0), 56.0, C_MUTED, 6)

	_file(PARROT, Rect2(0, 0, 16, 16), Vector2(160.0, 163.0), S3)
	_lbl("Halcón\n(compañero)", Vector2(132.0, 192.0), 62.0, C_MUTED, 6)

	_file(RACOON, Rect2(0, 0, 16, 16), Vector2(248.0, 160.0), S3)
	_lbl("Mapache\n(monstruo)", Vector2(220.0, 192.0), 62.0, C_MUTED, 6)

	_lbl("16×16 · estilo japonés · paleta suave", Vector2(4.0, 330.0), 313.0, C_MUTED, 6)


func _right_panel() -> void:
	var p := ColorRect.new()
	p.color = C_PANEL; p.position = Vector2(323.0, 18.0); p.size = Vector2(313.0, 335.0)
	add_child(p)

	_lbl("KENNEY TINY TOWN  +  TINY DUNGEON", Vector2(323.0, 24.0), 313.0, C_TITLE, 8)
	_lbl("packs de assets Kenney (CC0)", Vector2(323.0, 38.0), 313.0, C_MUTED, 6)

	# ── Casa (Tiny Town) ────────────────────────────────────────────────────
	# 3 cols × 3 filas a escala 3× = 144×144 px.
	# Fila 0: relleno techo  |  Fila 1: relleno + CUMBRERA ▽ + relleno  |  Fila 2: paredes
	var HX := 333.0; var HY := 48.0; var TS := 48.0
	# Fila 0 — techo superior
	_spr_file(TT_ROOF,   Vector2(HX + TS * 0.5, HY + TS * 0.5), S3)
	_spr_file(TT_ROOF,   Vector2(HX + TS * 1.5, HY + TS * 0.5), S3)
	_spr_file(TT_ROOF,   Vector2(HX + TS * 2.5, HY + TS * 0.5), S3)
	# Fila 1 — cumbrera (la ▽ naranja identifica la casa)
	_spr_file(TT_FILL_L, Vector2(HX + TS * 0.5, HY + TS * 1.5), S3)
	_spr_file(TT_PEAK,   Vector2(HX + TS * 1.5, HY + TS * 1.5), S3)
	_spr_file(TT_FILL_R, Vector2(HX + TS * 2.5, HY + TS * 1.5), S3)
	# Fila 2 — fachada / paredes
	_spr_file(TT_WALL_L, Vector2(HX + TS * 0.5, HY + TS * 2.5), S3)
	_spr_file(TT_WALL_C, Vector2(HX + TS * 1.5, HY + TS * 2.5), S3)
	_spr_file(TT_WALL_R, Vector2(HX + TS * 2.5, HY + TS * 2.5), S3)
	_lbl("Casa\n(Tiny Town)", Vector2(HX - 2.0, HY + TS * 3.0 + 4.0), TS * 3.0, C_MUTED, 6)

	# ── Árbol (Tiny Town) ───────────────────────────────────────────────────
	_spr_file(TT_TREE, Vector2(600.0, 96.0), S3)
	_lbl("Árbol (TT)", Vector2(575.0, 124.0), 56.0, C_DIM, 6)

	# ── Personajes Tiny Dungeon ─────────────────────────────────────────────
	# (Tiny Town no incluye sprites de personajes — solo edificios y props)
	var CY := 252.0
	_atlas(TD, TD_MAGE,      Vector2(345.0, CY), S3)
	_atlas(TD, TD_FIGHTER,   Vector2(393.0, CY), S3)
	_atlas(TD, TD_GHOST,     Vector2(453.0, CY), S3)
	_atlas(TD, TD_RED_DEMON, Vector2(505.0, CY), S3)
	_lbl("Personajes (Tiny Dungeon)",
		Vector2(327.0, CY + 30.0), 230.0, C_MUTED, 6)

	# ── Objetos mezclados ───────────────────────────────────────────────────
	var OY := 318.0
	_atlas(TD, TD_CHEST,    Vector2(340.0, OY), S3)
	_lbl("Cofre (TD)", Vector2(318.0, OY + 24.0), 50.0, C_DIM, 6)

	_atlas(TD, TD_POT_RED,  Vector2(398.0, OY), S3)
	_atlas(TD, TD_POT_BLUE, Vector2(438.0, OY), S3)
	_lbl("Pociones (TD)", Vector2(380.0, OY + 24.0), 76.0, C_DIM, 6)

	_spr_file(TT_HAMMER, Vector2(498.0, OY), S3)
	_spr_file(TT_FORK,   Vector2(546.0, OY), S3)
	_lbl("Herr. (TT)", Vector2(480.0, OY + 24.0), 76.0, C_DIM, 6)

	_lbl("16×16 · estilo occidental · colores saturados", Vector2(323.0, 347.0), 313.0, C_MUTED, 6)


# Sprite desde PNG individual (sin atlas)
func _spr_file(path: String, pos: Vector2, scl: Vector2) -> void:
	var sp := Sprite2D.new()
	sp.texture  = load(path)
	sp.scale    = scl
	sp.position = pos
	add_child(sp)


# Sprite desde AtlasTexture (para el packed tilemap de Tiny Dungeon)
func _atlas(tex_path: String, region: Rect2, pos: Vector2, scl: Vector2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(tex_path)
	atlas.region = region
	var sp := Sprite2D.new()
	sp.texture  = atlas
	sp.scale    = scl
	sp.position = pos
	add_child(sp)


# Sprite desde PNG con recorte (para Ninja Adventure, que no tiene tiles individuales)
func _file(path: String, region: Rect2, pos: Vector2, scl: Vector2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(path)
	atlas.region = region
	var sp := Sprite2D.new()
	sp.texture  = atlas
	sp.scale    = scl
	sp.position = pos
	add_child(sp)


func _lbl(text: String, pos: Vector2, width: float, color: Color, sz: int) -> void:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.size     = Vector2(width, 30.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	add_child(l)
