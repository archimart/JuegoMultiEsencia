extends CanvasLayer

signal resume_requested

const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_OPTIONS   := "res://scenes/options_menu.tscn"

@onready var _btn_resume:  Button = $Panel/VBox/BtnResume
@onready var _btn_options: Button = $Panel/VBox/BtnOptions
@onready var _btn_quit:    Button = $Panel/VBox/BtnQuit


func _ready() -> void:
	_btn_resume.pressed.connect(_on_resume)
	_btn_options.pressed.connect(_on_options)
	_btn_quit.pressed.connect(_on_quit)
	_btn_resume.grab_focus()
	get_tree().paused = true


func _on_resume() -> void:
	SFX.play("ui_click")
	_close()


func _on_options() -> void:
	SFX.play("ui_click")
	if ResourceLoader.exists(SCENE_OPTIONS):
		get_tree().paused = false
		get_tree().change_scene_to_file(SCENE_OPTIONS)


func _on_quit() -> void:
	SFX.play("ui_click")
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _close() -> void:
	get_tree().paused = false
	resume_requested.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume()
