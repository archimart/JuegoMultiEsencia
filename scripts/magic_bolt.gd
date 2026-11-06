extends Area2D

const TRAIL_INTERVAL := 0.06

var direction:     Vector2 = Vector2.RIGHT
var damage:        int     = 14
var speed:         float   = 180.0
var max_range:     float   = 300.0
var bolt_color:    Color   = Color(0.6, 0.3, 1.3)
var splash_radius: float   = 0.0
var piercing:      bool    = false
var slow_duration: float   = 0.0
var trail_type:    String  = ""
var impact_fx:     String  = ""

var _origin:  Vector2
var _radius:  float      = 3.0
var _trail_t: float      = 0.0
var _hit_set: Dictionary = {}


func _ready() -> void:
	_origin  = global_position
	_radius  = 5.5 if splash_radius > 0.0 else 3.0
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	global_position += direction * speed * delta
	if trail_type != "":
		_trail_t += delta
		if _trail_t >= TRAIL_INTERVAL:
			_trail_t = 0.0
			FX.particles(global_position, trail_type)
	if global_position.distance_squared_to(_origin) > max_range * max_range:
		_impact(null)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("companion"):
		return
	if not body.is_in_group("monster"):
		_impact(null)
		return
	if _hit_set.has(body):
		return
	_hit_set[body] = true
	if piercing:
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		if slow_duration > 0.0 and body.has_method("apply_slow"):
			body.call("apply_slow", slow_duration)
		for c: Node in get_tree().get_nodes_in_group("companion"):
			if c.has_method("set_attack_target"):
				c.set_attack_target(body)
		var fx := impact_fx if not impact_fx.is_empty() else "magic_hit"
		FX.particles(global_position, fx)
		FX.hit_stop(0.04)
	else:
		_impact(body)


func _impact(direct_hit) -> void:
	if not is_inside_tree():
		return
	set_process(false)
	if direct_hit != null:
		if direct_hit.has_method("take_damage"):
			direct_hit.take_damage(damage, global_position)
		if slow_duration > 0.0 and direct_hit.has_method("apply_slow"):
			direct_hit.call("apply_slow", slow_duration)
		for c: Node in get_tree().get_nodes_in_group("companion"):
			if c.has_method("set_attack_target"):
				c.set_attack_target(direct_hit)
	if splash_radius > 0.0:
		for m: Node in get_tree().get_nodes_in_group("monster"):
			if not is_instance_valid(m) or m == direct_hit or not m is Node2D:
				continue
			if (m as Node2D).global_position.distance_to(global_position) <= splash_radius:
				m.call("take_damage", maxi(1, damage / 2), global_position)
		var fx := impact_fx if not impact_fx.is_empty() else "nova"
		FX.particles(global_position, fx)
		FX.camera_shake(3.5, 0.2)
		FX.hit_stop(0.07)
	else:
		var fx := impact_fx if not impact_fx.is_empty() else "magic_hit"
		FX.particles(global_position, fx)
		if direct_hit != null:
			FX.hit_stop(0.05)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, bolt_color)
	draw_circle(Vector2.ZERO, _radius * 0.45, Color(1.0, 1.0, 1.0, 0.75))
