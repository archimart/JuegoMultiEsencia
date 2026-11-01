extends Area2D

const ARROW_TEX := "res://assets/Items/Weapons/Bow/Arrow.png"
const SPEED     := 220.0
const MAX_DIST  := 350.0
const DAMAGE    := 10

@onready var _sprite: Sprite2D = $Sprite2D

var direction: Vector2 = Vector2.RIGHT
var _origin:   Vector2


func _ready() -> void:
	_sprite.texture  = load(ARROW_TEX)
	_sprite.centered = true
	_origin  = global_position
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	global_position += direction * SPEED * delta
	if global_position.distance_squared_to(_origin) > MAX_DIST * MAX_DIST:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE, global_position)
		FX.hit_stop(0.05)
		FX.particles(global_position, "hit")
		# Avisar al compañero para que ataque al monstruo golpeado
		for c: Node in get_tree().get_nodes_in_group("companion"):
			c.set_attack_target(body)
	queue_free()
