class_name CardCollection
extends Control

var card_db: Dictionary = {}
var card_ui_prefab = preload("res://scenes/card_ui.tscn")
var current_filter: String = "all"
var current_element_filter: String = "all"
var current_type_filter: String = "all"
var current_rarity_filter: String = "all"
var current_set_filter: String = "all"
var current_nav_tab: String = "Card Archive"
var search_query: String = ""
var use_legacy: bool = false

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var open_packs_button: Button = $TopBar/OpenPacksButton
@onready var filter_option: OptionButton = $TopBar/FilterOption
@onready var legacy_toggle: CheckButton = $TopBar/LegacyToggle
@onready var back_button: Button = $TopBar/BackButton

@onready var preview_panel: Panel = $PreviewPanel
@onready var preview_card_container: Control = $PreviewPanel/CardHolder
@onready var preview_name: Label = $PreviewPanel/InfoBox/Name
@onready var preview_type: Label = $PreviewPanel/InfoBox/Type
@onready var preview_stats: Label = $PreviewPanel/InfoBox/Stats
@onready var preview_ability: RichTextLabel = $PreviewPanel/InfoBox/AbilityText
@onready var preview_fidelity: Label = $PreviewPanel/InfoBox/Fidelity

var count_title_label: Label = null
var search_input: LineEdit = null
var element_filter_btns: Dictionary = {}
var nav_tab_btns: Dictionary = {}
var type_dropdown: OptionButton = null
var rarity_dropdown: OptionButton = null
var set_dropdown: OptionButton = null

func _ready() -> void:
	card_db = CardData.load_database()
	_build_reference_archive_layout()

	back_button.pressed.connect(_on_back_pressed)
	if open_packs_button:
		open_packs_button.pressed.connect(_on_open_packs_pressed)
	legacy_toggle.toggled.connect(_on_legacy_toggled)
	filter_option.item_selected.connect(_on_filter_selected)

	setup_filter_options()
	populate_cards()

