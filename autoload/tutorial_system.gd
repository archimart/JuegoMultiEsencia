extends Node

# Pasos del tutorial en orden. Cada uno tiene id, condición y mensaje.
# La condición se evalúa externamente llamando trigger(step_id).
const STEPS: Array[Dictionary] = [
	{ "id": "move",      "msg": "Muévete con WASD  |  Ataca con clic izquierdo" },
	{ "id": "inventory", "msg": "Abre el inventario con [I]  |  Equipa armas con clic derecho" },
	{ "id": "wood",      "msg": "Acércate a la mesa de crafteo y presiona [E] para fabricar" },
	{ "id": "shop",      "msg": "El comerciante compra tus materiales a cambio de oro" },
	{ "id": "hp",        "msg": "Los huevos de familiar eclosionan al matar monstruos  |  [F] para eclosionar" },
]

var _done: Dictionary = {}   # step_id → true
var _cfg_path := "user://tutorial.cfg"

signal tip_requested(message: String)


func _ready() -> void:
	_load()
	# Primer mensaje al arrancar si no se ha visto
	if not _done.get("move", false):
		call_deferred("_show_step", "move")


func trigger(step_id: String) -> void:
	if _done.get(step_id, false):
		return
	_done[step_id] = true
	_save()
	_show_step(step_id)


func _show_step(step_id: String) -> void:
	for s: Dictionary in STEPS:
		if s["id"] == step_id:
			tip_requested.emit(s["msg"])
			return


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_cfg_path) != OK:
		return
	for s: Dictionary in STEPS:
		var id: String = s["id"]
		_done[id] = cfg.get_value("done", id, false)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_cfg_path)
	for id: Variant in _done.keys():
		cfg.set_value("done", id, _done[id])
	cfg.save(_cfg_path)


func reset() -> void:
	_done.clear()
	var cfg := ConfigFile.new()
	cfg.save(_cfg_path)
