extends CanvasLayer

# ── Nodos del .tscn ───────────────────────────────────────────────────────────
@onready var _stats_panel:    Panel = $Root/LeftCol/StatsPanel
@onready var _comp_hud:       Panel = $Root/LeftCol/CompPanel
@onready var _fam_hud:        Panel = $Root/LeftCol/FamPanel
@onready var _egg_panel_hud:  Panel = $Root/LeftCol/EggPanel

# ── Layout ────────────────────────────────────────────────────────────────────
const HOTBAR_N   := 8
const HOTBAR_S   := 18    # tamaño exterior del slot
const HOTBAR_GAP := 2
const HOTBAR_PAD := 3

const INV_COLS := 4
const INV_S    := 20    # tamaño exterior del slot en inventario
const INV_GAP  := 2

# ── Colores ───────────────────────────────────────────────────────────────────
const C_BG     := Color(0.07, 0.07, 0.10, 0.82)
const C_INV_BG := Color(0.07, 0.07, 0.10, 0.94)
const C_SLOT   := Color(0.10, 0.10, 0.16, 0.90)
const C_BORDER := Color(0.25, 0.25, 0.35, 0.90)
const C_TEXT   := Color(0.92, 0.92, 0.85, 1.00)
const C_SHADOW := Color(0.00, 0.00, 0.00, 0.85)
const C_MUTED  := Color(0.60, 0.60, 0.70, 1.00)

# ── Iconos del panel de stats ─────────────────────────────────────────────────
const ICON_HEART := "res://assets/Items/Potion/Heart.png"
const ICON_COIN  := "res://assets/Items/Treasure/GoldCoin.png"
const ICON_ARROW := "res://assets/Items/Projectile/Arrow.png"
const ICON_EGG   := "res://assets/Items/Egg.png"

# ── Estado ────────────────────────────────────────────────────────────────────
var _player:    Node2D
var _notice_id: int        = 0
var _item_reg:  Dictionary = {}   # item_id -> Resource (ItemData)

# Refs panel stats
var _hp_fill:       ColorRect
var _gold_lbl:      Label
var _arr_lbl:       Label
var _player_lvl_lbl: Label
var _player_xp_fill: ColorRect

# Refs panel compañero
var _comp_name_lbl: Label
var _comp_lvl_lbl: Label
var _comp_xp_fill: ColorRect

# Refs hotbar (arrays en paralelo, tamaño HOTBAR_N)
var _hb_icons:  Array[TextureRect] = []
var _hb_counts: Array[Label]       = []

# Inventario (null cuando está cerrado)
var _inv_panel: Panel         = null
var _inv_grid:  GridContainer = null

# Panel de compañeros (null cuando está cerrado)
var _comp_panel: Panel = null
var _companion_node: Node = null

# Familiares (panel HUD)
var _fam_slot_fills: Array[ColorRect]  = []  # HP fills de los 5 slots
var _fam_thumbs:     Array[TextureRect] = []  # Thumbnails de los 5 slots
var _fam_hp_fills:   Dictionary        = {}  # {monster_id: ColorRect} actualizado en _process
var _fam_hp_tick:    float             = 0.0

# Widget de incubación de huevo
var _egg_hud:          Panel       = null
var _egg_hud_name_lbl: Label       = null
var _egg_hud_bar_fill: ColorRect   = null
var _egg_hud_count_lbl: Label      = null
var _egg_hud_icon:     TextureRect = null

# Aviso / hint
var _hint_lbl: Label

# Slot de arma equipada (fila 4 del panel de stats)
var _weapon_lbl: Label = null

# Barra de maná (Mago)
var _mana_bg:   ColorRect = null
var _mana_fill: ColorRect = null

# Panel de habilidades del Guerrero
var _skill_bar: Panel         = null
var _skill_cd_lbls:  Array[Label]     = []
var _skill_cd_fills: Array[ColorRect] = []
var _equipped_weapon_id: String       = ""


# ── API pública ───────────────────────────────────────────────────────────────

func set_player(p: Node2D) -> void:
	_player = p
	if has_node("/root/UIManager"):
		UIManager.register_player(p)
	p.inventory_changed.connect(_refresh)
	p.inventory_changed.connect(_reopen_comp_panel)
	p.health_changed.connect(_update_hp)
	p.notice_requested.connect(show_notice)
	if p.has_signal("xp_changed"):
		p.xp_changed.connect(_update_player_xp)
	if p.has_signal("level_changed"):
		p.level_changed.connect(_update_player_level)
	if p.has_signal("weapon_changed"):
		p.weapon_changed.connect(_on_weapon_changed)
	if p.has_signal("skill_cooldown_changed"):
		p.skill_cooldown_changed.connect(_update_skill_cd)
	if p.has_signal("blocking_changed"):
		p.blocking_changed.connect(_on_blocking_changed)
	if p.has_signal("class_changed"):
		p.class_changed.connect(_on_class_changed)
	if p.has_signal("mana_changed"):
		p.mana_changed.connect(_update_mana)
	_refresh()
	_update_hp()
	_update_player_level(p.get("level") if p.get("level") != null else 1)
	_update_player_xp(p.get("xp") if p.get("xp") != null else 0, 50)


# ── Ciclo de vida ─────────────────────────────────────────────────────────────

func _ready() -> void:
	if has_node("/root/UIManager"):
		$Root.theme = UIManager.game_theme
	_load_item_reg()
	_reg_inv_action()
	_build_stats()
	_build_companion_panel()
	_build_familiar_panel()
	_build_egg_hud()
	_build_hotbar()
	_build_hint()
	if has_node("/root/CompanionSystem"):
		CompanionSystem.team_changed.connect(_on_team_changed_hud)
		CompanionSystem.companion_unlocked.connect(_on_companion_unlocked_hud)
		CompanionSystem.essence_gained.connect(_on_essence_gained_hud)
	if has_node("/root/FamiliarSystem"):
		FamiliarSystem.roster_changed.connect(_refresh_familiar_panel)
		FamiliarSystem.roster_changed.connect(_reopen_comp_panel)
		FamiliarSystem.roster_changed.connect(_refresh_egg_hud)
		FamiliarSystem.egg_progress_changed.connect(_on_egg_progress)
		FamiliarSystem.egg_ready.connect(_on_egg_ready_hud)


func _process(delta: float) -> void:
	_fam_hp_tick += delta
	if _fam_hp_tick >= 0.25:
		_fam_hp_tick = 0.0
		_update_fam_hp_bars()


