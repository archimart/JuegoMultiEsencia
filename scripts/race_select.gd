extends Control

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

const CARD_W      := 140
const CARD_H      := 200
const CARD_GAP    := 24
const GENDER_W    := 72
const GENDER_H    := 52
const GENDER_GAP  := 20

var _races:           Array   = []
var _selected:        int     = -1
var _selected_gender: String  = ""
var _cards:           Array   = []
var _btn_start:       Button  = null
var _gender_panel:    Control = null
var _gender_cards:    Array   = []
var _start_y:         float   = 36.0


func _ready() -> void:
	_load_races()
	_build_ui()


func _load_races() -> void:
	for path: String in RACE_PATHS:
		if ResourceLoader.exists(path):
			_races.append(load(path))


func _build_ui() -> void:
	var vp := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color          = C_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	var title := Label.new()
	title.text     = "Elige tu Raza"
	title.position = Vector2(0.0, 10.0)
	title.size     = Vector2(vp.x, 18.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", C_TEXT)
	add_child(title)

	var n:       int   = _races.size()
	var total_w: float = float(n * CARD_W + max(0, n - 1) * CARD_GAP)
	var start_x: float = roundf((vp.x - total_w) * 0.5)

	for i: int in n:
		var card := _build_race_card(_races[i], i)
		card.position = Vector2(start_x + i * (CARD_W + CARD_GAP), _start_y)
		add_child(card)
		_cards.append(card)

	# Panel de género (oculto hasta que se elija raza)
	_gender_panel = Control.new()
	_gender_panel.position = Vector2(0.0, _start_y + CARD_H + 10.0)
	_gender_panel.size     = Vector2(vp.x, GENDER_H + 18.0)
	_gender_panel.visible  = false
	add_child(_gender_panel)

	var gender_title := Label.new()
	gender_title.text     = "Apariencia"
	gender_title.position = Vector2(0.0, 0.0)
	gender_title.size     = Vector2(vp.x, 14.0)
	gender_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gender_title.add_theme_font_size_override("font_size", 8)
	gender_title.add_theme_color_override("font_color", C_MUTED)
	_gender_panel.add_child(gender_title)

	_btn_start = Button.new()
	_btn_start.text     = "Empezar"
	_btn_start.size     = Vector2(110.0, 22.0)
	_btn_start.position = Vector2(
			roundf((vp.x - 110.0) * 0.5),
			_start_y + CARD_H + 10.0 + GENDER_H + 22.0)
	_btn_start.disabled = true
	_btn_start.add_theme_font_size_override("font_size", 9)
	_btn_start.pressed.connect(_on_start_pressed)
	add_child(_btn_start)


func _build_race_card(race, idx: int) -> Panel:
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
		tr.position     = Vector2(CARD_W * 0.5 - 32.0, 10.0)
		tr.size         = Vector2(64.0, 64.0)
		card.add_child(tr)
	elif not race.sprite_dir_path_f.is_empty():
		var south: String = race.sprite_dir_path_f + "/Idle/rotations/south.png"
		if ResourceLoader.exists(south):
			var tr := TextureRect.new()
			tr.texture      = load(south)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			tr.position     = Vector2(CARD_W * 0.5 - 32.0, 10.0)
			tr.size         = Vector2(64.0, 64.0)
			card.add_child(tr)
	elif not race.sprite_dir_path_m.is_empty():
		var south: String = race.sprite_dir_path_m + "/Idle/rotations/south.png"
		if ResourceLoader.exists(south):
			var tr := TextureRect.new()
			tr.texture      = load(south)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			tr.position     = Vector2(CARD_W * 0.5 - 32.0, 10.0)
			tr.size         = Vector2(64.0, 64.0)
			card.add_child(tr)

	var name_lbl := Label.new()
	name_lbl.text     = race.race_name
	name_lbl.position = Vector2(4.0, 82.0)
	name_lbl.size     = Vector2(CARD_W - 8.0, 14.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	card.add_child(name_lbl)

	var sep := ColorRect.new()
	sep.position = Vector2(8.0, 98.0)
	sep.size     = Vector2(CARD_W - 16.0, 1.0)
	sep.color    = C_BORDER
	card.add_child(sep)

	var stats_txt := "❤ %d   ⚡ %d" % [race.max_hp, int(race.speed)]
	var stats_lbl := _stat_label(stats_txt, Vector2(4.0, 104.0), card)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var comp_name: String = ""
	if race.companion_data != null:
		comp_name = race.companion_data.companion_name
	var comp_lbl := _stat_label("⚔ %s" % comp_name, Vector2(4.0, 118.0), card)
	comp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comp_lbl.size          = Vector2(CARD_W - 8.0, 28.0)
	comp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if not race.description.is_empty():
		var desc := _stat_label(race.description, Vector2(4.0, 152.0), card)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size          = Vector2(CARD_W - 8.0, 40.0)
		desc.add_theme_color_override("font_color", C_MUTED)

	var click := Button.new()
	click.flat     = true
	click.position = Vector2.ZERO
	click.size     = Vector2(CARD_W, CARD_H)
	click.pressed.connect(_on_race_pressed.bind(idx))
	card.add_child(click)

	return card


func _on_race_pressed(idx: int) -> void:
	_selected = idx
	for i: int in _cards.size():
		_cards[i].add_theme_stylebox_override("panel", _sb_card(i == _selected))
	_refresh_gender_panel(_races[_selected])


func _refresh_gender_panel(race) -> void:
	# Eliminar tarjetas de género anteriores
	for old in _gender_cards:
		if is_instance_valid(old):
			old.free()
	_gender_cards.clear()
	_selected_gender = ""
	_btn_start.disabled = true

	var has_m: bool = not race.sprite_dir_path_m.is_empty()
	var has_f: bool = not race.sprite_dir_path_f.is_empty()

	if not has_m and not has_f:
		# Raza sin variantes de género: skip directo
		_gender_panel.visible = false
		_selected_gender      = "m"
		_btn_start.disabled   = false
		return

	_gender_panel.visible = true

	var available: Array[String] = []
	if has_m: available.append("m")
	if has_f: available.append("f")

	var vp       := get_viewport_rect().size
	var total_gw := float(available.size() * GENDER_W + max(0, available.size() - 1) * GENDER_GAP)
	var gx0      := roundf((vp.x - total_gw) * 0.5)

	for gi: int in available.size():
		var g:     String = available[gi]
		var path:  String = race.sprite_dir_path_m if g == "m" else race.sprite_dir_path_f
		var label: String = "Hombre" if g == "m" else "Mujer"
		var gcard := _build_gender_card(path, label, g)
		gcard.position = Vector2(gx0 + gi * (GENDER_W + GENDER_GAP), 16.0)
		_gender_panel.add_child(gcard)
		_gender_cards.append(gcard)

	# Auto-seleccionar si solo hay una opción
	if available.size() == 1:
		_on_gender_pressed(available[0])


func _build_gender_card(sprite_base: String, label_text: String, gender: String) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(GENDER_W, GENDER_H)
	card.size                = Vector2(GENDER_W, GENDER_H)
	card.set_meta("gender", gender)
	card.add_theme_stylebox_override("panel", _sb_card(false))

	var south := sprite_base + "/Idle/rotations/south.png"
	if ResourceLoader.exists(south):
		var tr := TextureRect.new()
		tr.texture      = load(south)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tr.position     = Vector2(GENDER_W * 0.5 - 18.0, 2.0)
		tr.size         = Vector2(36.0, 36.0)
		card.add_child(tr)

	var lbl := Label.new()
	lbl.text     = label_text
	lbl.position = Vector2(0.0, GENDER_H - 13.0)
	lbl.size     = Vector2(GENDER_W, 12.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", C_TEXT)
	card.add_child(lbl)

	var btn := Button.new()
	btn.flat     = true
	btn.position = Vector2.ZERO
	btn.size     = Vector2(GENDER_W, GENDER_H)
	btn.pressed.connect(_on_gender_pressed.bind(gender))
	card.add_child(btn)

	return card


func _on_gender_pressed(gender: String) -> void:
	_selected_gender    = gender
	_btn_start.disabled = false
	for gcard in _gender_cards:
		if is_instance_valid(gcard) and gcard is Panel:
			var sel: bool = gcard.get_meta("gender", "") == gender
			gcard.add_theme_stylebox_override("panel", _sb_card(sel))


func _on_start_pressed() -> void:
	if _selected < 0 or _selected >= _races.size():
		return
	GameState.selected_race   = _races[_selected]
	GameState.selected_gender = _selected_gender
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
	s.bg_color            = C_PANEL
	s.border_color        = C_SELECT if selected else C_BORDER
	s.border_width_left   = 2 if selected else 1
	s.border_width_right  = 2 if selected else 1
	s.border_width_top    = 2 if selected else 1
	s.border_width_bottom = 2 if selected else 1
	s.set_corner_radius_all(3)
	return s
