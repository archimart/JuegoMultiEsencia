extends Node2D

const MAX_MONSTERS   := 25
const SPAWN_INTERVAL := 3.5
const MIN_DIST       := 130.0   # mínimo desde el jugador
const MAX_DIST       := 480.0   # máximo (dentro de los chunks cargados)
const WORLD_MIN      := 24.0
const WORLD_MAX      := 3176.0
const VILLAGE_POS    := Vector2(1584.0, 1584.0)
const VILLAGE_SAFE   := 180.0   # radio libre de monstruos alrededor del pueblo

var _scenes: Array[PackedScene] = [
	preload("res://scenes/monster_heart.tscn"),
	preload("res://scenes/monster_racoon.tscn"),
	preload("res://scenes/monster_slime.tscn"),
	preload("res://scenes/monster_mushroom.tscn"),
	preload("res://scenes/monster_spider.tscn"),
	preload("res://scenes/monster_bat.tscn"),
	preload("res://scenes/monster_golem.tscn"),
	preload("res://scenes/monster_scorpion.tscn"),
	preload("res://scenes/monster_snake.tscn"),
	preload("res://scenes/monster_skull.tscn"),
	preload("res://scenes/monster_spirit.tscn"),
]
var _player: Node2D = null
var _timer:  float  = 0.8   # primer spawn rápido


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
	# Poblar el mundo al arrancar
	for _i: int in 12:
		_try_spawn()


func _process(delta: float) -> void:
	if _player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SPAWN_INTERVAL
	# Generar hasta 3 por tick para recuperar la población más rápido
	for _i: int in 3:
		_try_spawn()


func _try_spawn() -> void:
	if get_tree().get_nodes_in_group("monster").size() >= MAX_MONSTERS:
		return
	if _player == null:
		return
	var player_pos := _player.global_position
	for _attempt: int in 25:
		var angle := randf() * TAU
		var dist  := randf_range(MIN_DIST, MAX_DIST)
		var pos   := player_pos + Vector2(cos(angle), sin(angle)) * dist
		pos.x = clampf(pos.x, WORLD_MIN, WORLD_MAX)
		pos.y = clampf(pos.y, WORLD_MIN, WORLD_MAX)
		if pos.distance_to(VILLAGE_POS) < VILLAGE_SAFE:
			continue
		var scene: PackedScene = _scenes[randi() % _scenes.size()]
		var m: Node2D = scene.instantiate()
		m.global_position = pos
		get_tree().current_scene.add_child(m)
		return