func _update_fam_hp_bars() -> void:
	for mid: String in _fam_hp_fills.keys():
		var fill: ColorRect = _fam_hp_fills[mid]
		if not is_instance_valid(fill):
			_fam_hp_fills.erase(mid)
			continue
		var fam := _get_active_fam_node(mid)
		if fam == null:
			fill.size.x = 0.0
			continue
		var fam_hp: int  = int(fam.get("hp"))
		var fam_max: int = int(fam.get("_max_hp"))
		if fam_max <= 0:
			continue
		var ratio := clampf(float(fam_hp) / float(fam_max), 0.0, 1.0)
		fill.size.x = 12.0 * ratio
		fill.color  = Color(0.25, 0.85, 0.25) if ratio > 0.5 else Color(0.9, 0.3, 0.1)


func _get_active_fam_node(monster_id: String) -> Node:
	if not is_inside_tree():
		return null
	for fam in get_tree().get_nodes_in_group("familiar"):
		if str(fam.get("monster_id")) == monster_id:
			return fam
	return null


func _load_item_reg() -> void:
	for id: String in ["wood", "bow", "arrows", "gold", "sword", "staff", "mineral", "iron_ingot"]:
		var path := "res://resources/item_" + id + ".tres"
		if ResourceLoader.exists(path):
			_item_reg[id] = load(path)


func _reg_inv_action() -> void:
	if not InputMap.has_action("inventory"):
		InputMap.add_action("inventory")
		for kc: int in [KEY_I, KEY_TAB]:
			var ev := InputEventKey.new()
			ev.keycode = kc
			InputMap.action_add_event("inventory", ev)
	if not InputMap.has_action("companions"):
		InputMap.add_action("companions")
		var ev := InputEventKey.new()
		ev.keycode = KEY_C
		InputMap.action_add_event("companions", ev)


# ── Panel de stats (arriba-izquierda) ─────────────────────────────────────────

func _build_stats() -> void:
	_stats_panel.add_theme_stylebox_override("panel", _sb(C_BG))

	# Fila 1: corazón + barra HP + nivel jugador
	_tex(_stats_panel, ICON_HEART, Vector2(4, 4), Vector2(9, 8))
	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(15, 5)
	hp_bg.size     = Vector2(50, 6)
	hp_bg.color    = Color(0.15, 0.15, 0.15, 1)
	_stats_panel.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2(15, 5)
	_hp_fill.size     = Vector2(50, 6)
	_hp_fill.color    = Color(0.25, 0.85, 0.25, 1)
	_stats_panel.add_child(_hp_fill)
	_player_lvl_lbl = _lbl("Nv.1", Vector2(67, 3), _stats_panel, 7)
	_player_lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))

	# Barra de maná (solo visible para Mago)
	_mana_bg = ColorRect.new()
	_mana_bg.position = Vector2(4, 13)
	_mana_bg.size     = Vector2(50, 3)
	_mana_bg.color    = Color(0.05, 0.10, 0.25, 1)
	_mana_bg.visible  = false
	_stats_panel.add_child(_mana_bg)
	_mana_fill = ColorRect.new()
	_mana_fill.position = Vector2(4, 13)
	_mana_fill.size     = Vector2(50, 3)
	_mana_fill.color    = Color(0.2, 0.55, 1.0, 1)
	_mana_fill.visible  = false
	_stats_panel.add_child(_mana_fill)

	# Fila 2: barra de XP del jugador
	var xp_bg := ColorRect.new()
	xp_bg.position = Vector2(4, 17)
	xp_bg.size     = Vector2(84, 4)
	xp_bg.color    = Color(0.12, 0.12, 0.12, 1)
	_stats_panel.add_child(xp_bg)
	_player_xp_fill = ColorRect.new()
	_player_xp_fill.position = Vector2(4, 17)
	_player_xp_fill.size     = Vector2(0, 4)
	_player_xp_fill.color    = Color(0.55, 0.35, 1.0, 1)
	_stats_panel.add_child(_player_xp_fill)

	# Fila 3: moneda | flechas
	_tex(_stats_panel, ICON_COIN, Vector2(4, 22), Vector2(8, 8))
	_gold_lbl = _lbl("0", Vector2(14, 21), _stats_panel, 7)
	var sep := ColorRect.new()
	sep.position = Vector2(44, 20)
	sep.size     = Vector2(1, 12)
	sep.color    = Color(0.4, 0.4, 0.5, 0.40)
	_stats_panel.add_child(sep)
	_tex(_stats_panel, ICON_ARROW, Vector2(48, 22), Vector2(8, 8))
	_arr_lbl = _lbl("0", Vector2(58, 21), _stats_panel, 7)

	# Fila 4: arma equipada
	var wsep := ColorRect.new()
	wsep.position = Vector2(4, 32)
	wsep.size     = Vector2(84, 1)
	wsep.color    = Color(0.4, 0.4, 0.5, 0.40)
	_stats_panel.add_child(wsep)
	_weapon_lbl = _lbl("Puños", Vector2(4, 35), _stats_panel, 6)
	_weapon_lbl.size = Vector2(84, 9)
	_weapon_lbl.add_theme_color_override("font_color", C_MUTED)


func set_companion(comp: Node) -> void:
	_companion_node = comp
	comp.xp_changed.connect(_update_comp_xp)
	comp.level_changed.connect(_update_comp_level)
	comp.notice_requested.connect(show_notice)
	var data = comp.get("data")
	if data != null and _comp_name_lbl != null:
		var raw: String = str(data.get("companion_name"))
		_comp_name_lbl.text = raw.substr(0, 6) if raw.length() > 6 else raw
	_update_comp_level(comp.get_level_display())
	_update_comp_xp(0, comp._get_xp_to_next())


func _build_companion_panel() -> void:
	_comp_hud.add_theme_stylebox_override("panel", _sb(C_BG))

	_comp_name_lbl = Label.new()
	_comp_name_lbl.text     = "---"
	_comp_name_lbl.position = Vector2(3, 2)
	_comp_name_lbl.size     = Vector2(32, 8)
	_comp_name_lbl.add_theme_font_size_override("font_size", 6)
	_comp_name_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	_comp_hud.add_child(_comp_name_lbl)

	_comp_lvl_lbl = Label.new()
	_comp_lvl_lbl.text     = "Nv.1"
	_comp_lvl_lbl.position = Vector2(36, 2)
	_comp_lvl_lbl.size     = Vector2(22, 8)
	_comp_lvl_lbl.add_theme_font_size_override("font_size", 6)
	_comp_lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_comp_hud.add_child(_comp_lvl_lbl)

	# Fondo de barra XP
	var xp_bg := ColorRect.new()
	xp_bg.position = Vector2(59, 5)
	xp_bg.size     = Vector2(30, 5)
	xp_bg.color    = Color(0.12, 0.12, 0.12, 1)
	_comp_hud.add_child(xp_bg)

	_comp_xp_fill = ColorRect.new()
	_comp_xp_fill.position = Vector2(59, 5)
	_comp_xp_fill.size     = Vector2(0, 5)
	_comp_xp_fill.color    = Color(0.35, 0.65, 1.0, 1)
	_comp_hud.add_child(_comp_xp_fill)


