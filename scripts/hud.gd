extends CanvasLayer

# ── Layout ────────────────────────────────────────────────────────────────────
const HOTBAR_N   := 8
const HOTBAR_S   := 18    # tamaño exterior del slot
const HOTBAR_GAP := 2
const HOTBAR_PAD := 3

const INV_COLS := 4
const INV_S    := 20    # tamaño exterior del slot en inventario
const INV_GAP  := 2

# ── Colores ───────────────────────────────────────────────────────────────────
const C_BG     := Color(0.07, 0.07, 0.10, 0.82)
const C_INV_BG := Color(0.07, 0.07, 0.10, 0.94)
const C_SLOT   := Color(0.10, 0.10, 0.16, 0.90)
const C_BORDER := Color(0.25, 0.25, 0.35, 0.90)
const C_TEXT   := Color(0.92, 0.92, 0.85, 1.00)
const C_SHADOW := Color(0.00, 0.00, 0.00, 0.85)
const C_MUTED  := Color(0.60, 0.60, 0.70, 1.00)

# ── Iconos del panel de stats ─────────────────────────────────────────────────
const ICON_HEART := "res://assets/Items/Potion/Heart.png"
const ICON_COIN  := "res://assets/Items/Treasure/GoldCoin.png"
const ICON_ARROW := "res://assets/Items/Projectile/Arrow.png"

# ── Estado ────────────────────────────────────────────────────────────────────
var _player:    Node2D
var _notice_id: int        = 0
var _item_reg:  Dictionary = {}   # item_id -> Resource (ItemData)

# Refs panel stats
var _hp_fill:  ColorRect
var _gold_lbl: Label
var _arr_lbl:  Label

# Refs panel compañero
var _comp_lvl_lbl: Label
var _comp_xp_fill: ColorRect

# Refs hotbar (arrays en paralelo, tamaño HOTBAR_N)
var _hb_icons:  Array[TextureRect] = []
var _hb_counts: Array[Label]       = []

# Inventario (null cuando está cerrado)
var _inv_panel: Panel         = null
var _inv_grid:  GridContainer = null

# Aviso / hint
var _hint_lbl: Label


# ── API pública ───────────────────────────────────────────────────────────────

func set_player(p: Node2D) -> void:
	_player = p
	p.inventory_changed.connect(_refresh)
	p.health_changed.connect(_update_hp)
	p.notice_requested.connect(show_notice)
	_refresh()
	_update_hp()


# ── Ciclo de vida ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_item_reg()
	_reg_inv_action()
	_build_stats()
	_build_companion_panel()
	_build_hotbar()
	_build_hint()


func _load_item_reg() -> void:
	for id: String in ["wood", "bow", "arrows", "gold"]:
		var path := "res://resources/item_" + id + ".tres"
		if ResourceLoader.exists(path):
			_item_reg[id] = load(path)


func _reg_inv_action() -> void:
	if InputMap.has_action("inventory"):
		return
	InputMap.add_action("inventory")
	for kc: int in [KEY_I, KEY_TAB]:
		var ev := InputEventKey.new()
		ev.keycode = kc
		InputMap.action_add_event("inventory", ev)


# ── Panel de stats (arriba-izquierda) ─────────────────────────────────────────

func _build_stats() -> void:
	var root := Panel.new()
	root.position = Vector2(3, 3)
	root.size     = Vector2(92, 28)
	root.add_theme_stylebox_override("panel", _sb(C_BG))
	add_child(root)

	# Fila 1: corazón + barra de HP
	_tex(root, ICON_HEART, Vector2(4, 4), Vector2(9, 8))
	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(15, 5)
	hp_bg.size     = Vector2(50, 6)
	hp_bg.color    = Color(0.15, 0.15, 0.15, 1)
	root.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2(15, 5)
	_hp_fill.size     = Vector2(50, 6)
	_hp_fill.color    = Color(0.25, 0.85, 0.25, 1)
	root.add_child(_hp_fill)

	# Fila 2: moneda | flechas
	_tex(root, ICON_COIN, Vector2(4, 16), Vector2(8, 8))
	_gold_lbl = _lbl("0", Vector2(14, 15), root, 7)
	var sep := ColorRect.new()
	sep.position = Vector2(44, 14)
	sep.size     = Vector2(1, 12)
	sep.color    = Color(0.4, 0.4, 0.5, 0.40)
	root.add_child(sep)
	_tex(root, ICON_ARROW, Vector2(48, 15), Vector2(8, 8))
	_arr_lbl = _lbl("0", Vector2(58, 15), root, 7)


