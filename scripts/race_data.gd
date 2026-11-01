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
