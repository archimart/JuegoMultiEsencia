extends CanvasLayer

signal closed

@onready var _gold_lbl:  Label          = $Panel/VBox/GoldRow/GoldLbl
@onready var _item_list: VBoxContainer  = $Panel/VBox/ItemList
@onready var _feedback:  Label          = $Panel/VBox/Feedback
@onready var _btn_buy:   Button         = $Panel/VBox/TabRow/BtnBuy
@onready var _btn_sell:  Button         = $Panel/VBox/TabRow/BtnSell

var _player: Node2D
var _mode: String = "buy"   # "buy" | "sell"

# Catálogo de compra: { item_id: { cost: int, amount: int, label: String } }
const BUY_CATALOG: Array = [
	{ "id": "arrows",        "cost": 5,  "amount": 10, "label": "Flechas x10" },
	{ "id": "health_potion", "cost": 3,  "amount": 1,  "label": "Poción de vida x1" },
	{ "id": "iron_sword",    "cost": 15, "amount": 1,  "label": "Espada de hierro x1" },
]
# Catálogo de venta: { item_id: { price: int, label: String } }
const SELL_CATALOG: Array = [
	{ "id": "wood",        "price": 1,  "label": "Madera" },
	{ "id": "mineral",     "price": 2,  "label": "Mineral" },
	{ "id": "iron_ingot",  "price": 5,  "label": "Lingote de hierro" },
]


func setup(player: Node2D) -> void:
	_player = player


func _ready() -> void:
	_btn_buy.pressed.connect(func() -> void: _set_mode("buy"))
	_btn_sell.pressed.connect(func() -> void: _set_mode("sell"))
	_refresh()


func _set_mode(mode: String) -> void:
	_mode = mode
	_feedback.text = ""
	_refresh()


func _refresh() -> void:
	_gold_lbl.text = "Oro: %d" % int(_player.inventory.get("gold", 0))
	for c in _item_list.get_children():
		c.queue_free()
	if _mode == "buy":
		_build_buy_rows()
	else:
		_build_sell_rows()


func _build_buy_rows() -> void:
	for entry: Dictionary in BUY_CATALOG:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(12, 12)
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _item_tex(entry["id"])
		row.add_child(icon)

		var lbl := Label.new()
		lbl.text = "%s — %d oro" % [entry["label"], entry["cost"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 8)
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "Comprar"
		btn.custom_minimum_size = Vector2(50, 0)
		btn.add_theme_font_size_override("font_size", 7)
		var gold: int = int(_player.inventory.get("gold", 0))
		btn.disabled = gold < int(entry["cost"])
		btn.pressed.connect(_buy.bind(entry))
		row.add_child(btn)

		_item_list.add_child(row)


func _build_sell_rows() -> void:
	for entry: Dictionary in SELL_CATALOG:
		var id: String    = entry["id"]
		var have: int     = int(_player.inventory.get(id, 0))
		if have <= 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(12, 12)
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _item_tex(id)
		row.add_child(icon)

		var lbl := Label.new()
		lbl.text = "%s x%d — %d oro c/u" % [entry["label"], have, entry["price"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 8)
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "Vender"
		btn.custom_minimum_size = Vector2(50, 0)
		btn.add_theme_font_size_override("font_size", 7)
		btn.pressed.connect(_sell.bind(entry))
		row.add_child(btn)

		_item_list.add_child(row)

	if _item_list.get_child_count() == 0:
		var lbl := Label.new()
		lbl.text = "Sin materiales para vender"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 8)
		_item_list.add_child(lbl)


func _buy(entry: Dictionary) -> void:
	var cost: int   = int(entry["cost"])
	var amount: int = int(entry["amount"])
	var gold: int   = int(_player.inventory.get("gold", 0))
	if gold < cost:
		_feedback.text = "Oro insuficiente"
		return
	_player.inventory["gold"] = gold - cost
	if _player.inventory["gold"] <= 0:
		_player.inventory.erase("gold")
	_player.call("collect_item", entry["id"], amount)
	_feedback.text = "Comprado: %s" % entry["label"]
	if _player.has_signal("inventory_changed"):
		_player.inventory_changed.emit()
	_refresh()


func _sell(entry: Dictionary) -> void:
	var id: String    = entry["id"]
	var price: int    = int(entry["price"])
	var have: int     = int(_player.inventory.get(id, 0))
	if have <= 0:
		_feedback.text = "No tienes %s" % entry["label"]
		return
	_player.inventory.erase(id)
	_player.call("collect_item", "gold", have * price)
	_feedback.text = "Vendido: %s x%d  (+%d oro)" % [entry["label"], have, have * price]
	if _player.has_signal("inventory_changed"):
		_player.inventory_changed.emit()
	_refresh()


func _item_tex(id: String) -> Texture2D:
	var path := "res://resources/item_%s.tres" % id
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res != null:
			return res.get("icon") as Texture2D
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
