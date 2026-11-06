class_name RaceData
extends Resource

@export var race_name:          String      = "Humano"
@export var description:        String      = ""
@export var walk_tex_path:      String      = ""
@export var idle_tex_path:      String      = ""
@export var max_hp:             int         = 30
@export var speed:              float       = 80.0
@export var damage_multiplier:  float       = 1.0   # reservado para ataques propios de raza
@export var companion_data:     CompanionData = null
@export var sprite_dir_path_m:  String        = ""   # carpeta base del personaje masculino
@export var sprite_dir_path_f:  String        = ""   # carpeta base del personaje femenino
## Región ecológica de afinidad: "prairie", "forest", "mountain", "desert", "swamp"
@export var region:             String        = ""
## Tinte de color aplicado al sprite según el género elegido (multiplicativo)
@export var modulate_m:         Color         = Color.WHITE
@export var modulate_f:         Color         = Color.WHITE
## Color original del cabello en el sprite (usado por el shader para detectar qué píxeles teñir)
## alpha=0 significa "sin tinte de cabello configurado"
@export var hair_color_m:            Color          = Color(0.0, 0.0, 0.0, 0.0)
@export var hair_color_f:            Color          = Color(0.0, 0.0, 0.0, 0.0)
## Variantes de sprite pre-coloreadas (carpeta raíz de cada variante)
@export var sprite_variant_dirs_m:   Array[String]  = []
@export var sprite_variant_names_m:  Array[String]  = []
@export var sprite_variant_dirs_f:   Array[String]  = []
@export var sprite_variant_names_f:  Array[String]  = []