func _update_comp_level(lvl: int) -> void:
	if _comp_lvl_lbl == null:
		return
	var max_lvl: int = 5
	_comp_lvl_lbl.text = "Nv.%d" % lvl if lvl < max_lvl else "Nv.MÁX"


func _update_comp_xp(current: int, to_next: int) -> void:
	if _comp_xp_fill == null:
		return
	if to_next <= 0:
		_comp_xp_fill.size.x = 30.0
		_comp_xp_fill.color  = Color(1.0, 0.75, 0.1)
		return
	var r := clampf(float(current) / float(to_next), 0.0, 1.0)
	_comp_xp_fill.size.x = 30.0 * r


func _update_hp() -> void:
	if _player == null or _hp_fill == null:
		return
	var r := clampf(float(_player.hp) / float(_player.max_hp), 0.0, 1.0)
	_hp_fill.size.x = 50.0 * r
	_hp_fill.color  = Color(0.25, 0.85, 0.25) if r > 0.5 else Color(0.90, 0.30, 0.10)


func _update_mana(current: int, total: int) -> void:
	if _mana_fill == null:
		return
	if total <= 0:
		_mana_fill.size.x = 0.0
		return
	_mana_fill.size.x = 50.0 * clampf(float(current) / float(total), 0.0, 1.0)


func _update_player_level(lvl: int) -> void:
	if _player_lvl_lbl == null:
		return
	_player_lvl_lbl.text = "MÁX" if lvl > 9 else "Nv.%d" % lvl


func _update_player_xp(current: int, to_next: int) -> void:
	if _player_xp_fill == null:
		return
	if to_next <= 0:
		_player_xp_fill.size.x = 84.0
		return
	_player_xp_fill.size.x = 84.0 * clampf(float(current) / float(to_next), 0.0, 1.0)


# ── Panel de familiares (abajo del compañero) ─────────────────────────────────

func _build_familiar_panel() -> void:
	const SLOT_S := 14
	const GAP    := 2
	const FAM_N  := 5
	_fam_hud.add_theme_stylebox_override("panel", _sb(C_BG))

	var hdr := _lbl("FAMILIARES", Vector2(3, 2), _fam_hud, 5)
	hdr.add_theme_color_override("font_color", C_MUTED)

	_fam_slot_fills.clear()
	_fam_thumbs.clear()
	for i: int in FAM_N:
		var sx := 3 + i * (SLOT_S + GAP)
		var slot := Panel.new()
		slot.position = Vector2(sx, 8)
		slot.size     = Vector2(SLOT_S, SLOT_S)
		slot.add_theme_stylebox_override("panel", _sb_slot())
		_fam_hud.add_child(slot)

		var thumb := TextureRect.new()
		thumb.position    = Vector2(1, 1)
		thumb.size        = Vector2(SLOT_S - 2, SLOT_S - 4)
		thumb.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(thumb)
		_fam_thumbs.append(thumb)

		var hp_bg := ColorRect.new()
		hp_bg.position = Vector2(1, SLOT_S - 3)
		hp_bg.size     = Vector2(SLOT_S - 2, 2)
		hp_bg.color    = Color(0.1, 0.1, 0.1)
		slot.add_child(hp_bg)

		var hp_fill := ColorRect.new()
		hp_fill.position = Vector2(1, SLOT_S - 3)
		hp_fill.size     = Vector2(0, 2)
		hp_fill.color    = Color(0.25, 0.85, 0.25)
		slot.add_child(hp_fill)
		_fam_slot_fills.append(hp_fill)


func _refresh_familiar_panel() -> void:
	if not has_node("/root/FamiliarSystem"):
		return
	var owned  := FamiliarSystem.get_owned_ids()
	var active := FamiliarSystem.get_familiar_monster_ids()
	_fam_hp_fills.clear()
	for i: int in _fam_thumbs.size():
		var thumb: TextureRect = _fam_thumbs[i]
		var hp_fill: ColorRect = _fam_slot_fills[i]
		if i >= owned.size():
			thumb.texture  = null
			hp_fill.size.x = 0.0
			continue
		var mid := owned[i]
		thumb.texture = _get_fam_atlas(mid)
		if active.has(mid):
			thumb.modulate = Color.WHITE
			_fam_hp_fills[mid] = hp_fill
			hp_fill.size.x     = 12.0
		else:
			thumb.modulate = Color(0.4, 0.4, 0.4, 0.8)
			hp_fill.size.x = 0.0


func _build_egg_hud() -> void:
	_egg_hud = _egg_panel_hud
	_egg_hud.add_theme_stylebox_override("panel", _sb(C_BG))

	var hdr := _lbl("INCUBANDO", Vector2(3, 2), _egg_hud, 5)
	hdr.add_theme_color_override("font_color", C_MUTED)

	_egg_hud_icon = TextureRect.new()
	_egg_hud_icon.texture     = load(ICON_EGG)
	_egg_hud_icon.position    = Vector2(3, 10)
	_egg_hud_icon.size        = Vector2(7, 7)
	_egg_hud_icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_egg_hud_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_egg_hud.add_child(_egg_hud_icon)

	_egg_hud_name_lbl = _lbl("---", Vector2(13, 10), _egg_hud, 6)

	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(42, 12)
	bar_bg.size     = Vector2(34, 3)
	bar_bg.color    = Color(0.12, 0.12, 0.12)
	_egg_hud.add_child(bar_bg)

	_egg_hud_bar_fill = ColorRect.new()
	_egg_hud_bar_fill.position = Vector2(42, 12)
	_egg_hud_bar_fill.size     = Vector2(0, 3)
	_egg_hud_bar_fill.color    = Color(0.9, 0.75, 0.1)
	_egg_hud.add_child(_egg_hud_bar_fill)

	_egg_hud_count_lbl = Label.new()
	_egg_hud_count_lbl.position = Vector2(78, 10)
	_egg_hud_count_lbl.size     = Vector2(12, 7)
	_egg_hud_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_egg_hud_count_lbl.add_theme_font_size_override("font_size", 5)
	_egg_hud_count_lbl.add_theme_color_override("font_color", C_MUTED)
	_egg_hud.add_child(_egg_hud_count_lbl)


