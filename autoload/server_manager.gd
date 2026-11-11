extends Node

## Detecta el argumento --server y lanza el juego en modo servidor dedicado.
## Uso: ./juego.x86_64 --headless -- --server
## El servidor corre sin jugador local; los clientes se conectan con la IP del servidor.

var active: bool = false


func _ready() -> void:
	if "--server" not in OS.get_cmdline_user_args():
		return
	active = true
	# Ocultar ventana por si no se usa --headless
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	print("[Server] ════════════════════════════════")
	print("[Server] Modo servidor dedicado activo")
	print("[Server] Puerto ENet: %d" % Network.PORT)
	print("[Server] ════════════════════════════════")
	Network.host_dedicated()
	call_deferred("_load_world")


func _load_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")