func _make_stylebox(bg: Color, border: Color, border_w: int = 2, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

func _build_reference_archive_layout() -> void:
	# 1. Fantasy background art (matching Deck Builder & Main Menu Dragon Portal theme)
	var bg_node = get_node_or_null("Background")
	if bg_node and bg_node is ColorRect:
		bg_node.color = Color(0.03, 0.03, 0.08, 1.0)
	if not has_node("ArtBackground"):
		var art_bg := TextureRect.new()
		art_bg.name = "ArtBackground"
		art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists("res://assets/art/deck_builder_bg.jpg"):
			art_bg.texture = load("res://assets/art/deck_builder_bg.jpg")
		elif ResourceLoader.exists("res://assets/art/main_menu_bg.jpg"):
			art_bg.texture = load("res://assets/art/main_menu_bg.jpg")
		art_bg.modulate = Color(0.55, 0.55, 0.72, 1.0)
		add_child(art_bg)
		move_child(art_bg, 1)

	# 2. Style Top Header Bar to match reference screenshot
	var top_bar: HBoxContainer = $TopBar
	top_bar.offset_left = 18.0
	top_bar.offset_top = 10.0
	top_bar.offset_right = -18.0
	top_bar.offset_bottom = 52.0

	var back_sb := _make_stylebox(Color(0.08, 0.08, 0.16, 0.95), Color(0.88, 0.68, 0.25, 1.0), 2, 18)
	back_sb.content_margin_left = 16; back_sb.content_margin_right = 16
	back_button.add_theme_stylebox_override("normal", back_sb)
	back_button.add_theme_stylebox_override("hover", back_sb)
	back_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))

	var title_lbl: Label = $TopBar/Title
	title_lbl.text = "🗂️  CARD ARCHIVE & CODEX"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))

	# Center Emblem Banner ("ELEMENTAL BEASTS TCG — LEGACY REBORN")
	if not has_node("HeaderLogo"):
		var logo_tex := TextureRect.new()
		logo_tex.name = "HeaderLogo"
		logo_tex.position = Vector2(490, 0)
		logo_tex.size = Vector2(300, 62)
		logo_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists("res://assets/art/logo.png"):
			logo_tex.texture = load("res://assets/art/logo.png")
		add_child(logo_tex)

	var pack_sb := _make_stylebox(Color(0.45, 0.18, 0.06, 0.96), Color(1.0, 0.78, 0.25, 1.0), 2, 8)
	pack_sb.content_margin_left = 14; pack_sb.content_margin_right = 14
	open_packs_button.add_theme_stylebox_override("normal", pack_sb)
	open_packs_button.add_theme_stylebox_override("hover", pack_sb)
	open_packs_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))

	# 3. Left Sidebar Navigation Panel (Collection, Deck Builder, Card Archive, Codex, Fusions, Sets, Achievements, Settings)
	if not has_node("LeftSidebar"):
		var sidebar := PanelContainer.new()
		sidebar.name = "LeftSidebar"
		sidebar.position = Vector2(12, 62)
		sidebar.size = Vector2(148, 644)
		var side_sb := _make_stylebox(Color(0.05, 0.06, 0.13, 0.92), Color(0.75, 0.58, 0.22, 0.85), 2, 10)
		side_sb.content_margin_left = 8; side_sb.content_margin_right = 8
		side_sb.content_margin_top = 12; side_sb.content_margin_bottom = 12
		sidebar.add_theme_stylebox_override("panel", side_sb)
		add_child(sidebar)

		var side_vbox := VBoxContainer.new()
		side_vbox.add_theme_constant_override("separation", 8)
		sidebar.add_child(side_vbox)

		var nav_items := [
			["🃏  Collection", "Collection"],
			["⚔️  Deck Builder", "Deck Builder"],
			["🗂️  Card Archive", "Card Archive"],
			["📘  Codex", "Codex"],
			["🧬  Fusions", "Fusions"],
			["🏛️  Realms & Sets", "Sets"],
			["🏆  Achievements", "Achievements"],
			["⚙️  Settings", "Settings"]
		]
		for item in nav_items:
			var n_btn := Button.new()
			n_btn.text = item[0]
			n_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			n_btn.custom_minimum_size = Vector2(130, 38)
			n_btn.add_theme_font_size_override("font_size", 12)
			var tab_key: String = item[1]
			nav_tab_btns[tab_key] = n_btn
			n_btn.pressed.connect(func():
				_on_sidebar_nav_pressed(tab_key)
			)
			side_vbox.add_child(n_btn)
		_refresh_sidebar_styles()

	# 4. Main Center Archive Frame & Filter Bar (All Cards count, Search input, All + 6 Element icons, Type, Rarity, Set)
	if not has_node("CenterArchiveFrame"):
		var frame := Panel.new()
		frame.name = "CenterArchiveFrame"
		frame.position = Vector2(168, 62)
		frame.size = Vector2(732, 644)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var f_sb := _make_stylebox(Color(0.05, 0.06, 0.12, 0.90), Color(0.88, 0.68, 0.26, 0.95), 2, 10)
		frame.add_theme_stylebox_override("panel", f_sb)
		add_child(frame)
		move_child(frame, get_children().find(scroll_container))

	if not has_node("FilterToolbar"):
		var f_bar := HBoxContainer.new()
		f_bar.name = "FilterToolbar"
		f_bar.position = Vector2(180, 72)
		f_bar.size = Vector2(708, 34)
		f_bar.add_theme_constant_override("separation", 6)
		add_child(f_bar)

		count_title_label = Label.new()
		count_title_label.text = "All Cards (65)"
		count_title_label.add_theme_font_size_override("font_size", 14)
		count_title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
		count_title_label.custom_minimum_size = Vector2(110, 0)
		f_bar.add_child(count_title_label)

		search_input = LineEdit.new()
		search_input.placeholder_text = "⌕ Search cards, abilities, or types..."
		search_input.custom_minimum_size = Vector2(185, 30)
		search_input.clear_button_enabled = true
		search_input.add_theme_font_size_override("font_size", 11)
		search_input.text_changed.connect(func(txt: String):
			search_query = txt.strip_edges().to_lower()
			populate_cards()
		)
		f_bar.add_child(search_input)

		# "All" + 6 Element Icon Filter Buttons
		var all_el_btn := Button.new()
		all_el_btn.text = "All"
		all_el_btn.custom_minimum_size = Vector2(36, 30)
		all_el_btn.add_theme_font_size_override("font_size", 11)
		element_filter_btns["all"] = all_el_btn
		all_el_btn.pressed.connect(func():
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			current_element_filter = "all"
			_refresh_element_filter_styles()
			populate_cards()
		)
		f_bar.add_child(all_el_btn)

		for el in ["fire", "lightning", "wind", "ice", "shadow", "mechanical", "water"]:
			var el_str: String = str(el)
			var e_btn := Button.new()
			e_btn.custom_minimum_size = Vector2(30, 30)
			e_btn.tooltip_text = el_str.capitalize()
			var ic_path: String = "res://assets/icons/" + el_str + ".png"
			if ResourceLoader.exists(ic_path):
				e_btn.icon = load(ic_path)
				e_btn.expand_icon = true
			else:
				e_btn.text = el_str.substr(0, 1).to_upper()
			var el_cap: String = el_str
			element_filter_btns[el_cap] = e_btn
			e_btn.pressed.connect(func():
				if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
				current_element_filter = el_cap if current_element_filter != el_cap else "all"
				_refresh_element_filter_styles()
				populate_cards()
			)
			f_bar.add_child(e_btn)
		_refresh_element_filter_styles()

		type_dropdown = OptionButton.new()
		type_dropdown.custom_minimum_size = Vector2(78, 30)
		type_dropdown.add_theme_font_size_override("font_size", 11)
		type_dropdown.add_item("Type ▾")
		type_dropdown.add_item("Dragons")
		type_dropdown.add_item("Fusions")
		type_dropdown.add_item("Realms")
		type_dropdown.add_item("Spells")
		type_dropdown.add_item("Support")
		type_dropdown.add_item("Stones")
		type_dropdown.add_item("Relics")
		type_dropdown.add_item("Rifts")
		type_dropdown.item_selected.connect(func(idx: int):
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			var map_t := ["all", "beast", "fusion", "realm", "spell", "support", "stone", "relic", "rift"]
			current_type_filter = map_t[clampi(idx, 0, map_t.size() - 1)]
			populate_cards()
		)
		f_bar.add_child(type_dropdown)

		set_dropdown = OptionButton.new()
		set_dropdown.custom_minimum_size = Vector2(78, 30)
		set_dropdown.add_theme_font_size_override("font_size", 11)
		set_dropdown.add_item("Set ▾")
		set_dropdown.add_item("All Sets")
		set_dropdown.add_item("Set 1: Primal")
		set_dropdown.add_item("Set 2: Tides")
		set_dropdown.item_selected.connect(func(idx: int):
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			var map_s := ["all", "all", "set_1", "set_2"]
			current_set_filter = map_s[clampi(idx, 0, map_s.size() - 1)]
			populate_cards()
		)
		f_bar.add_child(set_dropdown)

		rarity_dropdown = OptionButton.new()
		rarity_dropdown.custom_minimum_size = Vector2(82, 30)
		rarity_dropdown.add_theme_font_size_override("font_size", 11)
		rarity_dropdown.add_item("Rarity ▾")
		rarity_dropdown.add_item("Base / Common")
		rarity_dropdown.add_item("Stage 1 / Rare")
		rarity_dropdown.add_item("Apex / Mythic")
		rarity_dropdown.item_selected.connect(func(idx: int):
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			var map_r := ["all", "common", "rare", "mythic"]
			current_rarity_filter = map_r[clampi(idx, 0, map_r.size() - 1)]
			populate_cards()
		)
		f_bar.add_child(rarity_dropdown)

	# Reposition ScrollContainer & GridContainer inside CenterArchiveFrame (4 columns of scaled cards)
	scroll_container.offset_left = 178.0
	scroll_container.offset_top = 114.0
	scroll_container.offset_right = -388.0
	scroll_container.offset_bottom = -22.0
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_container.columns = 4
	grid_container.add_theme_constant_override("h_separation", 12)
	grid_container.add_theme_constant_override("v_separation", 12)

	# 5. Style Right Preview Panel to match reference screenshot
	preview_panel.offset_left = -372.0
	preview_panel.offset_top = 62.0
	preview_panel.offset_right = -12.0
	preview_panel.offset_bottom = -14.0
	var prev_sb := _make_stylebox(Color(0.05, 0.06, 0.14, 0.94), Color(0.92, 0.72, 0.28, 1.0), 2, 10)
	preview_panel.add_theme_stylebox_override("panel", prev_sb)

	preview_card_container.offset_left = -115.0
	preview_card_container.offset_top = 16.0
	preview_card_container.offset_right = 115.0
	preview_card_container.offset_bottom = 335.0

	var info_box: VBoxContainer = $PreviewPanel/InfoBox
	info_box.offset_left = 18.0
	info_box.offset_top = -288.0
	info_box.offset_right = -18.0
	info_box.offset_bottom = -14.0
	preview_name.add_theme_font_size_override("font_size", 22)
	preview_type.add_theme_font_size_override("font_size", 12)
	preview_stats.add_theme_font_size_override("font_size", 14)
	preview_ability.add_theme_font_size_override("normal_font_size", 12)
	preview_ability.add_theme_font_size_override("bold_font_size", 15)

