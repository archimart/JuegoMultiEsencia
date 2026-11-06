extends CanvasLayer

signal closed

@onready var _recipe_list: VBoxContainer = $Panel/VBox/RecipeList
@onready var _feedback:    Label         = $Panel/VBox/Feedback

var _player:  Node2D
var _recipes: Array[RecipeData]

# Cache de texturas de ítems para no recargar en cada refresh
var _tex_cache: Dictionary = {}


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
		_recipe_list.add_child(_build_row(recipe))


func _build_row(recipe: RecipeData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Icono del resultado
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _item_tex(recipe.result_item)
	row.add_child(icon)

	# Centro: nombre + ingredientes
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 1)

	var name_lbl := Label.new()
	name_lbl.text = recipe.recipe_name
	name_lbl.add_theme_font_size_override("font_size", 8)
	center.add_child(name_lbl)

	var ingr_row := HBoxContainer.new()
	ingr_row.add_theme_constant_override("separation", 3)
	var inv := _player.inventory if _player != null else {}
	for ing_id: String in recipe.ingredients:
		var needed: int = recipe.ingredients[ing_id]
		var have:   int = int(inv.get(ing_id, 0))
		var enough := have >= needed

		var ingr_icon := TextureRect.new()
		ingr_icon.custom_minimum_size = Vector2(10, 10)
		ingr_icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		ingr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ingr_icon.texture = _item_tex(ing_id)
		if not enough:
			ingr_icon.modulate = Color(1.0, 0.4, 0.4)
		ingr_row.add_child(ingr_icon)

		var cnt_lbl := Label.new()
		cnt_lbl.text = "%d" % needed
		cnt_lbl.add_theme_font_size_override("font_size", 7)
		cnt_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.4) if enough else Color(1.0, 0.35, 0.35))
		ingr_row.add_child(cnt_lbl)

	center.add_child(ingr_row)
	row.add_child(center)

	# Botón craft
	var btn := Button.new()
	btn.text     = "Craft"
	btn.disabled = not recipe.can_craft(inv)
	btn.custom_minimum_size = Vector2(36, 0)
	btn.add_theme_font_size_override("font_size", 8)
	btn.pressed.connect(_craft.bind(recipe))
	row.add_child(btn)

	return row


func _craft(recipe: RecipeData) -> void:
	if _player == null or not recipe.can_craft(_player.inventory):
		_feedback.text = "Sin materiales"
		return
	for item: String in recipe.ingredients:
		_player.inventory[item] = _player.inventory.get(item, 0) - recipe.ingredients[item]
		if _player.inventory[item] <= 0:
			_player.inventory.erase(item)
	_player.collect_item(recipe.result_item, recipe.result_amount)
	_feedback.text = "Fabricado: " + recipe.recipe_name
	if _player.has_signal("inventory_changed"):
		_player.inventory_changed.emit()
	_refresh()


func _item_tex(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := "res://resources/item_%s.tres" % id
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res != null:
			var tex := res.get("icon") as Texture2D
			_tex_cache[id] = tex
			return tex
	_tex_cache[id] = null
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
