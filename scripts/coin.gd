extends Area2D

const COIN_TEX    := "res://assets/Items/Treasure/GoldCoin.png"
const ATTRACT_DIST := 55.0
const COLLECT_DIST := 8.0
const BASE_SPEED   := 45.0
const MAX_SPEED    := 200.0

@onready var _sprite: Sprite2D = $Sprite2D

var _player: Node2D = null


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
	_sprite.texture  = load(COIN_TEX)
	_sprite.centered = true
	_sprite.scale    = Vector2(1.5, 1.5)


func _process(delta: float) -> void:
	if _player == null:
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist < COLLECT_DIST:
		_player.collect_item("gold", 1)
		FX.particles(global_position, "coin")
		SFX.play("coin")
		queue_free()
		return
	if dist < ATTRACT_DIST:
		var t   := 1.0 - dist / ATTRACT_DIST
		var spd := lerpf(BASE_SPEED, MAX_SPEED, t)
		var dir := (_player.global_position - global_position).normalized()
		global_position += dir * spd * delta
