extends Control

const SCENE_MAIN_MENU   := "res://scenes/main_menu.tscn"
const SCENE_RACE_SELECT := "res://scenes/race_select.tscn"

@onready var _btn_host:    Button          = $Center/VBox/HRow/PanelLeft/VBox/BtnHost
@onready var _field_ip:    LineEdit        = $Center/VBox/HRow/PanelLeft/VBox/HIP/FieldIP
@onready var _btn_join:    Button          = $Center/VBox/HRow/PanelLeft/VBox/HIP/BtnJoin
@onready var _lbl_status:  Label           = $Center/VBox/HRow/PanelLeft/VBox/LblStatus
@onready var _player_list: VBoxContainer   = $Center/VBox/HRow/PanelRight/VBox/Scroll/PlayerList
@onready var _btn_race:    Button          = $Center/VBox/HActions/BtnRace
@onready var _btn_start:   Button          = $Center/VBox/HActions/BtnStart
@onready var _btn_back:    Button          = $Center/VBox/HActions/BtnBack


func _ready() -> void:
	_btn_host.pressed.connect(_on_btn_host)
	_btn_join.pressed.connect(_on_btn_join)
	_btn_race.pressed.connect(_on_btn_race)
	_btn_start.pressed.connect(_on_btn_start)
	_btn_back.pressed.connect(_on_btn_back)

	Network.server_created.connect(_on_server_created)
	Network.join_succeeded.connect(_on_join_succeeded)
	Network.connection_failed.connect(_on_connection_failed)
	Network.peer_joined.connect(_on_peer_joined)
	Network.peer_left.connect(_on_peer_left)
	Network.server_disconnected.connect(_on_server_disconnected)
	Network.game_in_progress_notified.connect(_on_game_in_progress)

	_btn_start.visible = false
	_field_ip.placeholder_text = "IP  o  host:puerto"
	_field_ip.text = GameState.lobby_ip if not GameState.lobby_ip.is_empty() else "127.0.0.1"

	# Restaurar estado si ya estamos en sesión (al volver de race_select)
	if multiplayer.has_multiplayer_peer():
		_btn_host.disabled = true
		_btn_join.disabled = true
		Network.update_local_data()   # registrar la raza recién elegida

		var am_server := multiplayer.is_server()
		print("[Lobby] Restaurando — is_server=%s is_hosting=%s game_in_progress=%s" % [
			am_server, Network.is_hosting, Network.game_in_progress])

		if am_server:
			# El host siempre ve INICIAR (aunque esté solo)
			Network.is_hosting = true
			_btn_start.visible = true
			_lbl_status.text   = "Esperando jugadores en puerto %d…" % Network.PORT
			_lbl_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		elif Network.game_in_progress:
			# Cliente vuelve de race_select con partida en curso → va directo al mundo
			var my_id := multiplayer.get_unique_id()
			var my_data: Dictionary = Network.players.get(my_id, {})
			if not (my_data.get("race_path", "") as String).is_empty():
				Network.request_late_join()
				return
			_on_game_in_progress()
		else:
			_lbl_status.text = "Conectado. Esperando al anfitrión…"
			_lbl_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

	_refresh_player_list()
	_update_start_button()


# ── Botones ───────────────────────────────────────────────────────────────────

func _on_btn_host() -> void:
	SFX.play("ui_click")
	_btn_host.disabled = true
	_btn_join.disabled = true
	Network.host()


func _on_btn_join() -> void:
	SFX.play("ui_click")
	_btn_host.disabled = true
	_btn_join.disabled = true
	var raw := _field_ip.text.strip_edges()
	var host := raw
	var port := Network.PORT
	if ":" in raw:
		var parts := raw.split(":", false, 1)
		host = parts[0]
		port = parts[1].to_int() if parts[1].is_valid_int() else Network.PORT
	_lbl_status.text = "Conectando a %s:%d…" % [host, port]
	_lbl_status.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	Network.join(host, port)


