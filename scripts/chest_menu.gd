extends CanvasLayer

signal closed

# ── Layout ────────────────────────────────────────────────────────────────────
const SLOT    := 20
const COLS    := 4
const SLOTGAP := 2
const PAD     := 6
const MID_GAP := 8
const TITLE_H := 14
const HDR_H   := 11
const HINT_H  := 11

# ── Colores ───────────────────────────────────────────────────────────────────
const C_BG     := Color(0.07, 0.07, 0.10, 0.94)
const C_SLOT   := Color(0.10, 0.10, 0.16, 0.90)
const C_BORDER := Color(0.25, 0.25, 0.35, 0.90)
const C_TEXT   := Color(0.92, 0.92, 0.85, 1.00)
const C_SHADOW := Color(0.00, 0.00, 0.00, 0.85)
const C_MUTED  := Color(0.60, 0.60, 0.70, 1.00)
const C_PLAYER := Color(0.55, 0.85, 0.55, 1.00)
const C_CHEST  := Color(0.90, 0.78, 0.40, 1.00)

# ── Estado ────────────────────────────────────────────────────────────────────
var _player: Node2D
var _chest:  Node2D

var _player_grid: GridContainer
var _chest_grid:  GridContainer


func setup(player: Node2D, chest: Node2D) -> void:
	_player = player
	_chest  = chest


func _ready() -> void:
	if _player == null:
		return
	_build_ui()


# ── Construcción de UI ────────────────────────────────────────────────────────

func _build_ui() -> void:
	var ci: Dictionary = _chest.get("chest_inventory") as Dictionary
	var p_rows: int = max(2, ceili(float(_player.inventory.size()) / float(COLS)))
	var c_rows: int = max(2, ceili(float(ci.size())               / float(COLS)))
	var rows: int   = max(p_rows, c_rows)

	var grid_w: int = COLS * SLOT + (COLS - 1) * SLOTGAP
	var grid_h: int = rows * SLOT + (rows - 1) * SLOTGAP
	var pw: int     = grid_w * 2 + MID_GAP + PAD * 2
	var ph: int     = TITLE_H + HDR_H + grid_h + HINT_H + PAD * 2 + 4
	var vp := get_viewport().get_visible_rect().size

	var bg := Panel.new()
	bg.position = Vector2(roundf((vp.x - pw) * 0.5), roundf((vp.y - ph) * 0.5))
	bg.size     = Vector2(pw, ph)
	bg.add_theme_stylebox_override("panel", _panel_sty(C_BG))
	add_child(bg)

	# Título centrado
	var title := _lbl("Cofre", bg, Vector2(0, 2), 8)
	title.size = Vector2(pw, TITLE_H)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_hsep(bg, PAD, TITLE_H, pw - PAD * 2)

	const Y_CONTENT := TITLE_H + 1

	# Encabezado columna izquierda (jugador)
	var lbl_p := _lbl("Inventario", bg, Vector2(PAD, Y_CONTENT + 1), 7)
	lbl_p.size = Vector2(grid_w, HDR_H)
	lbl_p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_p.add_theme_color_override("font_color", C_PLAYER)

	# Encabezado columna derecha (cofre)
	var rx: int     = PAD + grid_w + MID_GAP
	var lbl_c := _lbl("Cofre", bg, Vector2(rx, Y_CONTENT + 1), 7)
	lbl_c.size = Vector2(grid_w, HDR_H)
	lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_c.add_theme_color_override("font_color", C_CHEST)

	# Divisor vertical
	var vdiv := ColorRect.new()
	vdiv.position = Vector2(PAD + grid_w + MID_GAP / 2, Y_CONTENT)
	vdiv.size     = Vector2(1, HDR_H + grid_h)
	vdiv.color    = Color(0.4, 0.4, 0.5, 0.5)
	bg.add_child(vdiv)

	# Cuadrículas
	var gy: int = Y_CONTENT + HDR_H
	_player_grid = _make_grid(bg, Vector2(PAD, gy), grid_w, grid_h)
	_chest_grid  = _make_grid(bg, Vector2(rx,  gy), grid_w, grid_h)

	# Hint de cierre
	var hint := _lbl("[Esc] Cerrar", bg, Vector2(0, ph - HINT_H), 7)
	hint.size = Vector2(pw, HINT_H)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", C_MUTED)

	_fill_grids()


