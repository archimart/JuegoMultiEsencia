extends Node2D

const BAG_TEX  := "res://assets/Items/Object/Bag.png"
const LIFETIME := 300.0   # 5 minutos

var contents: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area:   Area2D   = $Area2D

var _player:   Node2D      = null
var _popup:    CanvasLayer = null
var _lifetime: float       = LIFETIME


func _ready() -> void:
	_sprite.texture  = load(BAG_TEX)
	_sprite.centered = true
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		_close_popup()
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _popup != null:
			_close_popup()
		else:
			_open_popup()


# ── Popup ─────────────────────────────────────────────────────────────────────

func _open_popup() -> void:
	_popup = CanvasLayer.new()
	add_child(_popup)

	var keys: Array = contents.keys()
	var rows: int   = max(1, ceili(float(keys.size()) / 4.0))
	const COLS:    int = 4
	const SLOT:    int = 20
	const SLOTGAP: int = 2
	const PAD:     int = 6
	const TITLE_H: int = 14
	const BTN_H:   int = 16
	const HINT_H:  int = 11

	var iw: int = COLS * SLOT + (COLS - 1) * SLOTGAP
	var ih: int = rows * SLOT + max(0, rows - 1) * SLOTGAP
	var pw: int = iw + PAD * 2
	var ph: int = TITLE_H + ih + BTN_H + HINT_H + PAD * 2 + 8
	var vp := get_viewport().get_visible_rect().size

	var bg := Panel.new()
	bg.position = Vector2(roundf((vp.x - pw) * 0.5), roundf((vp.y - ph) * 0.5))
	bg.size     = Vector2(pw, ph)
	bg.add_theme_stylebox_override("panel", _panel_sty(Color(0.07, 0.07, 0.10, 0.94)))
	_popup.add_child(bg)

	var title := _lbl("Bolsa de botín", bg, Vector2(0, 2), 8)
	title.size = Vector2(pw, TITLE_H)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_hsep(bg, PAD, TITLE_H, iw)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", SLOTGAP)
	grid.add_theme_constant_override("v_separation", SLOTGAP)
	grid.position = Vector2(PAD, TITLE_H + 2)
	grid.size     = Vector2(iw, ih)
	bg.add_child(grid)
	_fill_grid(grid)

	# Botón "Recoger todo"
	var btn_y: int = TITLE_H + ih + 6
	var btn := Button.new()
	btn.text     = "Recoger todo"
	btn.position = Vector2(PAD, btn_y)
	btn.size     = Vector2(iw, BTN_H)
	btn.add_theme_font_size_override("font_size", 7)
	var bs := StyleBoxFlat.new()
	bs.bg_color    = Color(0.20, 0.50, 0.20, 0.90)
	bs.border_color = Color(0.30, 0.70, 0.30, 1.00)
	bs.border_width_left = 1; bs.border_width_right  = 1
	bs.border_width_top  = 1; bs.border_width_bottom = 1
	bs.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", bs)
	var bsh := bs.duplicate() as StyleBoxFlat
	bsh.bg_color = Color(0.28, 0.65, 0.28, 0.95)
	btn.add_theme_stylebox_override("hover", bsh)
	btn.pressed.connect(_take_all)
	bg.add_child(btn)

	var hint := _lbl("[E] Cerrar", bg, Vector2(0, ph - HINT_H), 7)
	hint.size = Vector2(pw, HINT_H)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))


func _fill_grid(grid: GridContainer) -> void:
	for ch: Node in grid.get_children():
		grid.remove_child(ch); ch.queue_free()
	for item_id: String in contents:
		var amt: int = contents[item_id]
		if amt <= 0:
			continue
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(20, 20)
		slot.add_theme_stylebox_override("panel", _slot_sty())
		slot.tooltip_text = _item_name(item_id)
		grid.add_child(slot)
		_add_icon(slot, item_id, amt, 20)


func _take_all() -> void:
	if _player == null:
		return
	for item_id: String in contents:
		_player.collect_item(item_id, contents[item_id])
	contents.clear()
	_close_popup()
	queue_free()


func _close_popup() -> void:
	if _popup != null:
		_popup.queue_free()
		_popup = null


# ── Señales de área ───────────────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_close_popup()


# ── Utilidades de UI ──────────────────────────────────────────────────────────

func _panel_sty(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	return s


func _slot_sty() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color          = Color(0.10, 0.10, 0.16, 0.90)
	s.border_color      = Color(0.25, 0.25, 0.35, 0.90)
	s.border_width_left  = 1; s.border_width_right  = 1
	s.border_width_top   = 1; s.border_width_bottom = 1
	return s


func _add_icon(slot: Panel, item_id: String, amt: int, slot_size: int) -> void:
	const ICON_S := 14
	var off := (slot_size - ICON_S) / 2
	var tex := _item_tex(item_id)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture     = tex
		icon.position    = Vector2(off, off)
		icon.size        = Vector2(ICON_S, ICON_S)
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
	var cnt := Label.new()
	cnt.text     = str(amt)
	cnt.position = Vector2(slot_size - 10, slot_size - 9)
	cnt.size     = Vector2(9, 8)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_font_size_override("font_size", 6)
	cnt.add_theme_color_override("font_color",        Color(0.92, 0.92, 0.85, 1))
	cnt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	cnt.add_theme_constant_override("shadow_offset_x", 1)
	cnt.add_theme_constant_override("shadow_offset_y", 1)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cnt)


func _hsep(parent: Control, x: int, y: int, w: int) -> void:
	var sep := ColorRect.new()
	sep.position = Vector2(x, y); sep.size = Vector2(w, 1)
	sep.color = Color(0.4, 0.4, 0.5, 0.5)
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
	l.add_theme_color_override("font_color",        Color(0.92, 0.92, 0.85, 1))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l
