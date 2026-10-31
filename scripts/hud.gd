extends CanvasLayer

@onready var _wood_label: Label = $Panel/WoodLabel
@onready var _hint_label: Label = $Panel/HintLabel

var _player: Node2D = null


func set_player(p: Node2D) -> void:
	_player = p
	p.inventory_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var wood: int = _player.inventory.get("wood", 0)
	_wood_label.text = "Madera: %d" % wood
