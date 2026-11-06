extends Area2D

# Zona segura: esquina superior-izquierda, world rect (0,0)-(160,128) = 10×8 tiles.
# Este nodo se posiciona en el centro geométrico (80, 64).
# La RectangleShape2D debe tener size=(160, 128).

const REGEN_INTERVAL := 2.0   # 1 HP cada N segundos

var _player:  Node2D = null
var _regen_t: float  = 0.0


func _ready() -> void:
	add_to_group("safe_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _player == null:
		return
	_regen_t -= delta
	if _regen_t <= 0.0:
		_regen_t = REGEN_INTERVAL
		if _player.hp < _player.max_hp:
			_player.hp = mini(_player.hp + 1, _player.max_hp)
			_player.health_changed.emit()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	body.in_safe_zone = true
	body.notice_requested.emit("Zona segura")
	if has_node("/root/FamiliarSystem"):
		FamiliarSystem.instant_recover_all()


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player.in_safe_zone = false
	_player = null
	body.notice_requested.emit("Saliendo de la zona segura")


func _draw() -> void:
	var r := Rect2(-80.0, -64.0, 160.0, 128.0)
	draw_rect(r, Color(0.3, 0.9, 0.4, 0.10))
	draw_rect(r, Color(0.3, 0.9, 0.4, 0.55), false, 1.0)