func _make_grid(parent: Control, pos: Vector2, w: int, h: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", SLOTGAP)
	g.add_theme_constant_override("v_separation", SLOTGAP)
	g.position = pos
	g.size     = Vector2(w, h)
	parent.add_child(g)
	return g


func _fill_grids() -> void:
	var ci: Dictionary = _chest.get("chest_inventory") as Dictionary
	_fill_grid(_player_grid, _player.inventory, true)
	_fill_grid(_chest_grid,  ci, false)


func _fill_grid(grid: GridContainer, inventory: Dictionary, is_player: bool) -> void:
	for ch: Node in grid.get_children():
		grid.remove_child(ch); ch.queue_free()

	for item_id: String in inventory:
		var amt: int = inventory.get(item_id, 0)
		if amt <= 0:
			continue
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT, SLOT)
		slot.add_theme_stylebox_override("panel", _slot_sty())
		slot.tooltip_text = _item_name(item_id) + "  ×" + str(amt)
		grid.add_child(slot)
		_add_icon(slot, item_id, amt)

		var id := item_id   # captura para la lambda
		slot.gui_input.connect(func(ev: InputEvent) -> void:
			if not ev is InputEventMouseButton:
				return
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				if is_player:
					_move_to_chest(id)
				else:
					_move_to_player(id)
		)


# ── Lógica de movimiento ──────────────────────────────────────────────────────

func _move_to_chest(item_id: String) -> void:
	var amt: int = _player.inventory.get(item_id, 0)
	if amt <= 0:
		return
	_player.inventory.erase(item_id)
	_player.inventory_changed.emit()
	var ci: Dictionary = _chest.get("chest_inventory") as Dictionary
	ci[item_id] = ci.get(item_id, 0) + amt
	_fill_grids()


func _move_to_player(item_id: String) -> void:
	var ci: Dictionary = _chest.get("chest_inventory") as Dictionary
	var amt: int = ci.get(item_id, 0)
	if amt <= 0:
		return
	ci.erase(item_id)
	_player.collect_item(item_id, amt)
	_fill_grids()


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()


# ── Utilidades de UI ──────────────────────────────────────────────────────────

func _panel_sty(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	return s


func _slot_sty() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color          = C_SLOT
	s.border_color      = C_BORDER
	s.border_width_left  = 1; s.border_width_right  = 1
	s.border_width_top   = 1; s.border_width_bottom = 1
	return s


func _add_icon(slot: Panel, item_id: String, amt: int) -> void:
	const ICON_S := 14; const OFF := (20 - ICON_S) / 2
	var tex := _item_tex(item_id)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture     = tex
		icon.position    = Vector2(OFF, OFF)
		icon.size        = Vector2(ICON_S, ICON_S)
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
	var cnt := Label.new()
	cnt.text     = str(amt)
	cnt.position = Vector2(SLOT - 10, SLOT - 9)
	cnt.size     = Vector2(9, 8)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 6)
	cnt.add_theme_color_override("font_color",        C_TEXT)
	cnt.add_theme_color_override("font_shadow_color", C_SHADOW)
	cnt.add_theme_constant_override("shadow_offset_x", 1)
	cnt.add_theme_constant_override("shadow_offset_y", 1)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cnt)


func _hsep(parent: Control, x: int, y: int, w: int) -> void:
	var sep := ColorRect.new()
	sep.position = Vector2(x, y); sep.size = Vector2(w, 1)
	sep.color    = Color(0.4, 0.4, 0.5, 0.5)
	parent.add_child(sep)


func _item_tex(id: String) -> Texture2D:
	var path := "res://resources/item_" + id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as Resource).get("icon") as Texture2D


func _item_name(id: String) -> String:
	var path := "res://resources/item_" + id + ".tres"
	if ResourceLoader.exists(path):
		var n = (load(path) as Resource).get("display_name")
		if n is String and not (n as String).is_empty():
			return n
	return id.capitalize()


func _lbl(text: String, parent: Control, pos: Vector2, fsize: int) -> Label:
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
