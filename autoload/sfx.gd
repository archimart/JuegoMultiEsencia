extends Node
## Reproductor de efectos de sonido. Llama SFX.play("clave") desde cualquier script.

const SOUNDS: Dictionary = {
	"hit_player":  "res://assets/Audio/Sounds/Hit & Impact/Hit3.wav",
	"hit_monster": "res://assets/Audio/Sounds/Hit & Impact/Hit1.wav",
	"chop":        "res://assets/Audio/Sounds/Elemental/Grass.wav",
	"shoot":       "res://assets/Audio/Sounds/Magic & Skill/Fx.wav",
	"coin":        "res://assets/Audio/Sounds/Bonus/Coin.wav",
	"die_monster": "res://assets/Audio/Sounds/Hit & Impact/Impact.wav",
	"die_player":  "res://assets/Audio/Jingles/GameOver.wav",
	"spirit":      "res://assets/Audio/Sounds/Magic & Skill/Spirit.wav",
	"ui_click":    "res://assets/Audio/Sounds/Menu/Accept.wav",
	"ui_hover":    "res://assets/Audio/Sounds/Menu/Move1.wav",
	"mine":        "res://assets/Audio/Sounds/Hit & Impact/Impact3.wav",
}


func play(key: String, volume_db: float = 0.0) -> void:
	if not SOUNDS.has(key):
		return
	var ap := AudioStreamPlayer.new()
	ap.stream    = load(SOUNDS[key])
	ap.volume_db = volume_db
	ap.autoplay  = true
	ap.finished.connect(ap.queue_free)
	add_child(ap)
