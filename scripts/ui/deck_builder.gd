class_name DeckBuilder
extends Control

const CARD_SLOT_SCALE: Vector2 = Vector2(0.76, 0.76)
const CARD_SLOT_SIZE: Vector2 = Vector2(154, 212)

var card_db: Dictionary = {}
var decks_data: Dictionary = {}
var current_deck_cards: Array[String] = []
var card_ui_prefab = preload("res://scenes/card_ui.tscn")

var selected_element: String = "all"
var selected_type: String = "all"
var selected_rarity: String = "all"
var selected_cost: String = "all"
var search_query: String = ""

@onready var deck_option: OptionButton = $TopBar/DeckOption
@onready var back_button: Button = $TopBar/BackButton
@onready var save_button: Button = $TopBar/SaveButton
@onready var deck_count_label: Label = $TopBar/CountLabel
@onready var deck_inline_count: Label = $DeckInlineCount
@onready var deck_scroll: ScrollContainer = $DeckScroll
@onready var deck_container: HBoxContainer = $DeckScroll/DeckContainer
@onready var deck_left_btn: Button = $DeckLeftBtn
@onready var deck_right_btn: Button = $DeckRightBtn

@onready var catalog_scroll: ScrollContainer = $CatalogScroll
@onready var catalog_container: GridContainer = $CatalogScroll/CatalogContainer

@onready var search_box: LineEdit = $FilterBar/SearchBox
@onready var elem_all_btn: Button = $FilterBar/ElemAllBtn
@onready var elem_fire_btn: Button = $FilterBar/ElemFireBtn
@onready var elem_lightning_btn: Button = $FilterBar/ElemLightningBtn
@onready var elem_wind_btn: Button = $FilterBar/ElemWindBtn
@onready var elem_ice_btn: Button = $FilterBar/ElemIceBtn
@onready var elem_shadow_btn: Button = $FilterBar/ElemShadowBtn
@onready var new_deck_button: Button = get_node_or_null("TopBar/NewDeckBtn")
@onready var delete_deck_button: Button = get_node_or_null("TopBar/DeleteDeckBtn")
@onready var elem_mech_btn: Button = $FilterBar/ElemMechBtn
@onready var elem_water_btn: Button = get_node_or_null("FilterBar/ElemWaterBtn")
@onready var type_option: OptionButton = $FilterBar/TypeOption
@onready var rarity_option: OptionButton = $FilterBar/RarityOption
@onready var cost_option: OptionButton = $FilterBar/CostOption

@onready var nav_deck_btn: Button = $BottomNav/NavDeckBtn
@onready var nav_collection_btn: Button = $BottomNav/NavCollectionBtn
@onready var nav_crafting_btn: Button = $BottomNav/NavCraftingBtn
@onready var nav_fusion_btn: Button = $BottomNav/NavFusionBtn

func _ready() -> void:
	card_db = CardData.load_database()
	load_decks_file()
	_apply_ornate_theme()
	
	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	deck_option.item_selected.connect(_on_deck_selected)
	if new_deck_button:
		new_deck_button.pressed.connect(_on_new_deck_pressed)
	if delete_deck_button:
		delete_deck_button.pressed.connect(_on_delete_deck_pressed)
	
	if deck_left_btn:
		deck_left_btn.pressed.connect(func(): _scroll_deck(-340))
	if deck_right_btn:
		deck_right_btn.pressed.connect(func(): _scroll_deck(340))
	
	_setup_filter_controls()
	_setup_bottom_nav()
	setup_deck_options()
	populate_catalog()
	load_selected_deck(0)

func _make_stylebox(bg: Color, border: Color, border_w: int = 2, radius: int = 6) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _apply_ornate_theme() -> void:
	var gold_normal = _make_stylebox(Color(0.08, 0.09, 0.16, 0.94), Color(0.78, 0.60, 0.24, 0.95), 2, 6)
	var gold_hover = _make_stylebox(Color(0.16, 0.14, 0.24, 0.98), Color(1.0, 0.84, 0.38, 1.0), 2, 6)
	var save_normal = _make_stylebox(Color(0.32, 0.20, 0.06, 0.96), Color(0.95, 0.76, 0.30, 1.0), 2, 6)
	var save_hover = _make_stylebox(Color(0.45, 0.28, 0.08, 0.98), Color(1.0, 0.90, 0.45, 1.0), 2, 6)
	
	for btn in [back_button, deck_option, new_deck_button, delete_deck_button]:
		if btn:
			btn.add_theme_stylebox_override("normal", gold_normal)
			btn.add_theme_stylebox_override("hover", gold_hover)
			btn.add_theme_stylebox_override("pressed", gold_hover)
			btn.add_theme_color_override("font_color", Color(0.96, 0.90, 0.74))
	
	if save_button:
		save_button.add_theme_stylebox_override("normal", save_normal)
		save_button.add_theme_stylebox_override("hover", save_hover)
		save_button.add_theme_stylebox_override("pressed", save_hover)
		save_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))

	var filter_sb = _make_stylebox(Color(0.07, 0.08, 0.14, 0.95), Color(0.46, 0.38, 0.22, 0.90), 1, 5)
	var filter_active_sb = _make_stylebox(Color(0.30, 0.20, 0.06, 0.98), Color(0.98, 0.78, 0.28, 1.0), 2, 5)
	if search_box:
		search_box.add_theme_stylebox_override("normal", filter_sb)
		search_box.add_theme_stylebox_override("focus", filter_active_sb)
	for opt in [type_option, rarity_option, cost_option]:
		if opt:
			opt.add_theme_stylebox_override("normal", filter_sb)
			opt.add_theme_stylebox_override("hover", filter_active_sb)

