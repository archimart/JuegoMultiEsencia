class_name MonsterData
extends Resource

@export var monster_name:    String  = "Monstruo"
@export var max_health:      int     = 20
@export var speed:           float   = 40.0
@export var damage:          int     = 5
@export var vision_range:    float   = 80.0
@export var attack_range:    float   = 14.0
@export var attack_cooldown: float   = 1.2
@export var gold_min:        int     = 1
@export var gold_max:        int     = 3
@export var sprite_path:     String  = ""

# ── Sistema de esencias y desbloqueo de compañeros ──────────────────────────────
## ID único para contar esencias (ej. "heart", "raccoon"). Dejar vacío si no da esencias.
@export var essence_id:        String        = ""
## Región ecológica: "prairie", "forest", "mountain", "desert", "swamp"
@export var region:            String        = ""
## Compañero que se desbloquea al acumular las esencias necesarias.
@export var companion_data:    CompanionData = null
## Cantidad de esencias necesarias para desbloquear el compañero.
@export var essences_required: int           = 0
