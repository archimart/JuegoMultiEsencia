class_name CityNPC
extends StaticBody2D

@export var npc_name:    String = "NPC"
@export var atlas_region: Rect2 = Rect2(0, 112, 16, 16)

const _TD := "res://assets/kenney/kenney_tiny-dungeon/Tilemap/tilemap_packed.png"


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 1  # capa Mundo
	collision_mask  = 0

	var atlas := AtlasTexture.new()
	atlas.atlas  = load(_TD)
	atlas.region = atlas_region
	$Sprite2D.texture = atlas

	var circle := CircleShape2D.new()
	circle.radius = 5.0
	$CollisionShape2D.shape = circle
