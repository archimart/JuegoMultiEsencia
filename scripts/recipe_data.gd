class_name RecipeData
extends Resource

@export var recipe_name: String = ""
@export var ingredients: Dictionary = {}
@export var result_item: String = ""
@export var result_amount: int = 1


func can_craft(inventory: Dictionary) -> bool:
	for item: String in ingredients:
		if inventory.get(item, 0) < ingredients[item]:
			return false
	return true
