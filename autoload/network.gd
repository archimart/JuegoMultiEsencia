extends Node

signal server_created
signal join_succeeded
signal connection_failed
signal peer_joined(peer_id: int, data: Dictionary)
signal peer_left(peer_id: int)
signal server_disconnected
signal game_started
signal game_in_progress_notified   # el servidor notifica al cliente que la partida ya inició

const PORT        := 7777
const MAX_PLAYERS := 8

# peer_id → { race_path, gender, class_path, hair_color, sprite_variant, display_name }
var players:          Dictionary = {}
var is_hosting:       bool       = false
var is_dedicated:     bool       = false   # servidor sin jugador local
var game_in_progress: bool       = false   # true cuando el mundo ya está cargado


func host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("[Network] Error creando servidor: %d" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_hosting = true
	players[1] = _local_data()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	server_created.emit()
	print("[Network] Servidor iniciado en puerto %d" % PORT)


func join(ip: String, port: int = PORT) -> void:
	# Limpiar peer y señales previas antes de cada intento
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_client(ip, port)
	if err != OK:
		push_error("[Network] Error conectando a %s:%d — %d" % [ip, port, err])
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_hosting = false
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("[Network] Conectando a %s:%d…" % [ip, port])


func disconnect_all() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	is_hosting       = false
	game_in_progress = false
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)


func host_dedicated() -> void:
	is_dedicated     = true
	is_hosting       = true
	game_in_progress = true
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("[Network] Error servidor dedicado: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[Network] Servidor dedicado escuchando en puerto %d" % PORT)


func start_game() -> void:
	if not multiplayer.is_server():
		return
	_rpc_start_game.rpc()


func update_local_data() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var my_id := multiplayer.get_unique_id()
	players[my_id] = _local_data()
	if not multiplayer.is_server():
		var status := multiplayer.multiplayer_peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			_rpc_register_player.rpc_id(1, players[my_id])


# Cliente ya eligió raza y pide unirse a la partida en curso.
func request_late_join() -> void:
	var my_id := multiplayer.get_unique_id()
	players[my_id] = _local_data()
	_rpc_late_join.rpc_id(1, players[my_id])


# ── RPCs ──────────────────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _rpc_start_game() -> void:
	game_in_progress = true
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/world.tscn")


# Solo el servidor lo llama con rpc_id hacia un cliente; el cliente carga el mundo.
@rpc("authority", "call_remote", "reliable")
func _rpc_send_to_world() -> void:
	game_in_progress = true
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/world.tscn")


@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_player(data: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	players[sender] = data
	peer_joined.emit(sender, data)
	if multiplayer.is_server():
		_rpc_send_roster.rpc_id(sender, players)
		for pid: int in players:
			if pid != sender and pid != 1:
				_rpc_notify_new_peer.rpc_id(pid, sender, data)
		# Si el juego ya está en marcha, avisarle al recién llegado
		if game_in_progress:
			_rpc_notify_in_progress.rpc_id(sender)


# Cliente solicita unirse a una partida ya iniciada (con raza ya elegida).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_late_join(data: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	players[sender] = data
	peer_joined.emit(sender, data)
	# Notificar a los demás jugadores del mundo sobre el nuevo jugador
	for pid: int in players:
		if pid != sender and pid != 1:
			_rpc_notify_new_peer.rpc_id(pid, sender, data)
	# Enviar al cliente tardío directamente al mundo
	_rpc_send_to_world.rpc_id(sender)


@rpc("authority", "call_remote", "reliable")
func _rpc_notify_in_progress() -> void:
	game_in_progress = true
	game_in_progress_notified.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_send_roster(all_players: Dictionary) -> void:
	for pid: int in all_players:
		var pid_int := pid as int
		if pid_int == multiplayer.get_unique_id():
			continue
		players[pid_int] = all_players[pid]
		peer_joined.emit(pid_int, all_players[pid])


@rpc("authority", "call_remote", "reliable")
func _rpc_notify_new_peer(new_id: int, data: Dictionary) -> void:
	players[new_id] = data
	peer_joined.emit(new_id, data)


# ── Callbacks internos ────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	print("[Network] Peer conectado: %d" % id)
	# Si la partida ya inició, avisar al recién llegado cuando se registre
	# (el aviso se hace en _rpc_register_player tras recibir sus datos)


func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer desconectado: %d" % id)
	players.erase(id)
	peer_left.emit(id)


func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	players[my_id] = _local_data()
	_rpc_register_player.rpc_id(1, players[my_id])
	join_succeeded.emit()
	print("[Network] Conectado al servidor (mi ID: %d)" % my_id)


func _on_connection_failed() -> void:
	push_error("[Network] Conexión fallida")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_error("[Network] Servidor desconectado")
	disconnect_all()
	server_disconnected.emit()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _local_data() -> Dictionary:
	return {
		"race_path":      GameState.selected_race.resource_path  if GameState.selected_race  != null else "",
		"gender":         GameState.selected_gender,
		"class_path":     GameState.selected_class.resource_path if GameState.selected_class != null else "",
		"hair_color":     GameState.selected_hair_color.to_html(),
		"sprite_variant": GameState.selected_sprite_variant,
		"display_name":   "Jugador",
	}
