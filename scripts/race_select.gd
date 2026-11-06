extends Control

# ── Recursos ─────────────────────────────────────────────────────────────────
const RACE_PATHS: Array[String] = [
	"res://resources/race_human.tres",
	"res://resources/race_orc.tres",
	"res://resources/race_elf.tres",
	"res://resources/race_dwarf.tres",
	"res://resources/race_undead.tres",
]
const CLASS_PATHS: Array[String] = [
	"res://resources/class_warrior.tres",
	"res://resources/class_archer.tres",
	"res://resources/class_mage.tres",
]

# ── Colores ───────────────────────────────────────────────────────────────────
const C_BG     := Color(0.07, 0.07, 0.10, 1.00)
const C_PANEL  := Color(0.11, 0.11, 0.16, 1.00)
const C_SELECT := Color(0.95, 0.78, 0.20, 1.00)
const C_BORDER := Color(0.22, 0.22, 0.30, 1.00)
const C_TEXT   := Color(0.92, 0.92, 0.85, 1.00)
const C_MUTED  := Color(0.60, 0.60, 0.70, 1.00)
const C_AFFIN  := Color(0.35, 1.00, 0.50, 1.00)

# ── Tamaños de tarjeta ────────────────────────────────────────────────────────
const CARD_W     := 108
const CARD_H     := 180
const CARD_GAP   := 12
const GENDER_W   := 72
const GENDER_H   := 52
const GENDER_GAP := 20

# ── Presets de color de cabello ───────────────────────────────────────────────
# Colores objetivo para el shader de cabello (0-1, colores reales de cabello).
# El primer elemento es Color(0,0,0,0) = Natural (sin shader).
const HAIR_VALUES: Array[Color] = [
	Color(0.00, 0.00, 0.00, 0.00),  # Natural (sin cambio)
	Color(0.08, 0.05, 0.03, 1.00),  # Negro
	Color(0.42, 0.25, 0.08, 1.00),  # Castaño
	Color(0.90, 0.72, 0.22, 1.00),  # Rubio
	Color(0.80, 0.18, 0.08, 1.00),  # Rojo
	Color(0.52, 0.08, 0.72, 1.00),  # Violeta
	Color(0.12, 0.38, 0.88, 1.00),  # Azul
	Color(0.10, 0.60, 0.22, 1.00),  # Verde
	Color(0.80, 0.80, 0.84, 1.00),  # Plata
]
const HAIR_NAMES: Array[String] = [
	"Natural", "Negro", "Castaño", "Rubio",
	"Rojo", "Violeta", "Azul", "Verde", "Plata",
]

# ── Estado ────────────────────────────────────────────────────────────────────
var _races:                Array   = []
var _classes:              Array   = []
var _selected_race:        int     = -1
var _selected_gender:      String  = ""
var _selected_class:       int     = -1
var _selected_hair_color:  Color   = Color(0, 0, 0, 0)  # alpha=0 = sin cambio
var _selected_variant:     String  = ""                  # "" = sprite original
var _step:                 int     = 0   # 0=raza 1=género 2=clase 3=resumen
var _step_root:            Control = null
var _help_panel:           Control = null


func _ready() -> void:
	_load_races()
	_load_classes()
	_build_bg()
	_build_step()


func _load_races() -> void:
	for path: String in RACE_PATHS:
		if ResourceLoader.exists(path):
			_races.append(load(path))


func _load_classes() -> void:
	for path: String in CLASS_PATHS:
		if ResourceLoader.exists(path):
			_classes.append(load(path))


func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color          = C_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# Botón de ayuda persistente (no pertenece a ningún paso)
	var vp   := get_viewport_rect().size
	var help := Button.new()
	help.text     = "?"
	help.size     = Vector2(20.0, 20.0)
	help.position = Vector2(vp.x - 24.0, vp.y - 24.0)
	help.add_theme_font_size_override("font_size", 11)
	help.pressed.connect(_toggle_help_panel)
	add_child(help)


# ── Navegación ────────────────────────────────────────────────────────────────

func _build_step() -> void:
	if _step_root != null and is_instance_valid(_step_root):
		_step_root.queue_free()
	_step_root = Control.new()
	_step_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_step_root)
	match _step:
		0: _build_race_step()
		1: _build_gender_step()
		2: _build_class_step()
		3: _build_summary_step()