func _refresh_sidebar_styles() -> void:
	for k in nav_tab_btns.keys():
		var btn: Button = nav_tab_btns[k]
		var active: bool = (k == current_nav_tab)
		var sb := _make_stylebox(
			Color(0.38, 0.22, 0.05, 0.96) if active else Color(0.08, 0.09, 0.18, 0.88),
			Color(1.0, 0.82, 0.28, 1.0) if active else Color(0.32, 0.36, 0.52, 0.65),
			2 if active else 1,
			8
		)
		sb.content_margin_left = 10
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72) if active else Color(0.82, 0.86, 0.96))

func _refresh_element_filter_styles() -> void:
	for k in element_filter_btns.keys():
		var btn: Button = element_filter_btns[k]
		var active: bool = (k == current_element_filter)
		var sb := _make_stylebox(
			Color(0.45, 0.25, 0.06, 0.96) if active else Color(0.09, 0.10, 0.20, 0.90),
			Color(1.0, 0.84, 0.30, 1.0) if active else Color(0.38, 0.42, 0.58, 0.75),
			2 if active else 1,
			6
		)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)

func _on_sidebar_nav_pressed(tab_key: String) -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	if tab_key == "Deck Builder":
		get_tree().change_scene_to_file("res://scenes/deck_builder.tscn")
		return
	if tab_key == "Settings":
		if has_node("/root/SoundManager") and get_node("/root/SoundManager").has_method("show_audio_settings_modal"):
			get_node("/root/SoundManager").show_audio_settings_modal(self)
		return
	current_nav_tab = tab_key
	_refresh_sidebar_styles()
	match tab_key:
		"Collection", "Card Archive", "Achievements":
			current_filter = "All Cards"
			current_type_filter = "all"
		"Codex":
			current_filter = "Confirmed 2024 Originals"
		"Fusions":
			current_filter = "Fusion Dragons"
		"Sets":
			current_filter = "Elemental Realms"
	populate_cards()