func _refresh_egg_hud() -> void:
	if _egg_hud == null or _player == null:
		return
	if not has_node("/root/FamiliarSystem"):
		return
	var inv: Dictionary = _player.get("inventory") if _player != null else {}
	var best_id: String  = ""
	var best_kills: int  = -1
	var best_ready: bool = false
	var needed: int      = FamiliarSystem.KILLS_TO_HATCH
	for item_id: String in inv.keys():
		if not item_id.begins_with("egg_"):
			continue
		if int(inv.get(item_id, 0)) <= 0:
			continue
		var kills := int(FamiliarSystem.egg_kills.get(item_id, 0))
		var ready := kills >= needed
		if ready and not best_ready:
			best_id    = item_id
			best_kills = kills
			best_ready = true
		elif ready == best_ready and kills > best_kills:
			best_id    = item_id
			best_kills = kills
	if best_id.is_empty():
		_egg_hud_name_lbl.text = "---"
		_egg_hud_name_lbl.add_theme_color_override("font_color", C_MUTED)
		_egg_hud_count_lbl.text = ""
		_egg_hud_bar_fill.size.x = 0.0
		_egg_hud_icon.modulate   = Color(0.5, 0.5, 0.5, 0.5)
		return
	var mid := best_id.substr(4)
	_egg_hud_name_lbl.text = mid.capitalize()
	var ratio := clampf(float(best_kills) / float(needed), 0.0, 1.0)
	_egg_hud_bar_fill.size.x = 34.0 * ratio
	if best_ready:
		_egg_hud_bar_fill.color = Color(0.3, 1.0, 0.5)
		_egg_hud_count_lbl.text = "LISTO!"
		_egg_hud_count_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		_egg_hud_name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		_egg_hud_bar_fill.color = Color(0.9, 0.75, 0.1)
		_egg_hud_count_lbl.text = "%d/10" % best_kills
		_egg_hud_count_lbl.add_theme_color_override("font_color", C_MUTED)
		_egg_hud_name_lbl.add_theme_color_override("font_color", C_TEXT)
	var rar := FamiliarSystem.get_egg_rarity(mid)
	_egg_hud_icon.modulate = _rarity_color(rar.get("rarity", "common"), rar.get("is_shiny", false))


func _on_egg_ready_hud(_item_id: String) -> void:
	_refresh_egg_hud()
	if _egg_hud == null:
		return
	_egg_hud.pivot_offset = Vector2(46.0, 10.0)
	var tw := _egg_hud.create_tween()
	for _i in 2:
		tw.tween_property(_egg_hud, "scale", Vector2(1.04, 1.0), 0.07)
		tw.tween_property(_egg_hud, "scale", Vector2(0.96, 1.0), 0.07)
	tw.tween_property(_egg_hud, "scale", Vector2(1.0, 1.0), 0.06)


func _rarity_color(rar: String, is_shiny: bool) -> Color:
	if is_shiny:
		return Color(1.0, 0.85, 0.2)
	match rar:
		"rare": return Color(0.5, 0.75, 1.0)
		"epic": return Color(0.9, 0.5, 1.0)
	return Color(1.0, 0.95, 0.75)


# ── Barra rápida (abajo-centro) ───────────────────────────────────────────────

func _build_hotbar() -> void:
	var tw := HOTBAR_N * HOTBAR_S + (HOTBAR_N - 1) * HOTBAR_GAP
	var pw := tw + HOTBAR_PAD * 2
	var ph := HOTBAR_S + HOTBAR_PAD * 2
	var vp := get_viewport().get_visible_rect().size

	var root := Panel.new()
	root.position = Vector2(roundf((vp.x - pw) * 0.5), vp.y - ph - 2)
	root.size     = Vector2(pw, ph)
	root.add_theme_stylebox_override("panel", _sb(C_BG))
	add_child(root)

	for i: int in HOTBAR_N:
		var sx   := HOTBAR_PAD + i * (HOTBAR_S + HOTBAR_GAP)
		var slot := Panel.new()
		slot.position = Vector2(sx, HOTBAR_PAD)
		slot.size     = Vector2(HOTBAR_S, HOTBAR_S)
		slot.add_theme_stylebox_override("panel", _sb_slot())
		root.add_child(slot)

		const ICON_S := 12
		const OFF    := (HOTBAR_S - ICON_S) / 2
		var icon := TextureRect.new()
		icon.position    = Vector2(OFF, OFF)
		icon.size        = Vector2(ICON_S, ICON_S)
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)
		_hb_icons.append(icon)

		var cnt := Label.new()
		cnt.position = Vector2(HOTBAR_S - 10, HOTBAR_S - 9)
		cnt.size     = Vector2(9, 8)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_font_size_override("font_size", 6)
		cnt.add_theme_color_override("font_color",        C_TEXT)
		cnt.add_theme_color_override("font_shadow_color", C_SHADOW)
		cnt.add_theme_constant_override("shadow_offset_x", 1)
		cnt.add_theme_constant_override("shadow_offset_y", 1)
		slot.add_child(cnt)
		_hb_counts.append(cnt)


# ── Inventario completo (toggle I / Tab) ──────────────────────────────────────

func _toggle_inventory() -> void:
	var was_open := _inv_panel != null
	if has_node("/root/UIManager"):
		UIManager.close_all()
	elif _inv_panel != null:
		_inv_panel.queue_free()
		_inv_panel = null
		_inv_grid  = null
	if not was_open and _player != null:
		_open_inventory()