func _setup_filter_controls() -> void:
	var elem_buttons = {
		"all": [elem_all_btn, ""],
		"fire": [elem_fire_btn, "res://assets/icons/fire.png"],
		"lightning": [elem_lightning_btn, "res://assets/icons/lightning.png"],
		"wind": [elem_wind_btn, "res://assets/icons/wind.png"],
		"ice": [elem_ice_btn, "res://assets/icons/ice.png"],
		"shadow": [elem_shadow_btn, "res://assets/icons/shadow.png"],
		"mechanical": [elem_mech_btn, "res://assets/icons/mechanical.png"],
		"water": [elem_water_btn, "res://assets/icons/water.png"]
	}
	for elem_key in elem_buttons.keys():
		var btn: Button = elem_buttons[elem_key][0]
		var icon_path: String = elem_buttons[elem_key][1]
		if not btn:
			continue
		if icon_path != "" and ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var k = elem_key
		btn.pressed.connect(func():
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			selected_element = k
			_refresh_element_filter_styles()
			populate_catalog()
		)
	_refresh_element_filter_styles()

	if search_box:
		search_box.text_changed.connect(func(new_text: String):
			search_query = new_text.strip_edges().to_lower()
			populate_catalog()
		)

	if type_option:
		type_option.clear()
		type_option.add_item("Type ▾")
		type_option.add_item("Beasts")
		type_option.add_item("Fusions")
		type_option.add_item("Spells")
		type_option.add_item("Supports")
		type_option.add_item("Stones")
		type_option.add_item("Relics")
		type_option.add_item("Rifts")
		type_option.item_selected.connect(func(idx: int):
			var map = ["all", "beast", "fusion", "spell", "support", "stone", "relic", "rift"]
			selected_type = map[idx] if idx < map.size() else "all"
			populate_catalog()
		)

	if rarity_option:
		rarity_option.clear()
		rarity_option.add_item("Rarity ▾")
		rarity_option.add_item("Confirmed")
		rarity_option.add_item("Mythic")
		rarity_option.add_item("Epic")
		rarity_option.add_item("Common")
		rarity_option.item_selected.connect(func(idx: int):
			var map = ["all", "confirmed", "mythic", "epic", "common"]
			selected_rarity = map[idx] if idx < map.size() else "all"
			populate_catalog()
		)

	if cost_option:
		cost_option.clear()
		cost_option.add_item("Cost ▾")
		cost_option.add_item("0 Mana")
		cost_option.add_item("1 Mana")
		cost_option.add_item("2 Mana")
		cost_option.add_item("3+ Mana")
		cost_option.item_selected.connect(func(idx: int):
			var map = ["all", "0", "1", "2", "3+"]
			selected_cost = map[idx] if idx < map.size() else "all"
			populate_catalog()
		)

func _refresh_element_filter_styles() -> void:
	var inactive_sb = _make_stylebox(Color(0.08, 0.09, 0.16, 0.92), Color(0.42, 0.35, 0.22, 0.85), 1, 5)
	var active_sb = _make_stylebox(Color(0.36, 0.24, 0.06, 0.98), Color(1.0, 0.82, 0.30, 1.0), 2, 5)
	var map = {
		"all": elem_all_btn,
		"fire": elem_fire_btn,
		"lightning": elem_lightning_btn,
		"wind": elem_wind_btn,
		"ice": elem_ice_btn,
		"shadow": elem_shadow_btn,
		"mechanical": elem_mech_btn,
		"water": elem_water_btn
	}
	for k in map.keys():
		var btn: Button = map[k]
		if not btn:
			continue
		var sb = active_sb if selected_element == k else inactive_sb
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", active_sb)
		btn.add_theme_stylebox_override("pressed", active_sb)

