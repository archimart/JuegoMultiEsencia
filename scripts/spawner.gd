extends Node2D

const MAX_MONSTERS   := 28
const SPAWN_INTERVAL := 3.5
const MIN_DIST       := 130.0
const MAX_DIST       := 480.0
const WORLD_MIN      := 24.0
const WORLD_MAX      := 3176.0
const VILLAGE_POS    := Vector2(1584.0, 1584.0)
const VILLAGE_SAFE   := 200.0

# Límite en X que separa el mundo de la cueva
const CAVE_MIN_X     := 3800.0

# Radios de zona (distancia al centro del mundo)
const ZONE_NEAR      := 450.0
const ZONE_MID       := 950.0

# Monstruos por zona: [near, mid, far]
var _scenes_near: Array[PackedScene] = [
	preload("res://scenes/monster_heart.tscn"),
	preload("res://scenes/monster_racoon.tscn"),
	preload("res://scenes/monster_slime.tscn"),
	preload("res://scenes/monster_mushroom.tscn"),
]
var _scenes_mid: Array[PackedScene] = [
	preload("res://scenes/monster_slime.tscn"),
	preload("res://scenes/monster_mushroom.tscn"),
	preload("res://scenes/monster_spider.tscn"),
	preload("res://scenes/monster_bat.tscn"),
	preload("res://scenes/monster_golem.tscn"),
]
var _scenes_far: Array[PackedScene] = [
	preload("res://scenes/monster_spider.tscn"),
	preload("res://scenes/monster_golem.tscn"),
	preload("res://scenes/monster_scorpion.tscn"),
	preload("res://scenes/monster_snake.tscn"),
	preload("res://scenes/monster_skull.tscn"),
	preload("res://scenes/monster_spirit.tscn"),
]
# Monstruos de cueva (solo spawnean si el jugador está en la cueva)
var _scenes_cave: Array[PackedScene] = [
	preload("res://scenes/monster_bat.tscn"),
	preload("res://scenes/monster_scorpion.tscn"),
	preload("res://scenes/monster_skull.tscn"),
	preload("res://scenes/monster_spirit.tscn"),
]

var _player: Node2D = null
var _timer:  float  = 0.8


func _ready() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]
	for _i: int in 14:
		_try_spawn()


func _process(delta: float) -> void:
	if _player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SPAWN_INTERVAL
	for _i: int in 3:
		_try_spawn()


func _try_spawn() -> void:
	if get_tree().get_nodes_in_group("monster").size() >= MAX_MONSTERS:
		return
	if _player == null:
		return
	var player_pos := _player.global_position
	var in_cave    := player_pos.x >= CAVE_MIN_X

	for _attempt: int in 25:
		var angle := randf() * TAU
		var dist  := randf_range(MIN_DIST, MAX_DIST)
		var pos   := player_pos + Vector2(cos(angle), sin(angle)) * dist

		if in_cave:
			# Mantener dentro de la cueva
			pos.x = clampf(pos.x, CAVE_MIN_X, CAVE_MIN_X + 1280.0)
			pos.y = clampf(pos.y, WORLD_MIN,  WORLD_MAX)
			var m: Node2D = _scenes_cave[randi() % _scenes_cave.size()].instantiate()
			m.global_position = pos
			get_tree().current_scene.add_child(m)
			return
		else:
			pos.x = clampf(pos.x, WORLD_MIN, WORLD_MAX)
			pos.y = clampf(pos.y, WORLD_MIN, WORLD_MAX)
			# Excluir cueva y villa
			if pos.x >= CAVE_MIN_X:
				continue
			if pos.distance_to(VILLAGE_POS) < VILLAGE_SAFE:
				continue
			var scene_pool := _pool_for(pos)
			var m: Node2D = scene_pool[randi() % scene_pool.size()].instantiate()
			m.global_position = pos
			get_tree().current_scene.add_child(m)
			return


func _pool_for(pos: Vector2) -> Array[PackedScene]:
	var d := pos.distance_to(VILLAGE_POS)
	if d < ZONE_NEAR:
		return _scenes_near
	elif d < ZONE_MID:
		return _scenes_mid
	else:
		return _scenes_far