func _open_inventory() -> void:
	var keys: Array = _player.inventory.keys()
	var rows: int   = max(1, ceili(float(keys.size()) / float(INV_COLS)))
	const PAD:   int = 6
	const TITLE: int = 14
	const CLOSE: int = 11
	var iw: int = INV_COLS * INV_S + (INV_COLS - 1) * INV_GAP
	var ih: int = rows * INV_S + max(0, rows - 1) * INV_GAP
	var pw: int = iw + PAD * 2
	var ph: int = TITLE + ih + CLOSE + PAD * 2 + 4
	var vp := get_viewport().get_visible_rect().size

	_inv_panel = Panel.new()
	_inv_panel.position = Vector2(roundf((vp.x - pw) * 0.5), roundf((vp.y - ph) * 0.5))
	_inv_panel.size     = Vector2(pw, ph)
	_inv_panel.add_theme_stylebox_override("panel", _sb(C_INV_BG))
	add_child(_inv_panel)
	var _this_inv := _inv_panel
	_inv_panel.tree_exiting.connect(func():
		if _inv_panel == _this_inv:
			_inv_panel = null
			_inv_grid  = null
	, CONNECT_ONE_SHOT)
	if has_node("/root/UIManager"):
		UIManager.push_menu(_inv_panel)

	var title := _lbl("Inventario", Vector2(0, 2), _inv_panel, 8)
	title.size = Vector2(pw, TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sep := ColorRect.new()
	sep.position = Vector2(PAD, TITLE)
	sep.size     = Vector2(iw, 1)
	sep.color    = Color(0.4, 0.4, 0.5, 0.50)
	_inv_panel.add_child(sep)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = INV_COLS
	_inv_grid.add_theme_constant_override("h_separation", INV_GAP)
	_inv_grid.add_theme_constant_override("v_separation", INV_GAP)
	_inv_grid.position = Vector2(PAD, TITLE + 2)
	_inv_grid.size     = Vector2(iw, ih)
	_inv_panel.add_child(_inv_grid)

	var hint := _lbl("[I] Cerrar", Vector2(0, ph - CLOSE), _inv_panel, 7)
	hint.size = Vector2(pw, CLOSE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", C_MUTED)

	_fill_inv_grid()


func _fill_inv_grid() -> void:
	if _inv_grid == null:
		return
	for ch: Node in _inv_grid.get_children():
		_inv_grid.remove_child(ch)
		ch.queue_free()
	if _player == null:
		return

	for item_id: String in _player.inventory:
		var amt: int = _player.inventory[item_id]
		if amt <= 0:
			continue

		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(INV_S, INV_S)
		var is_equipped := (item_id == _equipped_weapon_id)
		slot.add_theme_stylebox_override("panel",
				_sb_slot_equipped() if is_equipped else _sb_slot())
		slot.tooltip_text = _item_name(item_id) + (" (equipado)" if is_equipped else "")
		_inv_grid.add_child(slot)

		if ResourceLoader.exists("res://resources/weapon_%s.tres" % item_id):
			slot.gui_input.connect(_on_inv_slot_input.bind(item_id))

		var icon_tex := _item_tex(item_id)
		if icon_tex != null:
			const ICON_S := 14
			const OFF    := (INV_S - ICON_S) / 2
			var icon := TextureRect.new()
			icon.position     = Vector2(OFF, OFF)
			icon.size         = Vector2(ICON_S, ICON_S)
			icon.texture      = icon_tex
			icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)

		var cnt := Label.new()
		cnt.text     = str(amt)
		cnt.position = Vector2(INV_S - 10, INV_S - 9)
		cnt.size     = Vector2(9, 8)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.add_theme_font_size_override("font_size", 6)
		cnt.add_theme_color_override("font_color",        C_TEXT)
		cnt.add_theme_color_override("font_shadow_color", C_SHADOW)
		cnt.add_theme_constant_override("shadow_offset_x", 1)
		cnt.add_theme_constant_override("shadow_offset_y", 1)
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cnt)


# ── Aviso / hint (encima de la barra rápida) ──────────────────────────────────

func _build_hint() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Fondo semitransparente para que el texto se lea sobre cualquier escenario
	var hint_bg := Panel.new()
	hint_bg.position = Vector2(roundf(vp.x * 0.5) - 90, vp.y - (HOTBAR_S + HOTBAR_PAD * 2 + 2) - 15)
	hint_bg.size     = Vector2(180, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.set_corner_radius_all(2)
	hint_bg.add_theme_stylebox_override("panel", sb)
	add_child(hint_bg)

	_hint_lbl = Label.new()
	_hint_lbl.position = Vector2(0, 1)
	_hint_lbl.size     = Vector2(180, 12)
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 8)
	_hint_lbl.add_theme_color_override("font_color",         Color(0.95, 0.95, 0.80, 1.0))
	_hint_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_hint_lbl.add_theme_constant_override("outline_size", 1)
	_hint_lbl.text = "[E] interactuar"
	hint_bg.add_child(_hint_lbl)


func show_notice(text: String) -> void:
	_notice_id += 1
	var this_id := _notice_id
	_hint_lbl.text = text
	if not is_inside_tree():
		return
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if _notice_id == this_id:
			_hint_lbl.text = "[E] interactuar"
	)


# ── Refresco ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _player == null:
		return
	_gold_lbl.text = str(_player.inventory.get("gold",   0))
	_arr_lbl.text  = str(_player.inventory.get("arrows", 0))
	_refresh_hotbar()
	_refresh_egg_hud()
	if _inv_grid != null:
		_fill_inv_grid()


func _refresh_hotbar() -> void:
	var keys: Array = _player.inventory.keys()
	for i: int in HOTBAR_N:
		if i < keys.size():
			var id: String = keys[i]
			var amt: int   = _player.inventory.get(id, 0)
			_hb_icons[i].texture = _item_tex(id)
			if id.begins_with("egg_") and has_node("/root/FamiliarSystem"):
				var kills: int = int(FamiliarSystem.egg_kills.get(id, 0))
				var needed: int = FamiliarSystem.KILLS_TO_HATCH
				_hb_counts[i].text = "%d/%d" % [kills, needed]
				_hb_counts[i].add_theme_color_override("font_color",
					Color(0.3, 1.0, 0.5) if kills >= needed else Color(0.9, 0.9, 0.5))
				var rar := FamiliarSystem.get_egg_rarity(id.substr(4))
				_hb_icons[i].modulate = _rarity_color(rar.get("rarity", "common"), rar.get("is_shiny", false))
			else:
				_hb_icons[i].modulate = Color.WHITE
				_hb_counts[i].text = str(amt) if amt > 1 else ""
				_hb_counts[i].add_theme_color_override("font_color", C_TEXT)
		else:
			_hb_icons[i].texture = null
			_hb_counts[i].text   = ""


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_toggle_inventory()
	elif event.is_action_pressed("companions"):
		get_viewport().set_input_as_handled()
		_toggle_comp_panel()


# ── Utilidades ────────────────────────────────────────────────────────────────

func _item_tex(id: String) -> Texture2D:
	if id.begins_with("egg_"):
		return load(ICON_EGG) as Texture2D
	if not _item_reg.has(id):
		return null
	var res: Resource = _item_reg[id]
	if res == null:
		return null
	return res.get("icon") as Texture2D


func _item_name(id: String) -> String:
	if _item_reg.has(id):
		var res: Resource = _item_reg[id]
		if res != null:
			var n = res.get("display_name")
			if n is String and not (n as String).is_empty():
				return n
	return id.capitalize()