func _setup_bottom_nav() -> void:
	var active_tab = _make_stylebox(Color(0.28, 0.18, 0.05, 0.96), Color(1.0, 0.80, 0.28, 1.0), 2, 7)
	var inactive_tab = _make_stylebox(Color(0.07, 0.08, 0.14, 0.92), Color(0.40, 0.34, 0.22, 0.85), 1, 7)
	if nav_deck_btn:
		nav_deck_btn.add_theme_stylebox_override("normal", active_tab)
		nav_deck_btn.add_theme_stylebox_override("hover", active_tab)
		nav_deck_btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58))
	for btn in [nav_collection_btn, nav_crafting_btn, nav_fusion_btn]:
		if btn:
			btn.add_theme_stylebox_override("normal", inactive_tab)
			btn.add_theme_stylebox_override("hover", active_tab)
			btn.add_theme_color_override("font_color", Color(0.84, 0.80, 0.72))

	if nav_collection_btn:
		nav_collection_btn.pressed.connect(func():
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			get_tree().change_scene_to_file("res://scenes/card_collection.tscn")
		)
	if nav_crafting_btn:
		nav_crafting_btn.pressed.connect(func():
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			get_tree().change_scene_to_file("res://scenes/pack_opening.tscn")
		)
	if nav_fusion_btn:
		nav_fusion_btn.pressed.connect(func():
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			selected_type = "fusion"
			if type_option:
				type_option.select(2)
			populate_catalog()
		)

func _scroll_deck(delta: int) -> void:
	if deck_scroll:
		deck_scroll.scroll_horizontal = clampi(deck_scroll.scroll_horizontal + delta, 0, 10000)

func load_decks_file() -> void:
	var path = "res://data/default_decks.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var text = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(text) == OK:
			decks_data = json.get_data()
	if not decks_data.has("decks"):
		decks_data["decks"] = []

	var user_path = "user://custom_decks.json"
	if FileAccess.file_exists(user_path):
		var u_file = FileAccess.open(user_path, FileAccess.READ)
		var u_text = u_file.get_as_text()
		u_file.close()
		var u_json = JSON.new()
		if u_json.parse(u_text) == OK:
			var custom_list = u_json.get_data().get("decks", [])
			for d in custom_list:
				decks_data["decks"].append(d)

