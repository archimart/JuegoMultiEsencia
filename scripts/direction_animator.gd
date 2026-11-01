class_name DirectionAnimator
extends RefCounted

## Solo cambia de eje cuando un componente supera al otro en este factor.
const HYSTERESIS := 0.30
## Debajo de esta velocidad (px/s) no se actualiza la dirección.
const MIN_SPEED  := 10.0

var _dir: String = "down"


## Actualiza con la velocidad actual; no cambia dirección bajo MIN_SPEED.
func update_velocity(vel: Vector2) -> String:
	if vel.length_squared() < MIN_SPEED * MIN_SPEED:
		return _dir
	return _pick(vel)


## Actualiza la dirección para mirar hacia un objetivo (estado ataque/seguimiento parado).
func face_target(origin: Vector2, target: Vector2) -> String:
	var diff := target - origin
	if diff.length_squared() < 1.0:
		return _dir
	return _pick(diff)


func get_dir() -> String:
	return _dir


## Construye (o extiende) SpriteFrames con el layout estándar Ninja Adventure:
##   columna = dirección  (0=abajo, 1=arriba, 2=izquierda, 3=derecha)
##   fila    = cuadro de animación
## prefix: "walk" genera "walk_down", "walk_up", "walk_left", "walk_right"
## frames:  pasar uno existente para añadir animaciones encima (walk+idle, etc.)
static func build_4dir_frames(
	tex: Texture2D,
	tile_size: int,
	num_frames: int,
	fps: float,
	prefix: String = "walk",
	frames: SpriteFrames = null
) -> SpriteFrames:
	if frames == null:
		frames = SpriteFrames.new()
		frames.remove_animation("default")
	var dirs := [["down", 0], ["up", 1], ["left", 2], ["right", 3]]
	for d: Array in dirs:
		var anim: String = prefix + "_" + (d[0] as String)
		var col:  int    = d[1]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, true)
		for row: int in num_frames:
			var a := AtlasTexture.new()
			a.atlas  = tex
			a.region = Rect2(col * tile_size, row * tile_size, tile_size, tile_size)
			frames.add_frame(anim, a)
	return frames


func _pick(v: Vector2) -> String:
	var ax   := absf(v.x)
	var ay   := absf(v.y)
	var is_h := _dir == "left" or _dir == "right"
	if is_h:
		if ay > ax * (1.0 + HYSTERESIS):
			_dir = "down" if v.y >= 0.0 else "up"
		else:
			_dir = "right" if v.x >= 0.0 else "left"
	else:
		if ax > ay * (1.0 + HYSTERESIS):
			_dir = "right" if v.x >= 0.0 else "left"
		else:
			_dir = "down" if v.y >= 0.0 else "up"
	return _dir