func set_companion(comp: Node) -> void:
	comp.xp_changed.connect(_update_comp_xp)
	comp.level_changed.connect(_update_comp_level)
	comp.notice_requested.connect(show_notice)
	_update_comp_level(comp.get_level_display())
	_update_comp_xp(0, comp._get_xp_to_next())


func _build_companion_panel() -> void:
	var root := Panel.new()
	root.position = Vector2(3, 34)
	root.size     = Vector2(92, 16)
	root.add_theme_stylebox_override("panel", _sb(C_BG))
	add_child(root)

	# Icono de pluma / pájaro (usamos la letra "H" como placeholder; el artista puede poner textura)
	var icon_lbl := Label.new()
	icon_lbl.text     = "Hk"
	icon_lbl.position = Vector2(3, 2)
	icon_lbl.size     = Vector2(12, 12)
	icon_lbl.add_theme_font_size_override("font_size", 6)
	icon_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	root.add_child(icon_lbl)

	_comp_lvl_lbl = Label.new()
	_comp_lvl_lbl.text     = "Nv.1"
	_comp_lvl_lbl.position = Vector2(15, 2)
	_comp_lvl_lbl.size     = Vector2(22, 8)
	_comp_lvl_lbl.add_theme_font_size_override("font_size", 6)
	_comp_lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	root.add_child(_comp_lvl_lbl)

	# Fondo de barra XP
	var xp_bg := ColorRect.new()
	xp_bg.position = Vector2(38, 5)
	xp_bg.size     = Vector2(50, 5)
	xp_bg.color    = Color(0.12, 0.12, 0.12, 1)
	root.add_child(xp_bg)

	_comp_xp_fill = ColorRect.new()
	_comp_xp_fill.position = Vector2(38, 5)
	_comp_xp_fill.size     = Vector2(0, 5)
	_comp_xp_fill.color    = Color(0.35, 0.65, 1.0, 1)
	root.add_child(_comp_xp_fill)


func _update_comp_level(lvl: int) -> void:
	if _comp_lvl_lbl == null:
		return
	var max_lvl: int = 5
	_comp_lvl_lbl.text = "Nv.%d" % lvl if lvl < max_lvl else "Nv.MÁX"


func _update_comp_xp(current: int, to_next: int) -> void:
	if _comp_xp_fill == null:
		return
	if to_next <= 0:
		_comp_xp_fill.size.x = 50.0
		_comp_xp_fill.color  = Color(1.0, 0.75, 0.1)
		return
	var r := clampf(float(current) / float(to_next), 0.0, 1.0)
	_comp_xp_fill.size.x = 50.0 * r


func _update_hp() -> void:
	if _player == null or _hp_fill == null:
		return
	var r := clampf(float(_player.hp) / float(_player.max_hp), 0.0, 1.0)
	_hp_fill.size.x = 50.0 * r
	_hp_fill.color  = Color(0.25, 0.85, 0.25) if r > 0.5 else Color(0.90, 0.30, 0.10)


# ── Barra rápida (abajo-centro) ───────────────────────────────────────────────

