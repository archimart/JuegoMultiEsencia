extends Node
## UIManager: tema global Wood, pila de menús, Esc y bloqueo de input al jugador.

signal menu_opened
signal menu_closed

var game_theme: Theme = null

const WOOD      := "res://assets/Ui/Theme/Theme Wood/"
const FONT_PATH := "res://assets/Ui/Font/NormalFont.ttf"

var _menu_stack: Array[Control] = []
var _player_ref: Node2D        = null


func _ready() -> void:
	_build_theme()
	get_tree().root.theme = game_theme
	_apply_saved_options()


func _apply_saved_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://options.cfg") != OK:
		return
	var sfx_vol: float = cfg.get_value("audio", "sfx_vol", 1.0)
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_vol) if sfx_vol > 0.0 else -80.0)
	var fullscreen: bool = cfg.get_value("display", "fullscreen", false)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var scale: int = cfg.get_value("display", "ui_scale", 2)
	scale = clampi(scale, 1, 4)
	if not fullscreen:
		var w := 640 * scale
		var h := 360 * scale
		DisplayServer.window_set_size(Vector2i(w, h))
		var screen_sz := DisplayServer.screen_get_size()
		DisplayServer.window_set_position(Vector2i((screen_sz.x - w) / 2, (screen_sz.y - h) / 2))


func register_player(player: Node2D) -> void:
	_player_ref = player


# ── Gestión de menús ──────────────────────────────────────────────────────────

func push_menu(panel: Control) -> void:
	_menu_stack.append(panel)
	panel.tree_exiting.connect(_on_menu_exiting.bind(panel), CONNECT_ONE_SHOT)
	_set_player_blocked(true)
	menu_opened.emit()


func close_all() -> void:
	for p: Control in _menu_stack.duplicate():
		if is_instance_valid(p):
			p.queue_free()


func is_menu_open() -> bool:
	return not _menu_stack.is_empty()


func _on_menu_exiting(panel: Control) -> void:
	_menu_stack.erase(panel)
	if _menu_stack.is_empty():
		_set_player_blocked(false)
		menu_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _menu_stack.is_empty():
		get_viewport().set_input_as_handled()
		var top: Control = _menu_stack.back()
		if is_instance_valid(top):
			top.queue_free()


func _set_player_blocked(blocked: bool) -> void:
	if _player_ref != null and is_instance_valid(_player_ref):
		_player_ref.set("input_blocked", blocked)


# ── Constructor del tema ──────────────────────────────────────────────────────

func _build_theme() -> void:
	game_theme = Theme.new()

	if ResourceLoader.exists(FONT_PATH):
		var font: Font = load(FONT_PATH)
		game_theme.default_font      = font
		game_theme.default_font_size = 8

	# Panel
	game_theme.set_stylebox("panel", "Panel",          _make_panel_sb("nine_path_panel.png"))
	game_theme.set_stylebox("panel", "PanelContainer", _make_panel_sb("nine_path_panel.png"))

	# Botones
	game_theme.set_stylebox("normal",   "Button", _make_btn_sb("button_normal.png"))
	game_theme.set_stylebox("hover",    "Button", _make_btn_sb("button_hover.png"))
	game_theme.set_stylebox("pressed",  "Button", _make_btn_sb("button_pressed.png"))
	game_theme.set_stylebox("disabled", "Button", _make_btn_sb("button_disabled.png"))
	game_theme.set_stylebox("focus",    "Button", StyleBoxEmpty.new())

	game_theme.set_color("font_color",         "Button", Color(0.92, 0.88, 0.75))
	game_theme.set_color("font_hover_color",   "Button", Color(1.0,  0.95, 0.80))
	game_theme.set_color("font_pressed_color", "Button", Color(0.75, 0.55, 0.15))
	game_theme.set_color("font_disabled_color","Button", Color(0.55, 0.55, 0.55))
	game_theme.set_color("font_outline_color", "Button", Color(0.0,  0.0,  0.0, 0.85))
	game_theme.set_constant("outline_size",    "Button", 1)

	# Labels: outline negro por defecto para todos
	game_theme.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 0.85))
	game_theme.set_constant("outline_size",    "Label", 1)

	# LineEdit
	game_theme.set_stylebox("normal", "LineEdit", _make_panel_sb("nine_path_panel.png"))
	game_theme.set_color("font_color",           "LineEdit", Color(0.92, 0.92, 0.85))
	game_theme.set_color("font_outline_color",   "LineEdit", Color(0.0,  0.0,  0.0, 0.85))
	game_theme.set_constant("outline_size",      "LineEdit", 1)


func _make_panel_sb(fname: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var path := WOOD + fname
	if ResourceLoader.exists(path):
		sb.texture = load(path)
	sb.texture_margin_left   = 3
	sb.texture_margin_right  = 3
	sb.texture_margin_top    = 3
	sb.texture_margin_bottom = 3
	sb.content_margin_left   = 2
	sb.content_margin_right  = 2
	sb.content_margin_top    = 2
	sb.content_margin_bottom = 2
	return sb


func _make_btn_sb(fname: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var path := WOOD + fname
	if ResourceLoader.exists(path):
		sb.texture = load(path)
	sb.texture_margin_left   = 3
	sb.texture_margin_right  = 3
	sb.texture_margin_top    = 2
	sb.texture_margin_bottom = 2
	return sb
