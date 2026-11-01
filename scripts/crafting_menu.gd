extends CanvasLayer

signal closed

@onready var _recipe_list: VBoxContainer = $Panel/VBox/RecipeList
@onready var _feedback:    Label         = $Panel/VBox/Feedback

var _player:  Node2D
var _recipes: Array[RecipeData]


func setup(player: Node2D, recipes: Array[RecipeData]) -> void:
	_player  = player
	_recipes = recipes


func _ready() -> void:

	if _player != null:
		_refresh()


func _refresh() -> void:
	for child in _recipe_list.get_children():
		child.queue_free()
	for recipe: RecipeData in _recipes:
		var btn := Button.new()
		btn.text     = _label(recipe)
		btn.disabled = not recipe.can_craft(_player.inventory)
		btn.pressed.connect(_craft.bind(recipe))
		_recipe_list.add_child(btn)


func _label(recipe: RecipeData) -> String:
	var parts: PackedStringArray = []
	for item: String in recipe.ingredients:
		parts.append(str(recipe.ingredients[item]) + " " + item)
	return recipe.recipe_name + "  [" + ", ".join(parts) + "]"


func _craft(recipe: RecipeData) -> void:
	if not recipe.can_craft(_player.inventory):
		_feedback.text = "Sin materiales"
		return
	for item: String in recipe.ingredients:
		_player.inventory[item] = _player.inventory.get(item, 0) - recipe.ingredients[item]
		if _player.inventory[item] <= 0:
			_player.inventory.erase(item)
	_player.collect_item(recipe.result_item, recipe.result_amount)
	_feedback.text = "Fabricado: " + recipe.recipe_name
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
