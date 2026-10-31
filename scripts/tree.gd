extends Node2D

const NATURE_TEX  := "res://assets/Backgrounds/Tilesets/TilesetNature.png"
# Árbol verde completo (primer árbol de TilesetNature): 2 tiles × 3 tiles = 32×48 px
# Medido en píxeles desde la esquina superior-izquierda de TilesetNature.png
const TREE_REGION := Rect2(0, 0, 32, 48)
const WOOD_PER_CHOP := 2

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area:   Area2D   = $Area2D

var _player:  Node2D = null
var _chopped: bool   = false


func _ready() -> void:
	_setup_sprite()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _setup_sprite() -> void:
	_sprite.texture        = load(NATURE_TEX)
	_sprite.region_enabled = true
	_sprite.region_rect    = TREE_REGION
	# Con centered=true y offset (0,-24): la BASE del tronco queda en la posición del nodo
	# → el jugador que pasa por detrás (y menor) se dibuja antes → Y-sort correcto
	_sprite.centered = true
	_sprite.offset   = Vector2(0, -24)


func _unhandled_input(event: InputEvent) -> void:
	if _chopped or _player == null:
		return
	if event.is_action_pressed("interact"):
		_chop()


func _chop() -> void:
	_chopped = true
	set_process_unhandled_input(false)
	if _player.has_method("collect_item"):
		_player.collect_item("wood", WOOD_PER_CHOP)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	tween.tween_property(_sprite, "modulate", Color.WHITE,          0.08)
	tween.tween_property(_sprite, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	tween.tween_property(_sprite, "scale",    Vector2(0.1, 0.1),    0.15)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
