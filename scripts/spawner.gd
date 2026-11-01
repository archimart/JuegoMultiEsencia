extends Node2D

const MAX_MONSTERS   := 8
const SPAWN_INTERVAL := 6.0
const MIN_DIST       := 130.0
const MAP_W          := 40
const MAP_H          := 25
# Rect de la zona segura + margen de seguridad para no spawnear cerca
const SAFE_ZONE_RECT := Rect2(0.0, 0.0, 160.0, 128.0)
const SAFE_MARGIN    := 40.0

var _scenes: Array[PackedScene] = [
	preload("res://scenes/monster_heart.tscn"),
	preload("res://scenes/monster_racoon.tscn"),
]
var _player: Node2D = null
var _timer:  float  = 1.5   # primer spawn rápido


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
	# Poblar el mapa con algunos monstruos al arrancar
	for _i: int in 4:
		_try_spawn()


func _process(delta: float) -> void:
	if _player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SPAWN_INTERVAL
	_try_spawn()


func _try_spawn() -> void:
	if get_tree().get_nodes_in_group("monster").size() >= MAX_MONSTERS:
		return
	var player_pos := _player.global_position if _player != null else Vector2(320, 200)
	for _attempt: int in 20:
		var pos := Vector2(
			randf_range(24.0, (MAP_W - 2) * 16.0),
			randf_range(24.0, (MAP_H - 2) * 16.0)
		)
		var near_safe := SAFE_ZONE_RECT.grow(SAFE_MARGIN).has_point(pos)
		if pos.distance_to(player_pos) >= MIN_DIST and not near_safe:
			var scene: PackedScene = _scenes[randi() % _scenes.size()]
			var m: Node2D = scene.instantiate()
			m.global_position = pos
			get_tree().current_scene.add_child(m)
			return
