extends Node2D

# Mismo patrón que coin.gd: detección por distancia en _process

const COLLECT_DIST := 10.0
const ATTRACT_DIST := 50.0
const BASE_SPEED   := 40.0
const MAX_SPEED    := 180.0

var egg_id:   String = ""
var rarity:   String = "common"
var is_shiny: bool   = false
var _ready_t: float  = 0.5
var _bob_t:   float  = 0.0
var _player:  Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
	_sprite.texture  = load("res://assets/Items/Egg.png")
	_sprite.scale    = Vector2(1.4, 1.6)
	_sprite.centered = true
	if is_shiny:
		_sprite.self_modulate = Color(1.0, 0.95, 0.3)
	else:
		match rarity:
			"rare": _sprite.self_modulate = Color(0.5, 0.75, 1.0)
			"epic": _sprite.self_modulate = Color(0.9, 0.5, 1.0)
			_:      _sprite.self_modulate = Color(1.0, 0.95, 0.75)
	z_index = 2


func _process(delta: float) -> void:
	_ready_t = maxf(0.0, _ready_t - delta)
	_bob_t  += delta * 3.5
	_sprite.position.y = -8.0 + sin(_bob_t) * 2.5

	if _player == null or _ready_t > 0.0:
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist < COLLECT_DIST:
		if has_node("/root/FamiliarSystem"):
			FamiliarSystem.register_egg_rarity(egg_id.substr(4), rarity, is_shiny)
		_player.call("collect_item", egg_id, 1)
		if _player.has_signal("notice_requested"):
			var prefix := ""
			if is_shiny:
				prefix = "[BRILLANTE] "
			elif rarity == "rare":
				prefix = "[RARO] "
			elif rarity == "epic":
				prefix = "[ÉPICO] "
			_player.notice_requested.emit("%sHuevo de %s!" % [prefix, egg_id.substr(4).capitalize()])
		queue_free()
		return
	if dist < ATTRACT_DIST:
		var t   := 1.0 - dist / ATTRACT_DIST
		var spd := lerpf(BASE_SPEED, MAX_SPEED, t)
		global_position += (_player.global_position - global_position).normalized() * spd * delta
