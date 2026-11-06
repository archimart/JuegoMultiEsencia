class_name CompanionData
extends Resource

@export var companion_name: String = ""

# ── Sprite ──────────────────────────────────────────────────────────────────────
## false = hoja de una fila + flip_h (Parrot, DogBlack, CatBlack)
## true  = SeparateAnim de 4 direcciones (Spirit, Statue)
@export var sprite_is_4dir:      bool   = false
## Modo fila única: ruta a la hoja completa
@export var sprite_tex:          String = ""
## Tamaño de celda para modo fila única
@export var sprite_cell_w:       int    = 16
@export var sprite_cell_h:       int    = 16
## Modo 4-dir: rutas a Walk.png e Idle.png del SeparateAnim
@export var sprite_walk_tex:     String = ""
@export var sprite_idle_tex:     String = ""
@export var sprite_tile_size:    int    = 16
@export var sprite_walk_frames:  int    = 4
@export var sprite_fps:          float  = 6.0

# ── Habilidad ───────────────────────────────────────────────────────────────────
## Ruta a la escena de CompanionAbility que se instancia como hijo del compañero.
## Dejar vacío si el compañero no tiene ataque directo.
@export var ability_scene_path: String = ""

# ── Niveles ─────────────────────────────────────────────────────────────────────
@export var damage_per_level:   Array[int]   = [2, 4, 6, 8, 10]
@export var cooldown_per_level: Array[float] = [3.0, 2.5, 2.0, 1.5, 1.2]
@export var xp_to_next:         Array[int]   = [5, 15, 30, 60, 0]

# ── Soporte (Espíritu del Bosque) ────────────────────────────────────────────────
## Porcentaje de HP máximo que se cura por nivel (0.10 = 10 %)
@export var heal_pct_per_level:        Array[float] = []
## Recarga del escudo en segundos por nivel
@export var shield_cooldown_per_level: Array[float] = []
## Intervalo en segundos entre curaciones automáticas
@export var heal_interval:             float         = 6.0
## El escudo se activa cuando HP < este umbral (0.30 = 30 %)
@export var shield_hp_threshold:       float         = 0.30

# ── HP del compañero (KO al llegar a 0) ─────────────────────────────────────────
## HP máximo por nivel. Si está vacío el compañero es inmortal.
@export var max_hp_per_level: Array[int] = []
