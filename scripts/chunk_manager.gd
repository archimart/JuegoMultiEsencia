class_name ChunkManager
extends Node

const CHUNK_TILES := 64
const TILE_PX     := 16
const CHUNK_PX    := CHUNK_TILES * TILE_PX   # 1024 px por chunk
const CHUNKS_PATH := "res://scenes/chunks/"

@export var layer:        int     = 0               # 0 = superficie, 1 = cueva
@export var world_offset: Vector2 = Vector2.ZERO    # offset en píxeles del origen de esta capa
@export var load_radius:  int     = 2

var _loaded: Dictionary = {}   # Vector2i(cx,cy) → Chunk node
var _active: bool = true


func _process(_delta: float) -> void:
	var needed := _needed_chunks()
	for coords: Vector2i in needed:
		if not _loaded.has(coords):
			_load_chunk(coords)
	for coords: Vector2i in _loaded.keys().duplicate():
		if not needed.has(coords):
			_unload_chunk(coords)


# ─── API pública ──────────────────────────────────────────────────────────────

func set_layer_active(active: bool) -> void:
	_active = active
	set_process(active)
	for chunk in _loaded.values():
		if is_instance_valid(chunk):
			chunk.visible = active


## Carga síncronamente los chunks cercanos a world_pos (útil antes de teleporte).
func preload_around(world_pos: Vector2) -> void:
	var cc := _world_to_chunk(world_pos)
	for dy: int in range(-load_radius, load_radius + 1):
		for dx: int in range(-load_radius, load_radius + 1):
			var coords := cc + Vector2i(dx, dy)
			if not _loaded.has(coords):
				_load_chunk(coords)


func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return _world_to_chunk(world_pos)


func chunk_to_world(coords: Vector2i) -> Vector2:
	return world_offset + Vector2(float(coords.x) * CHUNK_PX, float(coords.y) * CHUNK_PX)


func is_safe_at(world_pos: Vector2) -> bool:
	var cc := _world_to_chunk(world_pos)
	if not _loaded.has(cc):
		return false
	var chunk = _loaded[cc]
	return is_instance_valid(chunk) and chunk.get("has_safe_zone")


func loaded_count() -> int:
	return _loaded.size()


func loaded_coords_str() -> String:
	var keys: Array = _loaded.keys()
	if keys.is_empty():
		return "(ninguno)"
	var parts: Array[String] = []
	for k: Vector2i in keys.slice(0, 9):
		parts.append(str(k))
	if keys.size() > 9:
		parts.append("…")
	return ", ".join(parts)


func unload_all() -> void:
	for coords: Vector2i in _loaded.keys().duplicate():
		_unload_chunk(coords)


# ─── Privado ──────────────────────────────────────────────────────────────────

func _world_to_chunk(world_pos: Vector2) -> Vector2i:
	var local := world_pos - world_offset
	return Vector2i(floori(local.x / CHUNK_PX), floori(local.y / CHUNK_PX))


func _needed_chunks() -> Dictionary:
	var result: Dictionary = {}
	for player: Node2D in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var cc := _world_to_chunk(player.global_position)
		for dy: int in range(-load_radius, load_radius + 1):
			for dx: int in range(-load_radius, load_radius + 1):
				result[cc + Vector2i(dx, dy)] = true
	return result


func _load_chunk(coords: Vector2i) -> void:
	var path := CHUNKS_PATH + "chunk_%d_%d_%d.tscn" % [layer, coords.x, coords.y]
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path)
	var chunk: Node2D = scene.instantiate()
	chunk.position = chunk_to_world(coords)
	if not _active:
		chunk.visible = false
	get_parent().add_child(chunk)
	_loaded[coords] = chunk


func _unload_chunk(coords: Vector2i) -> void:
	var chunk = _loaded[coords]
	if is_instance_valid(chunk) and chunk.has_method("save_state"):
		chunk.save_state()
	if is_instance_valid(chunk):
		chunk.queue_free()
	_loaded.erase(coords)
