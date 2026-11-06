extends Control

const SCENE_RACE_SELECT := "res://scenes/race_select.tscn"
const SCENE_OPTIONS     := "res://scenes/options_menu.tscn"

@onready var _btn_play:    Button = $Center/VBox/BtnPlay
@onready var _btn_options: Button = $Center/VBox/BtnOptions
@onready var _btn_credits: Button = $Center/VBox/BtnCredits
@onready var _btn_quit:    Button = $Center/VBox/BtnQuit

var _credits_overlay: CanvasLayer = null


func _ready() -> void:
	_btn_play.pressed.connect(_on_play)
	_btn_options.pressed.connect(_on_options)
	_btn_credits.pressed.connect(_on_credits)
	_btn_quit.pressed.connect(_on_quit)
	_btn_play.grab_focus()


func _on_play() -> void:
	SFX.play("ui_click")
	get_tree().change_scene_to_file(SCENE_RACE_SELECT)


func _on_options() -> void:
	SFX.play("ui_click")
	if ResourceLoader.exists(SCENE_OPTIONS):
		get_tree().change_scene_to_file(SCENE_OPTIONS)


func _on_credits() -> void:
	SFX.play("ui_click")
	if _credits_overlay != null and is_instance_valid(_credits_overlay):
		_credits_overlay.queue_free()
		_credits_overlay = null
		return
	_open_credits()


func _on_quit() -> void:
	SFX.play("ui_click")
	get_tree().quit()


func _open_credits() -> void:
	_credits_overlay = CanvasLayer.new()
	_credits_overlay.layer = 10
	add_child(_credits_overlay)

	var W := 500.0
	var H := 310.0
	var vp := get_viewport().get_visible_rect().size

	var bg := Panel.new()
	bg.position = Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)
	bg.size     = Vector2(W, H)
	_credits_overlay.add_child(bg)

	var title := Label.new()
	title.text = "Créditos"
	title.position = Vector2(0.0, 6.0)
	title.size     = Vector2(W, 16.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	bg.add_child(title)

	var sep := ColorRect.new()
	sep.position = Vector2(8.0, 25.0)
	sep.size     = Vector2(W - 16.0, 1.0)
	sep.color    = Color(0.4, 0.4, 0.5, 0.6)
	bg.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8.0, 30.0)
	scroll.size     = Vector2(W - 16.0, H - 55.0)
	bg.add_child(scroll)

	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size          = Vector2(W - 32.0, 0.0)
	text.add_theme_font_size_override("font_size", 7)
	text.text = _load_credits_text()
	scroll.add_child(text)

	var close_btn := Button.new()
	close_btn.text     = "✕  Cerrar"
	close_btn.position = Vector2(W * 0.5 - 44.0, H - 22.0)
	close_btn.size     = Vector2(88.0, 16.0)
	close_btn.add_theme_font_size_override("font_size", 8)
	close_btn.pressed.connect(_on_credits)
	bg.add_child(close_btn)


func _load_credits_text() -> String:
	const PATH := "res://CREDITS.md"
	var godot_notice := "\n---\n\nMotor de juego\n\nEste juego usa Godot Engine, disponible bajo la licencia MIT.\nhttps://godotengine.org\n"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(PATH)):
		return "No se encontró CREDITS.md" + godot_notice
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return "Error al leer CREDITS.md" + godot_notice
	var raw := f.get_as_text()
	f.close()
	# Simplificar markdown: quitar # y ** para texto plano
	var lines := raw.split("\n")
	var out: PackedStringArray = []
	for line: String in lines:
		var l := line.strip_edges()
		if l.begins_with("## "):
			out.append("\n" + l.substr(3).to_upper())
		elif l.begins_with("# "):
			out.append(l.substr(2).to_upper())
		elif l.begins_with("**") and l.ends_with("**"):
			out.append(l.replace("**", ""))
		else:
			out.append(l.replace("**", ""))
	return "\n".join(out) + godot_notice


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _credits_overlay != null:
		_on_credits()
		get_viewport().set_input_as_handled()
