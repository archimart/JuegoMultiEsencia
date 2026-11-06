extends CanvasLayer

var _player: Node2D = null
var _lost_items: Dictionary = {}

@onready var _title:    Label  = $Overlay/VBox/Title
@onready var _lost_lbl: Label  = $Overlay/VBox/LostItems
@onready var _btn:      Button = $Overlay/VBox/BtnRespawn


func setup(player: Node2D, lost: Dictionary) -> void:
	_player     = player
	_lost_items = lost


func _ready() -> void:
	_btn.pressed.connect(_on_respawn)
	_btn.grab_focus()

	# Animación del título
	_title.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_OUT)

	# Lista de objetos perdidos
	if _lost_items.is_empty():
		_lost_lbl.text = "(sin objetos)"
	else:
		var parts: PackedStringArray = []
		for id: String in _lost_items:
			var amt: int = int(_lost_items[id])
			if amt > 0:
				parts.append("%s ×%d" % [id.capitalize().replace("_", " "), amt])
		_lost_lbl.text = "\n".join(parts) if not parts.is_empty() else "(sin objetos)"


func _on_respawn() -> void:
	SFX.play("ui_click")
	if _player != null and is_instance_valid(_player):
		_player.do_respawn()
	queue_free()