func save_custom_decks_file() -> void:
	var custom_list: Array = []
	for d in decks_data.get("decks", []):
		if d.get("is_custom", false) == true:
			custom_list.append(d)
	var f = FileAccess.open("user://custom_decks.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"decks": custom_list}, "\t"))
		f.close()

func _on_new_deck_pressed() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	var custom_idx = 1
	for d in decks_data.get("decks", []):
		if str(d.get("name", "")).begins_with("Custom Deck"):
			custom_idx += 1
	var new_deck = {
		"name": "Custom Deck " + str(custom_idx),
		"element": "neutral",
		"is_custom": true,
		"cards": current_deck_cards.duplicate()
	}
	decks_data["decks"].append(new_deck)
	save_custom_decks_file()
	setup_deck_options()
	deck_option.select(decks_data["decks"].size() - 1)
	load_selected_deck(decks_data["decks"].size() - 1)
	deck_count_label.text = "✦ CREATED " + new_deck["name"] + " ✦"

func _on_delete_deck_pressed() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	var idx = deck_option.selected
	if idx >= 0 and idx < decks_data.get("decks", []).size():
		if decks_data["decks"].size() > 1:
			decks_data["decks"].remove_at(idx)
			save_custom_decks_file()
			setup_deck_options()
			var next_idx = mini(idx, decks_data["decks"].size() - 1)
			deck_option.select(next_idx)
			load_selected_deck(next_idx)
			deck_count_label.text = "DECK DELETED"

func setup_deck_options() -> void:
	deck_option.clear()
	if decks_data.has("decks"):
		for d in decks_data["decks"]:
			var prefix = "✎ " if d.get("is_custom", false) else "✦ "
			deck_option.add_item(prefix + str(d.get("name", "Custom Deck")))

func _on_deck_selected(idx: int) -> void:
	load_selected_deck(idx)

func load_selected_deck(idx: int) -> void:
	current_deck_cards.clear()
	if decks_data.has("decks") and idx < decks_data["decks"].size():
		var d = decks_data["decks"][idx]
		for cid in d.get("cards", []):
			current_deck_cards.append(str(cid))
	refresh_deck_view()

func _create_scaled_card_slot(card: CardData, on_click: Callable) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = CARD_SLOT_SIZE
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_ui: CardUI = card_ui_prefab.instantiate()
	card_ui.base_scale = CARD_SLOT_SCALE
	wrapper.add_child(card_ui)
	card_ui.setup(card)
	card_ui.pivot_offset = Vector2.ZERO
	card_ui.scale = CARD_SLOT_SCALE
	card_ui.position = Vector2(1, 1)
	card_ui.card_clicked.connect(on_click)
	return wrapper

func refresh_deck_view() -> void:
	for child in deck_container.get_children():
		child.queue_free()
		
	var count_num = current_deck_cards.size()
	deck_count_label.text = "❖ DECK: " + str(count_num) + " CARDS"
	if deck_inline_count:
		deck_inline_count.text = str(count_num) + " / " + str(RulesConfig.STANDARD_DECK_SIZE)
		deck_inline_count.modulate = Color(0.35, 0.98, 0.48) if count_num == RulesConfig.STANDARD_DECK_SIZE else Color(1.0, 0.78, 0.30)
	
	for i in range(current_deck_cards.size()):
		var cid = current_deck_cards[i]
		if card_db.has(cid):
			var rem_idx = i
			var slot = _create_scaled_card_slot(card_db[cid], func(_c): remove_card_from_deck(rem_idx))
			deck_container.add_child(slot)

func _matches_catalog_filters(card: CardData) -> bool:
	if selected_element != "all":
		if card.element != selected_element and not card.element.contains(selected_element):
			return false
	if selected_type != "all":
		match selected_type:
			"beast":
				if card.card_type != "beast" or card.sub_type == "fusion_dragon":
					return false
			"fusion":
				if card.sub_type != "fusion_dragon":
					return false
			"realm":
				if card.card_type != "realm":
					return false
			"spell":
				if card.card_type != "spell":
					return false
			"support":
				if card.card_type != "support":
					return false
			"stone":
				if card.card_type != "stone":
					return false
			"relic":
				if card.card_type != "relic":
					return false
			"rift":
				if card.card_type != "rift":
					return false
	if selected_rarity != "all":
		match selected_rarity:
			"confirmed":
				if card.status != "CONFIRMED":
					return false
			"mythic":
				if card.sub_type != "god_dragon":
					return false
			"epic":
				if card.sub_type != "fusion_dragon" and card.sub_type != "elemental_dragon":
					return false
			"common":
				if card.card_type != "stone" and card.sub_type != "base_dragon":
					return false
	if selected_cost != "all":
		match selected_cost:
			"0":
				if card.mana_cost != 0:
					return false
			"1":
				if card.mana_cost != 1:
					return false
			"2":
				if card.mana_cost != 2:
					return false
			"3+":
				if card.mana_cost < 3:
					return false
	if search_query != "":
		var haystack = (card.name + " " + card.element + " " + card.sub_type + " " + card.description).to_lower()
		if not haystack.contains(search_query):
			return false
	return true

func populate_catalog() -> void:
	for child in catalog_container.get_children():
		child.queue_free()
	
	# Order catalog so iconic dragons appear first just like the reference screenshot
	var priority_ids = [
		"little_dragon", "shadow_dragon", "wind_dragon", "fire_dragon", "lightning_dragon", "ice_dragon",
		"mechanical_dragon", "volcovolt_dragon", "spark_wraith_dragon", "techno_frost_dragon", "god_dragon"
	]
	var ordered_cards: Array[CardData] = []
	var seen: Dictionary = {}
	for pid in priority_ids:
		if card_db.has(pid):
			ordered_cards.append(card_db[pid])
			seen[pid] = true
	for c in card_db.values():
		if not seen.has(c.id):
			ordered_cards.append(c)
		
	for card in ordered_cards:
		if not _matches_catalog_filters(card):
			continue
		var slot = _create_scaled_card_slot(card, func(c): add_card_to_deck(c.card_data.id))
		catalog_container.add_child(slot)

func add_card_to_deck(cid: String) -> void:
	if current_deck_cards.size() >= RulesConfig.STANDARD_DECK_SIZE:
		return
	var count = current_deck_cards.count(cid)
	if cid == "god_dragon" and count >= RulesConfig.GOD_DRAGON_MAX_PER_DECK:
		return
	if not cid.ends_with("_stone") and count >= RulesConfig.MAX_COPIES_PER_CARD:
		return
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_card_click()
	current_deck_cards.append(cid)
	refresh_deck_view()

func remove_card_from_deck(idx: int) -> void:
	if idx >= 0 and idx < current_deck_cards.size():
		if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_card_click()
		current_deck_cards.remove_at(idx)
		refresh_deck_view()

func _on_save_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	var idx = deck_option.selected
	if idx >= 0 and idx < decks_data.get("decks", []).size():
		decks_data["decks"][idx]["cards"] = current_deck_cards.duplicate()
		decks_data["decks"][idx]["is_custom"] = true
		save_custom_decks_file()
	var val = RulesConfig.validate_deck(current_deck_cards)
	if val.valid:
		deck_count_label.text = "SAVED! (40/40 VALID)"
	else:
		deck_count_label.text = val.error

func _on_back_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
