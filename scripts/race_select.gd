extends Control

# Para añadir una raza nueva basta con poner su .tres aquí
const RACE_PATHS: Array[String] = [
	"res://resources/race_human.tres",
	"res://resources/race_orc.tres",
	"res://resources/race_elf.tres",
]

const C_BG      := Color(0.07, 0.07, 0.10, 1.00)
const C_PANEL   := Color(0.11, 0.11, 0.16, 1.00)
const C_SELECT  := Color(0.95, 0.78, 0.20, 1.00)
const C_BORDER  := Color(0.22, 0.22, 0.30, 1.00)
const C_TEXT    := Color(0.92, 0.92, 0.85, 1.00)
const C_MUTED   := Color(0.60, 0.60, 0.70, 1.00)
const C_BTN     := Color(0.25, 0.55, 0.25, 1.00)
const C_BTN_OFF := Color(0.18, 0.18, 0.24, 1.00)

const CARD_W    := 140
const CARD_H    := 220
const CARD_GAP  := 24

var _races:    Array      = []
var _selected: int        = -1
var _cards:    Array      = []
var _btn_start: Button    = null


func _ready() -> void:
	_load_races()
	_build_ui()


func _load_races() -> void:
	for path: String in RACE_PATHS:
		if ResourceLoader.exists(path):
			_races.append(load(path))


func _build_ui() -> void:
	var vp := get_viewport_rect().size

	# Fondo oscuro
	var bg := ColorRect.new()
	bg.color              = C_BG
	bg.anchors_preset     = Control.PRESET_FULL_RECT
	add_child(bg)

	# Título
	var title := Label.new()
	title.text     = "Elige tu Raza"
	title.position = Vector2(0.0, 28.0)
	title.size     = Vector2(vp.x, 18.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C_TEXT)
	add_child(title)

	# Calcular posición inicial para centrar las cartas
	var n:       int   = _races.size()
	var total_w: float = float(n * CARD_W + max(0, n - 1) * CARD_GAP)
	var start_x: float = roundf((vp.x - total_w) * 0.5)
	var start_y: float = roundf((vp.y - float(CARD_H)) * 0.5) - 10.0

	for i: int in n:
		var race = _races[i]
		var card := _build_card(race, i)
		card.position = Vector2(start_x + i * (CARD_W + CARD_GAP), start_y)
		add_child(card)
		_cards.append(card)

	# Botón Empezar (desactivado hasta seleccionar)
	_btn_start = Button.new()
	_btn_start.text              = "Empezar"
	_btn_start.size              = Vector2(110.0, 22.0)
	_btn_start.position          = Vector2(roundf((vp.x - 110.0) * 0.5), start_y + CARD_H + 16.0)
	_btn_start.disabled          = true
	_btn_start.add_theme_font_size_override("font_size", 9)
	_btn_start.pressed.connect(_on_start_pressed)
	add_child(_btn_start)


func _build_card(race, idx: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size                = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel", _sb_card(false))

	# Sprite del personaje
	if not race.idle_tex_path.is_empty() and ResourceLoader.exists(race.idle_tex_path):
		var tex: Texture2D = load(race.idle_tex_path)
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
		var tr := TextureRect.new()
		tr.texture      = atlas
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tr.position     = Vector2(CARD_W * 0.5 - 32.0, 14.0)
		tr.size         = Vector2(64.0, 64.0)
		card.add_child(tr)
	elif not race.sprite_dir_path.is_empty():
		var south: String = race.sprite_dir_path + "/Idle/rotations/south.png"
		if ResourceLoader.exists(south):
			var tr := TextureRect.new()
			tr.texture      = load(south)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			tr.position     = Vector2(CARD_W * 0.5 - 32.0, 14.0)
			tr.size         = Vector2(64.0, 64.0)
			card.add_child(tr)

	# Nombre
	var name_lbl := Label.new()
	name_lbl.text     = race.race_name
	name_lbl.position = Vector2(4.0, 86.0)
	name_lbl.size     = Vector2(CARD_W - 8.0, 14.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	card.add_child(name_lbl)

	# Separador
	var sep := ColorRect.new()
	sep.position = Vector2(8.0, 102.0)
	sep.size     = Vector2(CARD_W - 16.0, 1.0)
	sep.color    = C_BORDER
	card.add_child(sep)

	# Stats
	var stats_txt := "❤ %d   ⚡ %d" % [race.max_hp, int(race.speed)]
	var stats_lbl := _stat_label(stats_txt, Vector2(4.0, 108.0), card)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Compañero
	var comp_name: String = ""
	if race.companion_data != null:
		comp_name = race.companion_data.companion_name
	var comp_lbl := _stat_label("⚔ %s" % comp_name, Vector2(4.0, 124.0), card)
	comp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comp_lbl.size          = Vector2(CARD_W - 8.0, 40.0)
	comp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Descripción
	if not race.description.is_empty():
		var desc := _stat_label(race.description, Vector2(4.0, 170.0), card)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size          = Vector2(CARD_W - 8.0, 40.0)
		desc.add_theme_color_override("font_color", C_MUTED)

	# Área de clic
	var click := Button.new()
	click.flat      = true
	click.position  = Vector2.ZERO
	click.size      = Vector2(CARD_W, CARD_H)
	click.pressed.connect(_on_card_pressed.bind(idx))
	card.add_child(click)

	return card


func _on_card_pressed(idx: int) -> void:
	_selected = idx
	_btn_start.disabled = false
	for i: int in _cards.size():
		_cards[i].add_theme_stylebox_override("panel", _sb_card(i == _selected))


func _on_start_pressed() -> void:
	if _selected < 0 or _selected >= _races.size():
		return
	GameState.selected_race = _races[_selected]
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _stat_label(text: String, pos: Vector2, parent: Control) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.size     = Vector2(CARD_W - 8.0, 12.0)
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", C_MUTED)
	parent.add_child(l)
	return l


func _sb_card(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color          = C_PANEL
	s.border_color      = C_SELECT if selected else C_BORDER
	s.border_width_left  = 2 if selected else 1
	s.border_width_right = 2 if selected else 1
	s.border_width_top   = 2 if selected else 1
	s.border_width_bottom = 2 if selected else 1
	s.set_corner_radius_all(3)
	return s
