class_name CompanionAbility
extends Node

## Clase base para habilidades de compañero.
## Cada habilidad concreta extiende esta clase e implementa get_velocity().
## El compañero llama activate() → get_velocity() cada frame → recibe hit_landed/finished.

signal hit_landed(enemy: Node2D, damage_mult: float)
signal finished()

var _active: bool    = false
var _target: Node2D  = null


func activate(enemy: Node2D) -> void:
	_target = enemy
	_active = true
	_on_activate()


func cancel() -> void:
	_active = false
	_target = null
	_on_cancel()


func is_active() -> bool:
	return _active


## Devuelve la velocidad deseada del compañero este frame.
## Emite hit_landed y finished cuando corresponde.
func get_velocity(companion_pos: Vector2) -> Vector2:
	return Vector2.ZERO


func get_speed_scale() -> float:
	return 1.0


# Hooks opcionales para subclases
func _on_activate() -> void: pass
func _on_cancel()   -> void: pass