func _on_btn_race() -> void:
	SFX.play("ui_click")
	GameState.in_lobby = true
	GameState.lobby_ip = _field_ip.text
	get_tree().change_scene_to_file(SCENE_RACE_SELECT)


func _on_btn_start() -> void:
	SFX.play("ui_click")
	Network.update_local_data()
	if Network.game_in_progress and not Network.is_hosting:
		# Late join: pide al servidor entrar al mundo
		Network.request_late_join()
	else:
		# Host: inicia la partida para todos
		Network.start_game()


func _on_btn_back() -> void:
	SFX.play("ui_click")
	Network.disconnect_all()
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


# ── Señales de Network ────────────────────────────────────────────────────────

func _on_server_created() -> void:
	_lbl_status.text = "Esperando jugadores en puerto %d…" % Network.PORT
	_lbl_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_btn_start.visible = true
	_refresh_player_list()
	_update_start_button()


func _on_join_succeeded() -> void:
	if Network.game_in_progress:
		_on_game_in_progress()
		return
	_lbl_status.text = "Conectado. Esperando al anfitrión…"
	_lbl_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_refresh_player_list()


func _on_connection_failed() -> void:
	_lbl_status.text = "Error: no se pudo conectar."
	_lbl_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_btn_host.disabled = false
	_btn_join.disabled = false


func _on_peer_joined(_id: int, _data: Dictionary) -> void:
	_refresh_player_list()
	_update_start_button()


func _on_peer_left(_id: int) -> void:
	_refresh_player_list()
	_update_start_button()


func _on_server_disconnected() -> void:
	_lbl_status.text = "Desconectado del servidor."
	_lbl_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_btn_host.disabled  = false
	_btn_join.disabled  = false
	_btn_start.visible  = false
	_refresh_player_list()


func _on_game_in_progress() -> void:
	_lbl_status.text = "Partida en curso — elige tu raza para unirte"
	_lbl_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_btn_start.visible = true
	_btn_start.text    = "UNIRSE A PARTIDA"
	_update_start_button()


# ── Lista de jugadores ────────────────────────────────────────────────────────

func _refresh_player_list() -> void:
	for child in _player_list.get_children():
		child.queue_free()

	if Network.players.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin jugadores conectados"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		empty_lbl.add_theme_font_size_override("font_size", 8)
		_player_list.add_child(empty_lbl)
		return

	var i := 1
	for pid: int in Network.players:
		var data: Dictionary = Network.players[pid]
		var race_name := _race_display_name(data.get("race_path", ""))
		var suffix := " (tú)" if pid == multiplayer.get_unique_id() else ""
		var has_race: bool = not (data.get("race_path", "") as String).is_empty()
		var row := Label.new()
		row.text = "%d. %s — %s%s%s" % [
			i,
			data.get("display_name", "Jugador"),
			race_name if has_race else "sin raza",
			" ✓" if has_race else "",
			suffix,
		]
		row.add_theme_font_size_override("font_size", 8)
		if has_race:
			row.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		_player_list.add_child(row)
		i += 1


# ── Helpers ───────────────────────────────────────────────────────────────────

func _update_start_button() -> void:
	if not _btn_start.visible:
		return
	if Network.is_hosting:
		# El host puede iniciar en cuanto él mismo tenga una raza (aunque nadie más esté)
		var host_data: Dictionary = Network.players.get(1, {})
		var host_has_race: bool = not (host_data.get("race_path", "") as String).is_empty()
		_btn_start.disabled = not host_has_race
	elif Network.game_in_progress:
		# Cliente tarde: puede unirse cuando tenga raza
		var my_id := multiplayer.get_unique_id()
		var my_data: Dictionary = Network.players.get(my_id, {})
		var has_race: bool = not (my_data.get("race_path", "") as String).is_empty()
		_btn_start.disabled = not has_race


func _race_display_name(path: String) -> String:
	if path.is_empty():
		return ""
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if res == null:
		return path.get_file().get_basename()
	var name_prop = res.get("race_name")
	if name_prop != null:
		return str(name_prop)
	return path.get_file().get_basename()