func _build_hotbar() -> void:
	var tw := HOTBAR_N * HOTBAR_S + (HOTBAR_N - 1) * HOTBAR_GAP
	var pw := tw + HOTBAR_PAD * 2
	var ph := HOTBAR_S + HOTBAR_PAD * 2
	var vp := get_viewport().get_visible_rect().size

	var root := Panel.new()
	root.position = Vector2(roundf((vp.x - pw) * 0.5), vp.y - ph - 2)
	root.size     = Vector2(pw, ph)
	root.add_theme_stylebox_override("panel", _sb(C_BG))
	add_child(root)

	for i: int in HOTBAR_N:
		var sx   := HOTBAR_PAD + i * (HOTBAR_S + HOTBAR_GAP)
		var slot := Panel.new()
		slot.position = Vector2(sx, HOTBAR_PAD)
		slot.size     = Vector2(HOTBAR_S, HOTBAR_S)
		slot.add_theme_stylebox_override("panel", _sb_slot())
		root.add_child(slot)

		const ICON_S := 12
		const OFF    := (HOTBAR_S - ICON_S) / 2
		var icon := TextureRect.new()
		icon.position    = Vector2(OFF, OFF)
		icon.size        = Vector2(ICON_S, ICON_S)
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)
		_hb_icons.append(icon)

		var cnt := Label.new()
		cnt.position = Vector2(HOTBAR_S - 10, HOTBAR_S - 9)
		cnt.size     = Vector2(9, 8)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_font_size_override("font_size", 6)
		cnt.add_theme_color_override("font_color",        C_TEXT)
		cnt.add_theme_color_override("font_shadow_color", C_SHADOW)
		cnt.add_theme_constant_override("shadow_offset_x", 1)
		cnt.add_theme_constant_override("shadow_offset_y", 1)
		slot.add_child(cnt)
		_hb_counts.append(cnt)


# ── Inventario completo (toggle I / Tab) ──────────────────────────────────────

func _toggle_inventory() -> void:
	if _inv_panel != null:
		_inv_panel.queue_free()
		_inv_panel = null
		_inv_grid  = null
		return
	if _player == null:
		return
	_open_inventory()


func _open_inventory() -> void:
	var keys: Array = _player.inventory.keys()
	var rows: int   = max(1, ceili(float(keys.size()) / float(INV_COLS)))
	const PAD:   int = 6
	const TITLE: int = 14
	const CLOSE: int = 11
	var iw: int = INV_COLS * INV_S + (INV_COLS - 1) * INV_GAP
	var ih: int = rows * INV_S + max(0, rows - 1) * INV_GAP
	var pw: int = iw + PAD * 2
	var ph: int = TITLE + ih + CLOSE + PAD * 2 + 4
	var vp := get_viewport().get_visible_rect().size

	_inv_panel = Panel.new()
	_inv_panel.position = Vector2(roundf((vp.x - pw) * 0.5), roundf((vp.y - ph) * 0.5))
	_inv_panel.size     = Vector2(pw, ph)
	_inv_panel.add_theme_stylebox_override("panel", _sb(C_INV_BG))
	add_child(_inv_panel)

	var title := _lbl("Inventario", Vector2(0, 2), _inv_panel, 8)
	title.size = Vector2(pw, TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sep := ColorRect.new()
	sep.position = Vector2(PAD, TITLE)
	sep.size     = Vector2(iw, 1)
	sep.color    = Color(0.4, 0.4, 0.5, 0.50)
	_inv_panel.add_child(sep)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = INV_COLS
	_inv_grid.add_theme_constant_override("h_separation", INV_GAP)
	_inv_grid.add_theme_constant_override("v_separation", INV_GAP)
	_inv_grid.position = Vector2(PAD, TITLE + 2)
	_inv_grid.size     = Vector2(iw, ih)
	_inv_panel.add_child(_inv_grid)

	var hint := _lbl("[I] Cerrar", Vector2(0, ph - CLOSE), _inv_panel, 7)
	hint.size = Vector2(pw, CLOSE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", C_MUTED)

	_fill_inv_grid()


func _fill_inv_grid() -> void:
	if _inv_grid == null:
		return
	for ch: Node in _inv_grid.get_children():
		_inv_grid.remove_child(ch)
		ch.queue_free()
	if _player == null:
		return

	for item_id: String in _player.inventory:
		var amt: int = _player.inventory[item_id]
		if amt <= 0:
			continue

		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(INV_S, INV_S)
		slot.add_theme_stylebox_override("panel", _sb_slot())
		slot.tooltip_text = _item_name(item_id)
		_inv_grid.add_child(slot)

		var icon_tex := _item_tex(item_id)
		if icon_tex != null:
			const ICON_S := 14
			const OFF    := (INV_S - ICON_S) / 2
			var icon := TextureRect.new()
			icon.position     = Vector2(OFF, OFF)
			icon.size         = Vector2(ICON_S, ICON_S)
			icon.texture      = icon_tex
			icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)

		var cnt := Label.new()
		cnt.text     = str(amt)
		cnt.position = Vector2(INV_S - 10, INV_S - 9)
		cnt.size     = Vector2(9, 8)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_font_size_override("font_size", 6)
		cnt.add_theme_color_override("font_color",        C_TEXT)
		cnt.add_theme_color_override("font_shadow_color", C_SHADOW)
		cnt.add_theme_constant_override("shadow_offset_x", 1)
		cnt.add_theme_constant_override("shadow_offset_y", 1)
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cnt)