func _sb(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	return s


func _sb_slot() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color          = C_SLOT
	s.border_color      = C_BORDER
	s.border_width_left  = 1; s.border_width_right  = 1
	s.border_width_top   = 1; s.border_width_bottom = 1
	return s


func _tex(parent: Control, path: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture     = load(path)
	tr.position    = pos
	tr.size        = sz
	tr.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(tr)
	return tr


func _get_fam_atlas(monster_id: String) -> AtlasTexture:
	var mon_path := "res://resources/monster_%s.tres" % monster_id
	if not ResourceLoader.exists(mon_path):
		return null
	var mon_data: Resource = load(mon_path)
	var spr_path: String   = str(mon_data.get("sprite_path"))
	if not ResourceLoader.exists(spr_path):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(spr_path)
	atlas.region = Rect2(0, 0, 16, 16)
	return atlas


func _open_rename_popup(monster_id: String) -> void:
	var vp  := get_viewport().get_visible_rect().size
	var pop := Panel.new()
	pop.position = Vector2(roundf((vp.x - 160.0) * 0.5), roundf((vp.y - 46.0) * 0.5))
	pop.size     = Vector2(160, 46)
	pop.add_theme_stylebox_override("panel", _sb(C_INV_BG))
	add_child(pop)

	_lbl("Nombre del familiar:", Vector2(5, 4), pop, 7)

	var le := LineEdit.new()
	le.position         = Vector2(5, 16)
	le.size             = Vector2(100, 14)
	le.text             = FamiliarSystem.get_fam_name(monster_id)
	le.placeholder_text = monster_id.capitalize()
	le.add_theme_font_size_override("font_size", 8)
	pop.add_child(le)
	le.grab_focus()

	var ok_btn := Button.new()
	ok_btn.text     = "OK"
	ok_btn.position = Vector2(108, 16)
	ok_btn.size     = Vector2(44, 14)
	ok_btn.add_theme_font_size_override("font_size", 7)
	var captured := monster_id
	ok_btn.pressed.connect(func() -> void:
		FamiliarSystem.set_fam_name(captured, le.text)
		pop.queue_free()
		_reopen_comp_panel()
	)
	pop.add_child(ok_btn)
	le.text_submitted.connect(func(t: String) -> void:
		FamiliarSystem.set_fam_name(captured, t)
		pop.queue_free()
		_reopen_comp_panel()
	)


# ── Panel de compañeros [C] ───────────────────────────────────────────────────

func _toggle_comp_panel() -> void:
	var was_open := _comp_panel != null
	if has_node("/root/UIManager"):
		UIManager.close_all()
	elif _comp_panel != null:
		_comp_panel.queue_free()
		_comp_panel = null
	if not was_open and _player != null:
		_open_comp_panel()


func _open_comp_panel() -> void:
	const PW := 178
	var vp := get_viewport().get_visible_rect().size

	# Calcula cuántas filas de huevos hay para ajustar altura
	var inv: Dictionary = _player.get("inventory") if _player != null else {}
	var egg_ids: Array[String] = []
	for k: String in inv.keys():
		if k.begins_with("egg_") and int(inv.get(k, 0)) > 0:
			egg_ids.append(k)

	# Altura dinámica según owned familiars y huevos
	var owned_count_pre: int = FamiliarSystem.get_owned_ids().size() if has_node("/root/FamiliarSystem") else 0
	var fam_section := 13 + maxi(1, owned_count_pre) * 32 + 6
	var ph := 14 + fam_section + 5 + 14 + maxi(1, egg_ids.size()) * 11 + 12
	ph = maxi(ph, 130)

	_comp_panel = Panel.new()
	_comp_panel.position = Vector2(roundf((vp.x - PW) * 0.5), roundf((vp.y - ph) * 0.5))
	_comp_panel.size     = Vector2(PW, ph)
	_comp_panel.add_theme_stylebox_override("panel", _sb(C_INV_BG))
	add_child(_comp_panel)
	var _this_comp := _comp_panel
	_comp_panel.tree_exiting.connect(func():
		if _comp_panel == _this_comp:
			_comp_panel = null
	, CONNECT_ONE_SHOT)
	if has_node("/root/UIManager"):
		UIManager.push_menu(_comp_panel)

	var title := _lbl("FAMILIARES", Vector2(0, 2), _comp_panel, 8)
	title.size = Vector2(PW, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hsep(_comp_panel, 12, PW)

	var sep_y1 := 12

	# ── Familiares ────────────────────────────────────────────────────────────
	var owned_ids: Array[String] = FamiliarSystem.get_owned_ids() if has_node("/root/FamiliarSystem") else []
	_lbl("FAMILIARES (%d/5)" % owned_ids.size(), Vector2(5, sep_y1 + 3), _comp_panel, 6).add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))

	var fam_rows := 0
	if owned_ids.is_empty():
		_lbl("ninguno — conseguí huevos de criaturas", Vector2(5, sep_y1 + 13), _comp_panel, 5).add_theme_color_override("font_color", C_MUTED)
		fam_rows = 1
	else:
		for fi: int in owned_ids.size():
			var mid: String = owned_ids[fi]
			var active: bool     = FamiliarSystem.is_summoned(mid) if has_node("/root/FamiliarSystem") else false
			var recovering: bool = FamiliarSystem.is_recovering(mid) if has_node("/root/FamiliarSystem") else false
			var card_y := sep_y1 + 13 + fi * 32

			var rar_data: Dictionary = FamiliarSystem.get_owned_rarity(mid) if has_node("/root/FamiliarSystem") else {"rarity": "common", "is_shiny": false}
			var rar_col := _rarity_color(rar_data.get("rarity", "common"), rar_data.get("is_shiny", false))

			# ─ Thumbnail ────────────────────────────────────────────────────────
			var thumb := TextureRect.new()
			thumb.position    = Vector2(5, card_y)
			thumb.size        = Vector2(12, 12)
			thumb.texture     = _get_fam_atlas(mid)
			thumb.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if recovering:   thumb.modulate = Color(0.9, 0.5, 0.2)
			elif not active: thumb.modulate = Color(0.5, 0.5, 0.5)
			_comp_panel.add_child(thumb)

			# ─ Fila 1: nombre, nivel, cariño, rename, acción ────────────────────
			var cname := FamiliarSystem.get_fam_name(mid)
			var dname := cname.left(8) if not cname.is_empty() else mid.capitalize()
			var nl := _lbl(dname, Vector2(19, card_y + 1), _comp_panel, 6)
			if recovering:   nl.add_theme_color_override("font_color", Color(0.9, 0.45, 0.15))
			elif active:     nl.add_theme_color_override("font_color", rar_col)
			else:            nl.add_theme_color_override("font_color", C_MUTED)

			var lv_lbl := _lbl("Nv.%d" % FamiliarSystem.get_fam_level(mid), Vector2(68, card_y + 1), _comp_panel, 5)
			lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

			var aff_lbl := _lbl("♥%d" % FamiliarSystem.get_affection(mid), Vector2(90, card_y + 1), _comp_panel, 5)
			aff_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.6))

			var ren_btn := Button.new()
			ren_btn.text     = "[R]"
			ren_btn.position = Vector2(108, card_y)
			ren_btn.size     = Vector2(14, 10)
			ren_btn.add_theme_font_size_override("font_size", 5)
			var cap_ren := mid
			ren_btn.pressed.connect(func() -> void: _open_rename_popup(cap_ren))
			_comp_panel.add_child(ren_btn)

			if recovering:
				var secs := FamiliarSystem.get_recovery_remaining(mid)
				_lbl("%.0fs" % secs, Vector2(124, card_y + 1), _comp_panel, 6).add_theme_color_override("font_color", Color(0.9, 0.45, 0.15))
			else:
				var act_btn := Button.new()
				act_btn.text     = "Guardar" if active else "Sacar"
				act_btn.position = Vector2(124, card_y)
				act_btn.size     = Vector2(48, 10)
				act_btn.add_theme_font_size_override("font_size", 5)
				var cap_mid    := mid
				var cap_active := active
				act_btn.pressed.connect(func() -> void:
					if cap_active: FamiliarSystem.dismiss(cap_mid)
					else:          FamiliarSystem.summon(cap_mid)
					_reopen_comp_panel()
				)
				_comp_panel.add_child(act_btn)

			# ─ Fila 2: HP y Daño ────────────────────────────────────────────────
			_lbl("HP", Vector2(19, card_y + 13), _comp_panel, 5).add_theme_color_override("font_color", C_MUTED)
			var hp_bg := ColorRect.new()
			hp_bg.position = Vector2(28, card_y + 15); hp_bg.size = Vector2(50, 3); hp_bg.color = Color(0.1, 0.1, 0.1)
			_comp_panel.add_child(hp_bg)
			var hp_fill2 := ColorRect.new()
			hp_fill2.position = Vector2(28, card_y + 15); hp_fill2.size = Vector2(0, 3)
			_comp_panel.add_child(hp_fill2)
			var fam_node := _get_active_fam_node(mid)
			if fam_node != null:
				var fhp: int  = int(fam_node.get("hp"))
				var fmax: int = int(fam_node.get("_max_hp"))
				var hr        := clampf(float(fhp) / float(maxi(1, fmax)), 0.0, 1.0)
				hp_fill2.size.x = 50.0 * hr
				hp_fill2.color  = Color(0.25, 0.85, 0.25) if hr > 0.5 else Color(0.9, 0.3, 0.1)
				_lbl("%d/%d" % [fhp, fmax], Vector2(80, card_y + 13), _comp_panel, 5).add_theme_color_override("font_color", C_MUTED)
				_lbl("D:%d" % int(fam_node.get("_damage")), Vector2(104, card_y + 13), _comp_panel, 5)
			else:
				_lbl("−/−", Vector2(80, card_y + 13), _comp_panel, 5).add_theme_color_override("font_color", C_MUTED)
			var rar_text := ""
			if rar_data.get("is_shiny", false): rar_text = "SHINY"
			else:
				match rar_data.get("rarity", "common"):
					"rare": rar_text = "RARO"
					"epic": rar_text = "ÉPICO"
			if not rar_text.is_empty():
				_lbl(rar_text, Vector2(132, card_y + 13), _comp_panel, 5).add_theme_color_override("font_color", rar_col)

			# ─ Fila 3: XP y Habilidad ────────────────────────────────────────────
			_lbl("XP", Vector2(19, card_y + 22), _comp_panel, 5).add_theme_color_override("font_color", C_MUTED)
			var xp_cur    := FamiliarSystem.get_fam_xp(mid)
			var xp_needed := FamiliarSystem.get_fam_xp_needed(mid)
			var xp_ratio  := clampf(float(xp_cur) / float(maxi(1, xp_needed)), 0.0, 1.0)
			var xp_bg := ColorRect.new()
			xp_bg.position = Vector2(28, card_y + 24); xp_bg.size = Vector2(50, 2); xp_bg.color = Color(0.1, 0.1, 0.1)
			_comp_panel.add_child(xp_bg)
			var xp_fill := ColorRect.new()
			xp_fill.position = Vector2(28, card_y + 24); xp_fill.size = Vector2(50.0 * xp_ratio, 2); xp_fill.color = Color(0.55, 0.35, 1.0)
			_comp_panel.add_child(xp_fill)
			var xp_lbl := _lbl("%d/%d" % [xp_cur, xp_needed], Vector2(80, card_y + 22), _comp_panel, 5)
			if FamiliarSystem.get_fam_level(mid) >= FamiliarSystem.FAM_MAX_LEVEL:
				xp_lbl.text = "MÁX"
			xp_lbl.add_theme_color_override("font_color", C_MUTED)
			var ability := FamiliarSystem.get_familiar_ability(mid)
			if not ability.is_empty():
				_lbl(ability, Vector2(104, card_y + 22), _comp_panel, 5).add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))

			if fi < owned_ids.size() - 1:
				_hsep(_comp_panel, card_y + 30, PW - 10)

		fam_rows = owned_ids.size()

	var sep_y2 := sep_y1 + 13 + maxi(1, fam_rows) * 32 + 2
	_hsep(_comp_panel, sep_y2, PW)

	# ── Huevos ────────────────────────────────────────────────────────────────
	_lbl("HUEVOS", Vector2(5, sep_y2 + 3), _comp_panel, 6).add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	if egg_ids.is_empty():
		_lbl("ninguno — derrotá criaturas para conseguirlos", Vector2(5, sep_y2 + 13), _comp_panel, 5).add_theme_color_override("font_color", C_MUTED)
	else:
		var needed: int = FamiliarSystem.KILLS_TO_HATCH if has_node("/root/FamiliarSystem") else 10
		for ei: int in egg_ids.size():
			var item_id: String = egg_ids[ei]
			var kills: int = int(FamiliarSystem.egg_kills.get(item_id, 0)) if has_node("/root/FamiliarSystem") else 0
			var ey := sep_y2 + 13 + ei * 11
			var ready := kills >= needed
			var name_lbl := _lbl(item_id.substr(4).capitalize(), Vector2(5, ey), _comp_panel, 6)
			if ready:
				name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			var bar_bg := ColorRect.new(); bar_bg.position = Vector2(50, ey + 1); bar_bg.size = Vector2(80, 5); bar_bg.color = Color(0.15, 0.15, 0.15); _comp_panel.add_child(bar_bg)
			var ratio := clampf(float(kills) / float(needed), 0.0, 1.0)
			var bar_fill := ColorRect.new(); bar_fill.position = Vector2(50, ey + 1); bar_fill.size = Vector2(80.0 * ratio, 5); bar_fill.color = Color(0.3, 1.0, 0.5) if ready else Color(0.9, 0.75, 0.1); _comp_panel.add_child(bar_fill)
			_lbl(("LISTO [F]!" if ready else "%d/10" % kills), Vector2(134, ey), _comp_panel, 6).add_theme_color_override("font_color", Color(0.3, 1.0, 0.5) if ready else C_MUTED)

	var hint_y := ph - 11
	_hsep(_comp_panel, hint_y - 3, PW)
	var hint := _lbl("[C] cerrar", Vector2(0, hint_y), _comp_panel, 6)
	hint.size = Vector2(PW, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", C_MUTED)


func _hsep(parent: Control, y: float, width: float) -> void:
	var sep := ColorRect.new()
	sep.position = Vector2(4, y)
	sep.size     = Vector2(width - 8, 1)
	sep.color    = Color(0.4, 0.4, 0.5, 0.45)
	parent.add_child(sep)


# ── Respuestas a CompanionSystem ──────────────────────────────────────────────

func _reopen_comp_panel() -> void:
	if _comp_panel == null:
		return
	var old: Panel = _comp_panel
	_comp_panel = null  # pre-null para que el lambda de tree_exiting no pise el nuevo panel
	old.queue_free()
	_open_comp_panel()


func _on_team_changed_hud() -> void:
	var data: Resource = CompanionSystem.get_active_data() if has_node("/root/CompanionSystem") else null
	if data != null and _comp_name_lbl != null:
		var raw: String = str(data.get("companion_name"))
		_comp_name_lbl.text = raw.substr(0, 6) if raw.length() > 6 else raw
	_reopen_comp_panel()


func _on_companion_unlocked_hud(_comp_data: Resource) -> void:
	_reopen_comp_panel()


func _on_essence_gained_hud(_id: String, _cur: int, _req: int) -> void:
	pass  # El progreso se ve al abrir el panel con C


func _on_egg_progress(_item_id: String, _kills: int, _needed: int) -> void:
	_refresh_hotbar()
	_refresh_egg_hud()


# ── Clic derecho en inventario ────────────────────────────────────────────────

func _on_inv_slot_input(ev: InputEvent, item_id: String) -> void:
	if ev is InputEventMouseButton \
			and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT \
			and (ev as InputEventMouseButton).pressed:
		if _player != null and _player.has_method("equip_item"):
			_player.call("equip_item", item_id)
		get_viewport().set_input_as_handled()


# ── Panel de habilidades del Guerrero ─────────────────────────────────────────

func _build_skill_bar(cd: Resource) -> void:
	if _skill_bar != null and is_instance_valid(_skill_bar):
		_skill_bar.queue_free()
	_skill_bar = null
	_skill_cd_lbls.clear()
	_skill_cd_fills.clear()
	var class_label := str(cd.get("class_label"))
	var skill_names: Array[String]
	match class_label:
		"Guerrero": skill_names = ["Torbellino", "Bloqueo",   "Carga"]
		"Mago":     skill_names = ["B. Fuego",   "Escudo",   "R. Hielo"]
		_:          return  # Otras clases sin barra de habilidades

	const SW: int = 82
	const SH: int = 57
	_skill_bar = Panel.new()
	_skill_bar.position = Vector2(97, 3)
	_skill_bar.size     = Vector2(SW, SH)
	_skill_bar.add_theme_stylebox_override("panel", _sb(C_BG))
	add_child(_skill_bar)

	var hdr := _lbl("HABILIDADES", Vector2(3, 2), _skill_bar, 5)
	hdr.add_theme_color_override("font_color", C_MUTED)

	var skill_keys := ["[1]", "[2]", "[3]"]

	for i: int in 3:
		var yb := 12 + i * 14
		var kl := _lbl(skill_keys[i], Vector2(2, yb), _skill_bar, 6)
		kl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
		_lbl(skill_names[i], Vector2(16, yb), _skill_bar, 6)

		var st_lbl := _lbl("LISTA", Vector2(55, yb), _skill_bar, 6)
		st_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
		_skill_cd_lbls.append(st_lbl)

		var bar_bg := ColorRect.new()
		bar_bg.position = Vector2(2, yb + 9)
		bar_bg.size     = Vector2(SW - 6, 3)
		bar_bg.color    = Color(0.15, 0.15, 0.20)
		_skill_bar.add_child(bar_bg)

		var bar_fill := ColorRect.new()
		bar_fill.position = Vector2(2, yb + 9)
		bar_fill.size     = Vector2(SW - 6, 3)
		bar_fill.color    = Color(0.2, 0.8, 0.35)
		_skill_bar.add_child(bar_fill)
		_skill_cd_fills.append(bar_fill)


func _on_class_changed(cd: Resource) -> void:
	_build_skill_bar(cd)
	var is_mage := str(cd.get("class_label")) == "Mago"
	if _mana_bg != null:
		_mana_bg.visible = is_mage
	if _mana_fill != null:
		_mana_fill.visible = is_mage
	if is_mage and _player != null:
		_update_mana(int(_player.get("mana")), int(_player.get("max_mana")))


func _on_weapon_changed(weapon_id: String) -> void:
	_equipped_weapon_id = weapon_id
	_update_weapon(weapon_id)
	if _inv_grid != null:
		_fill_inv_grid()


func _update_weapon(weapon_id: String) -> void:
	if _weapon_lbl == null:
		return
	if weapon_id.is_empty():
		_weapon_lbl.text = "Puños"
		_weapon_lbl.add_theme_color_override("font_color", C_MUTED)
	else:
		var path := "res://resources/weapon_%s.tres" % weapon_id
		if ResourceLoader.exists(path):
			var wd = load(path)
			_weapon_lbl.text = "%s  %d dmg" % [str(wd.get("display_name")), int(wd.get("damage"))]
		else:
			_weapon_lbl.text = weapon_id.capitalize()
		_weapon_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))


