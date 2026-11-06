extends Control

const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const CFG_PATH        := "user://options.cfg"

@onready var _slider_music: HSlider = $Center/Panel/VBox/RowMusic/SliderMusic
@onready var _slider_sfx:   HSlider = $Center/Panel/VBox/RowSfx/SliderSfx
@onready var _chk_fullscreen: CheckButton = $Center/Panel/VBox/RowFullscreen/ChkFullscreen
@onready var _lbl_scale: Label = $Center/Panel/VBox/RowScale/LblScale
@onready var _btn_scale_down: Button = $Center/Panel/VBox/RowScale/BtnDown
@onready var _btn_scale_up:   Button = $Center/Panel/VBox/RowScale/BtnUp
@onready var _btn_back: Button = $Center/Panel/VBox/BtnBack

var _music_vol:   float = 1.0
var _sfx_vol:     float = 1.0
var _fullscreen:  bool  = false
var _ui_scale:    int   = 2   # factor entero: 1=640×360, 2=1280×720, 3=1920×1080


func _ready() -> void:
	_load_options()
	_apply_all()
	_refresh_ui()
	_slider_music.value_changed.connect(_on_music_changed)
	_slider_sfx.value_changed.connect(_on_sfx_changed)
	_chk_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_btn_scale_down.pressed.connect(_on_scale_down)
	_btn_scale_up.pressed.connect(_on_scale_up)
	_btn_back.pressed.connect(_on_back)
	_btn_back.grab_focus()


func _load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	_music_vol  = cfg.get_value("audio", "music_vol", 1.0)
	_sfx_vol    = cfg.get_value("audio", "sfx_vol",   1.0)
	_fullscreen = cfg.get_value("display", "fullscreen", false)
	_ui_scale   = cfg.get_value("display", "ui_scale", 2)


func _save_options() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_vol",    _music_vol)
	cfg.set_value("audio", "sfx_vol",      _sfx_vol)
	cfg.set_value("display", "fullscreen", _fullscreen)
	cfg.set_value("display", "ui_scale",   _ui_scale)
	cfg.save(CFG_PATH)


func _apply_all() -> void:
	_apply_music()
	_apply_sfx()
	_apply_fullscreen()
	_apply_scale()


func _apply_music() -> void:
	# Bus "Music" si existe, si no: ignorar (no hay BGM aún)
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(_music_vol) if _music_vol > 0.0 else -80.0)
		AudioServer.set_bus_mute(idx, _music_vol <= 0.0)


func _apply_sfx() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(_sfx_vol) if _sfx_vol > 0.0 else -80.0)


func _apply_fullscreen() -> void:
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_scale() -> void:
	_ui_scale = clampi(_ui_scale, 1, 4)
	var w := 640 * _ui_scale
	var h := 360 * _ui_scale
	DisplayServer.window_set_size(Vector2i(w, h))
	# Centrar ventana
	var screen_sz := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i((screen_sz.x - w) / 2, (screen_sz.y - h) / 2))


func _refresh_ui() -> void:
	_slider_music.value = _music_vol
	_slider_sfx.value   = _sfx_vol
	_chk_fullscreen.button_pressed = _fullscreen
	_lbl_scale.text = "%dx  (%d×%d)" % [_ui_scale, 640 * _ui_scale, 360 * _ui_scale]
	_btn_scale_down.disabled = (_ui_scale <= 1)
	_btn_scale_up.disabled   = (_ui_scale >= 4)


func _on_music_changed(val: float) -> void:
	_music_vol = val
	_apply_music()
	_save_options()


func _on_sfx_changed(val: float) -> void:
	_sfx_vol = val
	_apply_sfx()
	_save_options()


func _on_fullscreen_toggled(val: bool) -> void:
	_fullscreen = val
	_apply_fullscreen()
	_save_options()


func _on_scale_down() -> void:
	_ui_scale -= 1
	_apply_scale()
	_refresh_ui()
	_save_options()


func _on_scale_up() -> void:
	_ui_scale += 1
	_apply_scale()
	_refresh_ui()
	_save_options()


func _on_back() -> void:
	SFX.play("ui_click")
	var prev := get_tree().current_scene.name
	if prev == "OptionsMenu":
		# Venimos del menú principal
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)
	else:
		# Venimos del juego (pausa) — no podemos volver fácil, vamos al main
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