# ── Aviso / hint (encima de la barra rápida) ──────────────────────────────────

func _build_hint() -> void:
	var vp := get_viewport().get_visible_rect().size
	_hint_lbl = Label.new()
	_hint_lbl.position = Vector2(0, vp.y - (HOTBAR_S + HOTBAR_PAD * 2 + 2) - 13)
	_hint_lbl.size     = Vector2(vp.x, 12)
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 7)
	_hint_lbl.add_theme_color_override("font_color",        Color(0.85, 0.85, 0.75, 0.85))
	_hint_lbl.add_theme_color_override("font_shadow_color", C_SHADOW)
	_hint_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_hint_lbl.add_theme_constant_override("shadow_offset_y", 1)
	_hint_lbl.text = "[E] interactuar"
	add_child(_hint_lbl)


func show_notice(text: String) -> void:
	_notice_id += 1
	var this_id := _notice_id
	_hint_lbl.text = text
	if not is_inside_tree():
		return
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if _notice_id == this_id:
			_hint_lbl.text = "[E] interactuar"
	)


# ── Refresco ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _player == null:
		return
	_gold_lbl.text = str(_player.inventory.get("gold",   0))
	_arr_lbl.text  = str(_player.inventory.get("arrows", 0))
	_refresh_hotbar()
	if _inv_grid != null:
		_fill_inv_grid()


func _refresh_hotbar() -> void:
	var keys: Array = _player.inventory.keys()
	for i: int in HOTBAR_N:
		if i < keys.size():
			var id: String = keys[i]
			var amt: int   = _player.inventory.get(id, 0)
			_hb_icons[i].texture = _item_tex(id)
			_hb_counts[i].text   = str(amt) if amt > 1 else ""
		else:
			_hb_icons[i].texture = null
			_hb_counts[i].text   = ""


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_toggle_inventory()


# ── Utilidades ────────────────────────────────────────────────────────────────

func _item_tex(id: String) -> Texture2D:
	if not _item_reg.has(id):
		return null
	var res: Resource = _item_reg[id]
	if res == null:
		return null
	return res.get("icon") as Texture2D


func _item_name(id: String) -> String:
	if _item_reg.has(id):
		var res: Resource = _item_reg[id]
		if res != null:
			var n = res.get("display_name")
			if n is String and not (n as String).is_empty():
				return n
	return id.capitalize()


func _sb(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	return s


func _sb_slot() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color          = C_SLOT
	s.border_color      = C_BORDER
	s.border_width_left  = 1; s.border_width_right  = 1
	s.border_width_top   = 1; s.border_width_bottom = 1
	return s


func _tex(parent: Control, path: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture     = load(path)
	tr.position    = pos
	tr.size        = sz
	tr.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(tr)
	return tr


func _lbl(text: String, pos: Vector2, parent: Control, fsize: int) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color",        C_TEXT)
	l.add_theme_color_override("font_shadow_color", C_SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l
