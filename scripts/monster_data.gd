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
@export var frame_size:      int     = 16

# ── Comportamientos especiales ───────────────────────────────────────────────
@export var flees_when_hurt:  bool  = false  # huye cuando le queda poca vida
@export var flee_threshold:   float = 0.30   # porcentaje de HP al que huye
@export var is_static:        bool  = false  # no persigue, solo ataca en rango
@export var poisons_on_hit:   bool  = false  # envenena al jugador al pegar
@export var poison_dps:       float = 2.0
@export var poison_duration:  float = 4.0

# ── Sistema de esencias y desbloqueo de compañeros ──────────────────────────────
## ID único para contar esencias (ej. "heart", "raccoon"). Dejar vacío si no da esencias.
@export var essence_id:        String        = ""
## Región ecológica: "prairie", "forest", "mountain", "desert", "swamp"
@export var region:            String        = ""
## Compañero que se desbloquea al acumular las esencias necesarias.
@export var companion_data:    CompanionData = null
## Cantidad de esencias necesarias para desbloquear el compañero.
@export var essences_required: int           = 0