func _update_skill_cd(slot: int, remaining: float, max_cd: float) -> void:
	if slot < 0 or slot >= _skill_cd_fills.size():
		return
	if slot == 1 and max_cd <= 0.0:
		return  # bloqueo del Guerrero no tiene CD numérico
	var fill: ColorRect = _skill_cd_fills[slot]
	var lbl: Label      = _skill_cd_lbls[slot]
	const BW := 76.0
	if remaining <= 0.0 or max_cd <= 0.0:
		fill.size.x = BW
		fill.color  = Color(0.2, 0.8, 0.35)
		lbl.text    = "LISTA"
		lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
	else:
		var ratio := clampf(1.0 - remaining / max_cd, 0.0, 1.0)
		fill.size.x = BW * ratio
		fill.color  = Color(0.35, 0.55, 0.9)
		lbl.text    = "%.0fs" % remaining
		lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.88))


func _on_blocking_changed(active: bool) -> void:
	if _skill_cd_fills.size() < 2 or _skill_cd_lbls.size() < 2:
		return
	var fill: ColorRect = _skill_cd_fills[1]
	var lbl: Label      = _skill_cd_lbls[1]
	const BW := 76.0
	if active:
		fill.size.x = BW
		fill.color  = Color(0.2, 0.5, 1.0)
		lbl.text    = "ACTIVO"
		lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		fill.size.x = 0.0
		lbl.text    = "LISTA"
		lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))


func _sb_slot_equipped() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color          = Color(0.14, 0.11, 0.04, 0.90)
	s.border_color      = Color(1.0, 0.85, 0.2)
	s.border_width_left  = 1; s.border_width_right  = 1
	s.border_width_top   = 1; s.border_width_bottom = 1
	return s


func _lbl(text: String, pos: Vector2, parent: Control, fsize: int) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color",        C_TEXT)
	l.add_theme_color_override("font_shadow_color", C_SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l