func _go_back() -> void:
	_step = max(0, _step - 1)
	# Si el paso de género no tiene elección real para esta raza, lo saltamos hacia atrás
	if _step == 1 and not _gender_step_has_choice():
		_step = 0
	_build_step()


func _go_next() -> void:
	_step = min(3, _step + 1)
	_build_step()


func _gender_step_has_choice() -> bool:
	if _selected_race < 0 or _selected_race >= _races.size():
		return false
	var race = _races[_selected_race]
	var has_m: bool = not str(race.get("sprite_dir_path_m")).is_empty()
	var has_f: bool = not str(race.get("sprite_dir_path_f")).is_empty()
	return has_m and has_f


func _add_back_btn() -> void:
	var btn := Button.new()
	btn.text     = "← Atrás"
	btn.size     = Vector2(70.0, 18.0)
	btn.position = Vector2(8.0, 8.0)
	btn.add_theme_font_size_override("font_size", 8)
	btn.pressed.connect(_go_back)
	_step_root.add_child(btn)


func _add_title(text: String, y: float = 10.0) -> void:
	var vp    := get_viewport_rect().size
	var label := Label.new()
	label.text     = text
	label.position = Vector2(0.0, y)
	label.size     = Vector2(vp.x, 18.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", C_TEXT)
	_step_root.add_child(label)


# ── Paso 0: Raza ──────────────────────────────────────────────────────────────

func _build_race_step() -> void:
	_add_title("Elige tu Raza")
	var vp     := get_viewport_rect().size
	var n      := _races.size()
	var per_row := mini(n, 3)
	var rows   := ceili(float(n) / float(per_row))
	var start_y := 30.0
	for row: int in rows:
		var count_in_row := mini(per_row, n - row * per_row)
		var total_w := float(count_in_row * CARD_W + max(0, count_in_row - 1) * CARD_GAP)
		var sx      := roundf((vp.x - total_w) * 0.5)
		for col: int in count_in_row:
			var idx  := row * per_row + col
			var card := _build_race_card(_races[idx], idx)
			card.position = Vector2(sx + col * (CARD_W + CARD_GAP), start_y + row * (CARD_H + 10))
			_step_root.add_child(card)


func _build_race_card(race, idx: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size                = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel", _sb_card(idx == _selected_race))

	# Sprite
	_add_race_sprite(race, card, CARD_W, 10.0)

	var name_lbl := Label.new()
	name_lbl.text     = str(race.get("race_name"))
	name_lbl.position = Vector2(4.0, 70.0)
	name_lbl.size     = Vector2(CARD_W - 8.0, 14.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	card.add_child(name_lbl)

	var sep := ColorRect.new()
	sep.position = Vector2(8.0, 86.0)
	sep.size     = Vector2(CARD_W - 16.0, 1.0)
	sep.color    = C_BORDER
	card.add_child(sep)

	_stat_lbl("❤ %d   ⚡ %d" % [int(race.get("max_hp")), int(race.get("speed"))],
			Vector2(4.0, 90.0), card)

	var comp_name := ""
	var comp = race.get("companion_data")
	if comp != null:
		comp_name = str(comp.get("companion_name"))
	_stat_lbl("⚔ %s" % comp_name, Vector2(4.0, 102.0), card)

	var desc := str(race.get("description"))
	if not desc.is_empty():
		var dl := _stat_lbl(desc, Vector2(4.0, 118.0), card)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size          = Vector2(CARD_W - 8.0, 56.0)

	var click := Button.new()
	click.flat     = true
	click.position = Vector2.ZERO
	click.size     = Vector2(CARD_W, CARD_H)
	click.pressed.connect(func() -> void:
		_selected_race   = idx
		_selected_gender = ""
		_go_next()
	)
	card.add_child(click)
	return card


func _add_race_sprite(race, parent: Control, card_w: float, y: float) -> void:
	var tr := TextureRect.new()
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tr.position     = Vector2(card_w * 0.5 - 32.0, y)
	tr.size         = Vector2(64.0, 58.0)

	var idle: String = str(race.get("idle_tex_path"))
	var dir_m: String = str(race.get("sprite_dir_path_m"))
	var dir_f: String = str(race.get("sprite_dir_path_f"))

	if not idle.is_empty() and ResourceLoader.exists(idle):
		var tex: Texture2D = load(idle)
		var atl := AtlasTexture.new()
		atl.atlas  = tex
		atl.region = Rect2(0.0, 0.0, 16.0, 16.0)
		tr.texture = atl
	elif not dir_f.is_empty():
		var p := dir_f + "/Idle/rotations/south.png"
		if ResourceLoader.exists(p):
			tr.texture = load(p)
	elif not dir_m.is_empty():
		var p := dir_m + "/Idle/rotations/south.png"
		if ResourceLoader.exists(p):
			tr.texture = load(p)

	if tr.texture != null:
		parent.add_child(tr)


# ── Paso 1: Género ────────────────────────────────────────────────────────────

func _build_gender_step() -> void:
	if _selected_race < 0 or _selected_race >= _races.size():
		_go_back()
		return
	var race = _races[_selected_race]
	_add_title("Apariencia")
	_add_back_btn()

	var has_m: bool = not str(race.get("sprite_dir_path_m")).is_empty()
	var has_f: bool = not str(race.get("sprite_dir_path_f")).is_empty()

	if not has_m and not has_f:
		# Sin variantes: saltar automáticamente
		_selected_gender = "m"
		_go_next()
		return

	var available: Array[String] = []
	if has_m: available.append("m")
	if has_f: available.append("f")

	var vp       := get_viewport_rect().size
	var total_gw := float(available.size() * GENDER_W + max(0, available.size() - 1) * GENDER_GAP)
	var gx0      := roundf((vp.x - total_gw) * 0.5)

	for gi: int in available.size():
		var g:     String = available[gi]
		var path:  String = str(race.get("sprite_dir_path_m" if g == "m" else "sprite_dir_path_f"))
		var label: String = "Hombre" if g == "m" else "Mujer"
		var gcard := _build_gender_card(path, label, g)
		gcard.position = Vector2(gx0 + gi * (GENDER_W + GENDER_GAP), 30.0)
		_step_root.add_child(gcard)

	if available.size() == 1:
		_selected_gender = available[0]
		_go_next()


func _build_gender_card(sprite_base: String, label_text: String, gender: String) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(GENDER_W, GENDER_H)
	card.size                = Vector2(GENDER_W, GENDER_H)
	card.set_meta("gender", gender)
	card.add_theme_stylebox_override("panel", _sb_card(_selected_gender == gender))

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
	btn.pressed.connect(func() -> void:
		_selected_gender = gender
		_go_next()
	)
	card.add_child(btn)
	return card


# ── Paso 2: Clase ─────────────────────────────────────────────────────────────

func _build_class_step() -> void:
	_add_title("Elige tu Clase")
	_add_back_btn()

	var vp      := get_viewport_rect().size
	var n       := _classes.size()
	var total_w := float(n * CARD_W + max(0, n - 1) * CARD_GAP)
	var sx      := roundf((vp.x - total_w) * 0.5)

	for i: int in n:
		var card := _build_class_card(_classes[i], i)
		card.position = Vector2(sx + i * (CARD_W + CARD_GAP), 30.0)
		_step_root.add_child(card)


func _build_class_card(cls, idx: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size                = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel", _sb_card(idx == _selected_class))

	var icon_lbl := Label.new()
	match str(cls.get("weapon_id")):
		"sword": icon_lbl.text = "⚔"
		"bow":   icon_lbl.text = "🏹"
		"staff": icon_lbl.text = "✨"
	icon_lbl.position = Vector2(0.0, 14.0)
	icon_lbl.size     = Vector2(CARD_W, 32.0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 26)
	card.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text     = str(cls.get("class_label"))
	name_lbl.position = Vector2(4.0, 50.0)
	name_lbl.size     = Vector2(CARD_W - 8.0, 14.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	card.add_child(name_lbl)

	var sep := ColorRect.new()
	sep.position = Vector2(8.0, 66.0)
	sep.size     = Vector2(CARD_W - 16.0, 1.0)
	sep.color    = C_BORDER
	card.add_child(sep)

	_stat_lbl("❤ ×%.1f" % float(cls.get("hp_mult")), Vector2(4.0, 70.0), card)
	_stat_lbl("⚡ ×%.1f" % float(cls.get("speed_mult")), Vector2(4.0, 82.0), card)
	_stat_lbl("⚔ ×%.1f" % float(cls.get("damage_mult")), Vector2(4.0, 94.0), card)

	var desc := str(cls.get("description"))
	if not desc.is_empty():
		var dl := _stat_lbl(desc, Vector2(4.0, 110.0), card)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size          = Vector2(CARD_W - 8.0, 52.0)
		dl.add_theme_color_override("font_color", C_MUTED)

	# Habilidades
	var snames: Array = cls.get("skill_names")
	var slevels: Array = cls.get("skill_levels")
	for si: int in mini(snames.size(), 2):
		var skill_lbl := _stat_lbl(
			"Nv.%d: %s" % [slevels[si], snames[si]],
			Vector2(4.0, 150.0 + si * 10.0), card
		)
		skill_lbl.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))

	# Indicador de afinidad si aplica
	if _selected_race >= 0 and _selected_race < _races.size():
		if _has_affinity(_races[_selected_race], cls):
			var af := Label.new()
			af.text     = "★ Afinidad"
			af.position = Vector2(0.0, CARD_H - 16.0)
			af.size     = Vector2(CARD_W, 12.0)
			af.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			af.add_theme_font_size_override("font_size", 7)
			af.add_theme_color_override("font_color", C_AFFIN)
			card.add_child(af)

	var click := Button.new()
	click.flat     = true
	click.position = Vector2.ZERO
	click.size     = Vector2(CARD_W, CARD_H)
	click.pressed.connect(func() -> void:
		_selected_class = idx
		_go_next()
	)
	card.add_child(click)
	return card


# ── Paso 3: Resumen ───────────────────────────────────────────────────────────

func _build_summary_step() -> void:
	if _selected_race < 0 or _selected_class < 0:
		_go_back()
		return
	var race = _races[_selected_race]
	var cls  = _classes[_selected_class]
	var affinity := _has_affinity(race, cls)
	var mult := 1.1 if affinity else 1.0

	_add_title("Apariencia")
	_add_back_btn()

	var vp  := get_viewport_rect().size
	var cx  := vp.x * 0.5

	var gender := _selected_gender if not _selected_gender.is_empty() else "m"

	# Sprite del personaje
	var sprite_root := Control.new()
	sprite_root.position = Vector2(cx - 32.0, 24.0)
	sprite_root.size     = Vector2(64.0, 64.0)
	_step_root.add_child(sprite_root)
	var tr := TextureRect.new()
	tr.position      = Vector2.ZERO
	tr.size          = Vector2(64.0, 64.0)
	tr.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	var dir_key  := "sprite_dir_path_m" if gender == "m" else "sprite_dir_path_f"
	var idle_tex: String = str(race.get("idle_tex_path"))
	var dir_path: String = str(race.get(dir_key))
	if not idle_tex.is_empty() and ResourceLoader.exists(idle_tex):
		var tex: Texture2D = load(idle_tex)
		var atl := AtlasTexture.new()
		atl.atlas  = tex
		atl.region = Rect2(0.0, 0.0, 16.0, 16.0)
		tr.texture = atl
	elif not dir_path.is_empty():
		var p := dir_path + "/Idle/rotations/south.png"
		if ResourceLoader.exists(p):
			tr.texture = load(p)
	sprite_root.add_child(tr)

	# Picker: variantes pre-coloreadas tienen prioridad sobre el shader de cabello
	var v_dirs  = race.get("sprite_variant_dirs_f")  if gender == "f" else race.get("sprite_variant_dirs_m")
	var v_names = race.get("sprite_variant_names_f") if gender == "f" else race.get("sprite_variant_names_m")
	var orig_dir: String = str(race.get("sprite_dir_path_f") if gender == "f" else race.get("sprite_dir_path_m"))
	if v_dirs != null and not v_dirs.is_empty():
		_selected_variant = ""
		_build_variant_picker(tr, vp, cx, 93.0, orig_dir, v_dirs, v_names)
	else:
		_selected_variant = ""
		var hair_src: Color = race.get("hair_color_m") if gender == "m" else race.get("hair_color_f")
		if hair_src != null and hair_src.a > 0.1:
			_build_hair_picker(tr, vp, cx, 93.0, hair_src)
		else:
			_selected_hair_color = Color(0, 0, 0, 0)

	# Panel de stats
	var panel := Panel.new()
	var pw    := 220.0
	var py    := 136.0
	panel.position = Vector2(cx - pw * 0.5, py)
	panel.size     = Vector2(pw, 120.0)
	panel.add_theme_stylebox_override("panel", _sb_card(false))
	_step_root.add_child(panel)

	var final_hp    := int(float(int(race.get("max_hp"))) * float(cls.get("hp_mult")) * mult)
	var final_speed := int(float(race.get("speed")) * float(cls.get("speed_mult")) * mult)
	var final_dmg   := float(race.get("damage_multiplier")) * float(cls.get("damage_mult")) * mult
	var comp_name   := ""
	var comp = race.get("companion_data")
	if comp != null:
		comp_name = str(comp.get("companion_name"))

	var lines: Array[String] = [
		"Raza: %s  ·  Clase: %s" % [str(race.get("race_name")), str(cls.get("class_label"))],
		"❤ HP: %d     ⚡ Velocidad: %d" % [final_hp, final_speed],
		"⚔ Daño: ×%.2f" % final_dmg,
		"🐾 Compañero: %s" % comp_name,
		"🗡 Arma: %s" % str(cls.get("weapon_id")),
	]
	if affinity:
		lines.append("★ Afinidad: +10 % stats")

	for i: int in lines.size():
		var color := C_AFFIN if i == lines.size() - 1 and affinity else \
					 C_TEXT  if i == 0 else C_MUTED
		var row := Label.new()
		row.text     = lines[i]
		row.position = Vector2(8.0, 5.0 + i * 19.0)
		row.size     = Vector2(pw - 16.0, 17.0)
		row.add_theme_font_size_override("font_size", 8)
		row.add_theme_color_override("font_color", color)
		panel.add_child(row)

	# Botón Empezar
	var btn := Button.new()
	btn.text     = "▶ Empezar"
	btn.size     = Vector2(120.0, 24.0)
	btn.position = Vector2(cx - 60.0, py + 128.0)
	btn.add_theme_font_size_override("font_size", 10)
	btn.pressed.connect(_on_start_pressed)
	_step_root.add_child(btn)


# ── Inicio del juego ─────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	if _selected_race < 0 or _selected_class < 0:
		return
	GameState.selected_race           = _races[_selected_race]
	GameState.selected_gender         = _selected_gender if not _selected_gender.is_empty() else "m"
	GameState.selected_class          = _classes[_selected_class]
	GameState.selected_hair_color     = _selected_hair_color
	GameState.selected_sprite_variant = _selected_variant
	get_tree().change_scene_to_file("res://scenes/world.tscn")


# ── Bonus de afinidad ─────────────────────────────────────────────────────────

func _has_affinity(race, cls) -> bool:
	var rn: String = str(race.get("race_name"))
	var cl: String = str(cls.get("class_label"))
	return (rn == "Orco"     and cl == "Guerrero") or \
		   (rn == "Elfo"     and cl == "Arquero")  or \
		   (rn == "No-muerto" and cl == "Mago")


# ── Selector de color de cabello ─────────────────────────────────────────────

func _build_hair_picker(
		sprite_ref: TextureRect, vp: Vector2, _cx: float,
		y: float, hair_src: Color) -> void:
	var lbl := Label.new()
	lbl.text = "Color de cabello:"
	lbl.position = Vector2(0.0, y)
	lbl.size = Vector2(vp.x, 10.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", C_MUTED)
	_step_root.add_child(lbl)

	const SWATCH_S: int = 16
	const SWATCH_G: int = 3
	var n := HAIR_VALUES.size()
	var total_w := n * SWATCH_S + (n - 1) * SWATCH_G
	var sx0 := roundf((vp.x - float(total_w)) * 0.5)
	var sy  := y + 12.0

	var swatches: Array[Panel] = []
	for i: int in n:
		var val := HAIR_VALUES[i]
		# El swatch Natural muestra el color original del cabello de la raza
		var display_col := hair_src if val.a < 0.1 else val
		var is_sel: bool = (i == 0 and _selected_hair_color.a < 0.1) or \
						   (i > 0 and val.is_equal_approx(_selected_hair_color))

		var sw := Panel.new()
		sw.position = Vector2(sx0 + float(i) * float(SWATCH_S + SWATCH_G), sy)
		sw.size = Vector2(float(SWATCH_S), float(SWATCH_S))
		sw.add_theme_stylebox_override("panel", _swatch_sb(display_col, is_sel))
		sw.tooltip_text = HAIR_NAMES[i]
		_step_root.add_child(sw)
		swatches.append(sw)

		var sbtn := Button.new()
		sbtn.flat     = true
		sbtn.position = Vector2.ZERO
		sbtn.size     = Vector2(float(SWATCH_S), float(SWATCH_S))
		sbtn.pressed.connect(func() -> void:
			_selected_hair_color = val
			# Aplicar shader al preview
			if val.a < 0.1:
				sprite_ref.material = null
			else:
				var mat := ShaderMaterial.new()
				mat.shader = preload("res://shaders/hair_tint.gdshader")
				mat.set_shader_parameter("hair_source", hair_src)
				mat.set_shader_parameter("hair_target", val)
				sprite_ref.material = mat
			# Actualizar bordes de swatches
			for j: int in swatches.size():
				var sel_j: bool = (j == 0 and _selected_hair_color.a < 0.1) or \
								  (j > 0 and HAIR_VALUES[j].is_equal_approx(_selected_hair_color))
				var dc_j := hair_src if HAIR_VALUES[j].a < 0.1 else HAIR_VALUES[j]
				swatches[j].add_theme_stylebox_override("panel", _swatch_sb(dc_j, sel_j))
		)
		sw.add_child(sbtn)


func _build_variant_picker(
		sprite_ref: TextureRect, vp: Vector2, _cx: float, y: float,
		orig_dir: String, variant_dirs: Array, variant_names: Array) -> void:
	var lbl := Label.new()
	lbl.text = "Variante de aspecto:"
	lbl.position = Vector2(0.0, y)
	lbl.size = Vector2(vp.x, 10.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", C_MUTED)
	_step_root.add_child(lbl)

	# Construir la lista completa: "Natural" (original) + las variantes
	var all_dirs: Array[String]  = []
	var all_names: Array[String] = []
	all_dirs.append(orig_dir)
	all_names.append("Natural")
	for d in variant_dirs:
		all_dirs.append(str(d))
	for n in variant_names:
		all_names.append(str(n))

	const SWATCH_S: int = 24
	const SWATCH_G: int = 6
	var n := all_dirs.size()
	var total_w := n * SWATCH_S + (n - 1) * SWATCH_G
	var sx0 := roundf((vp.x - float(total_w)) * 0.5)
	var sy  := y + 12.0

	var swatches: Array[Panel] = []
	for i: int in n:
		var dir := all_dirs[i]
		var is_sel: bool = (i == 0 and _selected_variant.is_empty()) or \
						   (i > 0 and dir == _selected_variant)

		var sw := Panel.new()
		sw.position = Vector2(sx0 + float(i) * float(SWATCH_S + SWATCH_G), sy)
		sw.size = Vector2(float(SWATCH_S), float(SWATCH_S))
		sw.add_theme_stylebox_override("panel", _sb_card(is_sel))
		sw.tooltip_text = all_names[i]
		_step_root.add_child(sw)
		swatches.append(sw)

		# Miniatura del sprite dentro del swatch
		var thumb := TextureRect.new()
		thumb.position = Vector2(4.0, 2.0)
		thumb.size = Vector2(16.0, 20.0)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		var tex := _load_south_tex(dir)
		if tex != null:
			thumb.texture = tex
		sw.add_child(thumb)

		# Label con el nombre debajo de la miniatura
		var nlbl := Label.new()
		nlbl.text = all_names[i]
		nlbl.position = Vector2(0.0, 18.0)
		nlbl.size = Vector2(float(SWATCH_S), 6.0)
		nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nlbl.add_theme_font_size_override("font_size", 5)
		nlbl.add_theme_color_override("font_color", C_TEXT)
		sw.add_child(nlbl)

		var sbtn := Button.new()
		sbtn.flat     = true
		sbtn.position = Vector2.ZERO
		sbtn.size     = Vector2(float(SWATCH_S), float(SWATCH_S))
		sbtn.pressed.connect(func() -> void:
			_selected_variant = "" if i == 0 else dir
			# Actualizar preview principal
			var new_tex := _load_south_tex("" if i == 0 else dir)
			if new_tex == null:
				new_tex = _load_south_tex(orig_dir)
			sprite_ref.texture = new_tex
			# Actualizar bordes de swatches
			for j: int in swatches.size():
				var sel_j: bool = (j == 0 and _selected_variant.is_empty()) or \
								  (j > 0 and all_dirs[j] == _selected_variant)
				swatches[j].add_theme_stylebox_override("panel", _sb_card(sel_j))
		)
		sw.add_child(sbtn)


func _load_south_tex(base_dir: String) -> Texture2D:
	var dir := DirAccess.open(base_dir)
	if dir:
		dir.list_dir_begin()
		var sub := dir.get_next()
		while not sub.is_empty():
			if dir.current_is_dir() and not sub.begins_with("."):
				var p := base_dir + "/" + sub + "/rotations/south.png"
				if ResourceLoader.exists(p):
					return load(p)
			sub = dir.get_next()
	return null


func _swatch_sb(col: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = col
	s.border_color        = C_SELECT if selected else C_BORDER
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.set_corner_radius_all(2)
	return s


# ── Helpers UI ────────────────────────────────────────────────────────────────

func _stat_lbl(text: String, pos: Vector2, parent: Control) -> Label:
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


# ── Panel de ayuda / controles ────────────────────────────────────────────────

func _toggle_help_panel() -> void:
	if _help_panel != null and is_instance_valid(_help_panel):
		_help_panel.queue_free()
		_help_panel = null
		return
	var vp  := get_viewport_rect().size
	const W := 260.0
	const H := 210.0

	_help_panel = Panel.new()
	_help_panel.position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)
	_help_panel.size     = Vector2(W, H)
	_help_panel.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.08, 0.12, 0.97)))
	add_child(_help_panel)

	var title := Label.new()
	title.text     = "Controles y combate"
	title.position = Vector2(0.0, 6.0)
	title.size     = Vector2(W, 14.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", C_TEXT)
	_help_panel.add_child(title)

	var sep := ColorRect.new()
	sep.position = Vector2(8.0, 22.0)
	sep.size     = Vector2(W - 16.0, 1.0)
	sep.color    = C_BORDER
	_help_panel.add_child(sep)

	var lines: Array[String] = [
		"[Movimiento]   Flechas / WASD",
		"[Atacar]       Clic izquierdo",
		"[Interactuar]  E",
		"[Inventario]   I / Tab",
		"[Compañeros]   C",
		"[Cambiar comp] [  /  ]",
		"[Ayuda]        H  (en partida)",
		"",
		"Combate:",
		"• Mata criaturas → oro + XP + esencias",
		"• Esencias suficientes → compañero nuevo",
		"• El compañero ataca si te golpean",
		"• El pueblo regenera vida (zona segura)",
		"• Al morir: sueltas la mochila 5 min",
	]
	for i: int in lines.size():
		var lbl := Label.new()
		lbl.text     = lines[i]
		lbl.position = Vector2(12.0, 26.0 + i * 12.0)
		lbl.size     = Vector2(W - 16.0, 12.0)
		lbl.add_theme_font_size_override("font_size", 7)
		var col := Color(1.0, 0.9, 0.5) if i == 8 else C_TEXT
		lbl.add_theme_color_override("font_color", col)
		_help_panel.add_child(lbl)

	var close := Button.new()
	close.text     = "✕ Cerrar"
	close.position = Vector2(W * 0.5 - 35.0, H - 20.0)
	close.size     = Vector2(70.0, 15.0)
	close.add_theme_font_size_override("font_size", 7)
	close.pressed.connect(_toggle_help_panel)
	_help_panel.add_child(close)


func _sb(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(3)
	return s
