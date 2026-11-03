class_name Chunk
extends Node2D

@export var chunk_x:      int  = 0
@export var chunk_y:      int  = 0
@export var layer:        int  = 0   # 0 = superficie, 1 = cueva
@export var has_safe_zone: bool = false

const _SAVE_DIR := "user://chunk_states/"


func _ready() -> void:
	_load_state()


func save_state() -> void:
	var nl := get_node_or_null("NatureLayer") as TileMapLayer
	if nl == null:
		return

	var data: Dictionary = {}
	for cell: Vector2i in nl.get_used_cells():
		data["%d,%d" % [cell.x, cell.y]] = [
			nl.get_cell_source_id(cell),
			nl.get_cell_atlas_coords(cell).x,
			nl.get_cell_atlas_coords(cell).y,
		]

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_SAVE_DIR))
	var path := _SAVE_DIR + "chunk_%d_%d_%d.json" % [layer, chunk_x, chunk_y]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func _load_state() -> void:
	var path := _SAVE_DIR + "chunk_%d_%d_%d.json" % [layer, chunk_x, chunk_y]
	if not FileAccess.file_exists(path):
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()

	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return

	var nl := get_node_or_null("NatureLayer") as TileMapLayer
	if nl == null:
		return

	nl.clear()
	for key: String in data:
		var parts := key.split(",")
		var pos   := Vector2i(int(parts[0]), int(parts[1]))
		var t: Array = data[key]
		nl.set_cell(pos, int(t[0]), Vector2i(int(t[1]), int(t[2])))