func setup_filter_options() -> void:
	filter_option.clear()
	filter_option.add_item("All Cards")
	filter_option.add_item("Confirmed 2024 Originals")
	filter_option.add_item("Elemental Dragons")
	filter_option.add_item("Fusion & Ascended Dragons")
	filter_option.add_item("Elemental Realms")
	filter_option.add_item("Spell & Support Cards")
	filter_option.add_item("Element Stones")

func populate_cards() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	var cards_list = card_db.values()
	var first_card: CardData = null
	var shown_count: int = 0

	for card in cards_list:
		if not matches_filter(card):
			continue
		shown_count += 1
		if not first_card:
			first_card = card

		var slot := Control.new()
		slot.custom_minimum_size = Vector2(160, 224)
		var card_ui: CardUI = card_ui_prefab.instantiate()
		card_ui.base_scale = Vector2(0.80, 0.80)
		slot.add_child(card_ui)
		card_ui.setup(card, use_legacy)
		card_ui.pivot_offset = Vector2.ZERO
		card_ui.scale = Vector2(0.80, 0.80)
		card_ui.position = Vector2(0, 0)
		card_ui.card_clicked.connect(func(c): show_card_preview(c.card_data))
		grid_container.add_child(slot)

	if count_title_label:
		var pct = int(float(shown_count) / float(maxi(1, card_db.size())) * 100.0)
		count_title_label.text = "✦ CODEX: " + str(shown_count) + " / " + str(card_db.size()) + " CARDS (" + str(pct) + "%) ✦"

	if first_card:
		show_card_preview(first_card)

func matches_filter(card: CardData) -> bool:
	if search_query != "":
		var ab_name := str(card.ability.get("name", "")).to_lower() if card.ability else ""
		var ab_desc := str(card.ability.get("description", "")).to_lower() if card.ability else ""
		var hay := (card.name + " " + card.element + " " + card.card_type + " " + card.sub_type + " " + ab_name + " " + ab_desc + " " + card.description).to_lower()
		if not hay.contains(search_query):
			return false

	if current_set_filter != "all":
		if current_set_filter == "set_1":
			if card.set_id != "set_1" and card.set_id != "set_1_and_2":
				return false
		elif current_set_filter == "set_2":
			if card.set_id != "set_2" and card.set_id != "set_1_and_2" and card.element != "water" and not (card.card_type in ["relic", "rift"]):
				return false

	if current_element_filter != "all" and card.element.to_lower() != current_element_filter and not card.element.contains(current_element_filter):
		return false

	if current_type_filter != "all":
		match current_type_filter:
			"beast":
				if card.card_type != "beast": return false
			"fusion":
				if card.sub_type != "fusion_dragon" and card.sub_type != "ascended_dragon": return false
			"realm":
				if card.card_type != "realm": return false
			"spell":
				if card.card_type != "spell": return false
			"support":
				if card.card_type != "support": return false
			"stone":
				if card.card_type != "stone": return false
			"relic":
				if card.card_type != "relic": return false
			"rift":
				if card.card_type != "rift": return false

	if current_rarity_filter != "all":
		match current_rarity_filter:
			"common":
				if card.sub_type != "base_dragon" and card.card_type != "stone" and card.card_type != "support": return false
			"rare":
				if card.evolution_stage != 1 and card.card_type != "spell" and card.card_type != "realm": return false
			"mythic":
				if card.sub_type != "fusion_dragon" and card.sub_type != "transcendent_dragon" and card.sub_type != "ascended_dragon" and card.id != "god_dragon": return false

	match current_filter:
		"Confirmed 2024 Originals":
			return card.status == "CONFIRMED"
		"Fusion Dragons", "Fusion & Ascended Dragons":
			return card.sub_type == "fusion_dragon" or card.sub_type == "ascended_dragon"
		"Elemental Dragons":
			return card.sub_type == "elemental_dragon" or card.sub_type == "base_dragon" or card.sub_type == "transcendent_dragon"
		"Elemental Realms":
			return card.card_type == "realm"
		"Spell & Support Cards":
			return card.card_type == "spell" or card.card_type == "support"
		"Element Stones":
			return card.card_type == "stone"
		_:
			return true

func show_card_preview(card: CardData) -> void:
	for child in preview_card_container.get_children():
		child.queue_free()

	var big_card: CardUI = card_ui_prefab.instantiate()
	big_card.hover_zoom = false
	preview_card_container.add_child(big_card)
	big_card.setup(card, use_legacy)
	big_card.pivot_offset = Vector2.ZERO
	big_card.scale = Vector2(1.14, 1.14)
	big_card.position = Vector2(1, 0)

	preview_name.text = card.name
	preview_type.text = card.card_type.to_upper() + " • " + card.sub_type.replace("_", " ").to_upper() + " • " + card.element.to_upper()

	if card.card_type == "beast":
		preview_stats.text = "❤️ HP: " + str(card.hp) + "      ⚔️ ATTACK: " + str(card.attack)
	elif card.card_type == "stone":
		preview_stats.text = "◈ RESOURCE CARD: " + card.element.to_upper() + " STONE"
	elif card.card_type == "realm":
		preview_stats.text = "❖ REALM COST: " + str(card.mana_cost) + " MANA  •  -1 EVO STONE"
	else:
		preview_stats.text = "💧 COST: " + str(card.mana_cost) + " MANA"

	var ability_text = ""
	if card.ability and not card.ability.is_empty():
		ability_text += "[b][color=#ffd166]🐉 " + str(card.ability.get("name", "")) + "[/color][/b]\n"
		ability_text += str(card.ability.get("description", ""))
	elif card.description != "":
		ability_text += card.description
	preview_ability.text = ability_text

	preview_fidelity.text = "⟪  HISTORICAL FIDELITY: " + card.status + "  ⟫"
	match card.status:
		"CONFIRMED":
			preview_fidelity.modulate = Color(0.35, 1.0, 0.45)
		"REMEMBERED":
			preview_fidelity.modulate = Color(1.0, 0.84, 0.28)
		_:
			preview_fidelity.modulate = Color(0.48, 0.86, 1.0)

func _on_filter_selected(idx: int) -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	current_filter = filter_option.get_item_text(idx)
	populate_cards()

func _on_legacy_toggled(toggled: bool) -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	use_legacy = toggled
	populate_cards()

func _on_open_packs_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/pack_opening.tscn")

func _on_back_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
