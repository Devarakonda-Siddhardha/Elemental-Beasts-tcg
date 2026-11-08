class_name MainMenu
extends Control

@onready var vs_ai_button: Button = $VBoxContainer/VsAIButton
@onready var pvp_button: Button = $VBoxContainer/PvPButton
@onready var pack_opening_button: Button = $VBoxContainer/PackOpeningButton
@onready var collection_button: Button = $VBoxContainer/CollectionButton
@onready var deck_builder_button: Button = $VBoxContainer/DeckBuilderButton
@onready var test_suite_button: Button = $VBoxContainer/TestSuiteButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var floating_pack_widget: Control = get_node_or_null("FloatingPackWidget")
@onready var floating_pack_button: TextureButton = get_node_or_null("FloatingPackWidget/FloatingPackButton")

var _bob_time: float = 0.0
var _floating_base_y: float = 500.0
var _toast_panel: PanelContainer = null
static var _welcome_played: bool = false
var _portal_frames: Array[Texture2D] = []
var _portal_frame_timer: float = 0.0
var _portal_frame_idx: int = 0
@onready var background_rect: TextureRect = $Background

func _ready() -> void:
	_load_animated_portal_frames()
	if not _welcome_played and has_node("/root/SoundManager"):
		_welcome_played = true
		var sm = get_node("/root/SoundManager")
		if sm.has_method("play_voice"):
			sm.play_voice("vo_welcome")

	vs_ai_button.pressed.connect(_on_vs_ai_pressed)
	pvp_button.pressed.connect(_on_pvp_pressed)
	if pack_opening_button:
		pack_opening_button.pressed.connect(_on_pack_opening_pressed)
	deck_builder_button.pressed.connect(_on_deck_builder_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	test_suite_button.pressed.connect(_on_test_suite_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	if floating_pack_widget:
		_floating_base_y = floating_pack_widget.position.y
	if floating_pack_button:
		floating_pack_button.pressed.connect(_on_pack_opening_pressed)
		floating_pack_button.mouse_entered.connect(_on_floating_pack_hover.bind(true))
		floating_pack_button.mouse_exited.connect(_on_floating_pack_hover.bind(false))

	# Setup subtle hover scale/glow feedback on all menu buttons
	var menu_buttons: Array[Button] = [
		vs_ai_button,
		pvp_button,
		pack_opening_button,
		collection_button,
		deck_builder_button,
		test_suite_button,
		quit_button
	]
	for btn in menu_buttons:
		if btn:
			btn.pivot_offset = Vector2(195.0, 19.0)
			btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
			btn.mouse_exited.connect(_on_button_hover.bind(btn, false))

func _load_animated_portal_frames() -> void:
	_portal_frames.clear()
	for i in range(12):
		var p := "res://assets/art/portal_frames/frame_%02d.jpg" % i
		if ResourceLoader.exists(p):
			var tex = load(p)
			if tex is Texture2D:
				_portal_frames.append(tex)
	if not _portal_frames.is_empty() and background_rect:
		background_rect.texture = _portal_frames[0]

func _process(delta: float) -> void:
	if floating_pack_widget:
		_bob_time += delta * 2.6
		floating_pack_widget.position.y = _floating_base_y + sin(_bob_time) * 6.0
	if _portal_frames.size() > 1 and background_rect:
		_portal_frame_timer += delta
		if _portal_frame_timer >= 0.09:
			_portal_frame_timer = 0.0
			_portal_frame_idx = (_portal_frame_idx + 1) % _portal_frames.size()
			background_rect.texture = _portal_frames[_portal_frame_idx]

func _on_button_hover(btn: Button, is_hovered: bool) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	if is_hovered and has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		if sm.has_method("play_card_hover"):
			sm.play_card_hover()
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if is_hovered:
		tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.14)
		tw.parallel().tween_property(btn, "modulate", Color(1.12, 1.1, 1.15, 1.0), 0.14)
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.14)
		tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.14)

func _on_floating_pack_hover(is_hovered: bool) -> void:
	if not floating_pack_widget:
		return
	if is_hovered and has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		if sm.has_method("play_card_hover"):
			sm.play_card_hover()
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if is_hovered:
		tw.tween_property(floating_pack_widget, "scale", Vector2(1.1, 1.1), 0.16)
		tw.parallel().tween_property(floating_pack_widget, "modulate", Color(1.18, 1.15, 1.22, 1.0), 0.16)
	else:
		tw.tween_property(floating_pack_widget, "scale", Vector2.ONE, 0.16)
		tw.parallel().tween_property(floating_pack_widget, "modulate", Color.WHITE, 0.16)

func _on_vs_ai_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	_show_starter_deck_selector(true)

func _on_pvp_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	_show_starter_deck_selector(false)

func _show_starter_deck_selector(vs_ai: bool) -> void:
	if has_node("DeckSelectModal"):
		get_node("DeckSelectModal").queue_free()
	var modal = ColorRect.new()
	modal.name = "DeckSelectModal"
	modal.color = Color(0.02, 0.02, 0.06, 0.88)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1140, 620)
	panel.position = Vector2(70, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.98)
	sb.border_color = Color(0.95, 0.78, 0.28, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	sb.shadow_size = 20
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	modal.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "✦ CHOOSE YOUR ELEMENTAL STARTER DECK (40 CARDS) ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	vbox.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	var decks_list: Array = []
	if FileAccess.file_exists("res://data/default_decks.json"):
		var f = FileAccess.open("res://data/default_decks.json", FileAccess.READ)
		var j = JSON.new()
		if j.parse(f.get_as_text()) == OK:
			decks_list = j.get_data().get("decks", [])
		f.close()

	var card_db: Dictionary = CardData.load_database()
	var card_ui_prefab: PackedScene = load("res://scenes/card_ui.tscn")

	var elem_colors = {
		"fire": Color(0.95, 0.35, 0.18),
		"lightning": Color(1.0, 0.82, 0.20),
		"wind": Color(0.25, 0.90, 0.58),
		"ice": Color(0.35, 0.82, 1.0),
		"shadow": Color(0.76, 0.40, 1.0),
		"mechanical": Color(0.85, 0.76, 0.58)
	}

	var main_dragon_ids = {
		"fire": "fire_dragon",
		"lightning": "lightning_dragon",
		"wind": "wind_dragon",
		"ice": "ice_dragon",
		"shadow": "shadow_dragon",
		"mechanical": "mechanical_dragon"
	}

	for i in range(decks_list.size()):
		var d = decks_list[i]
		var el: String = str(d.get("element", "fire"))
		var col: Color = elem_colors.get(el, Color(0.95, 0.78, 0.28))
		var main_dragon_id: String = str(main_dragon_ids.get(el, el + "_dragon"))
		var dragon_card: CardData = card_db.get(main_dragon_id)

		var card_btn = Button.new()
		card_btn.name = "DeckOption_" + el
		card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_btn.custom_minimum_size = Vector2(354, 240)
		card_btn.clip_contents = true
		var b_sb = StyleBoxFlat.new()
		b_sb.bg_color = Color(0.07, 0.08, 0.15, 0.96)
		b_sb.border_color = col
		b_sb.set_border_width_all(2)
		b_sb.set_corner_radius_all(12)
		var b_hover = b_sb.duplicate()
		b_hover.bg_color = Color(0.13, 0.15, 0.26, 0.98)
		b_hover.border_color = col.lightened(0.35)
		b_hover.set_border_width_all(3)
		b_hover.shadow_color = Color(col.r, col.g, col.b, 0.45)
		b_hover.shadow_size = 12
		card_btn.add_theme_stylebox_override("normal", b_sb)
		card_btn.add_theme_stylebox_override("hover", b_hover)
		card_btn.add_theme_stylebox_override("pressed", b_hover)

		# Subtle darkened dragon art backdrop inside the button
		var bg_art_path := "res://assets/art/" + main_dragon_id + ".jpg"
		if ResourceLoader.exists(bg_art_path):
			var bg_art := TextureRect.new()
			bg_art.name = "DragonArtBackdrop"
			bg_art.texture = load(bg_art_path)
			bg_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg_art.modulate = Color(0.32, 0.32, 0.38, 0.38)
			bg_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_btn.add_child(bg_art)

		var main_hbox = HBoxContainer.new()
		main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		main_hbox.offset_left = 10
		main_hbox.offset_right = -10
		main_hbox.offset_top = 8
		main_hbox.offset_bottom = -8
		main_hbox.add_theme_constant_override("separation", 12)
		main_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_btn.add_child(main_hbox)

		# Left: Actual rendered Main Dragon Card (CardUI) at 0.78 scale (156x217)
		var card_holder := Control.new()
		card_holder.name = "MainDragonCardHolder"
		card_holder.custom_minimum_size = Vector2(156, 218)
		card_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main_hbox.add_child(card_holder)

		if dragon_card != null and card_ui_prefab != null:
			var dragon_ui: CardUI = card_ui_prefab.instantiate()
			dragon_ui.name = "MainDragonCardUI"
			dragon_ui.base_scale = Vector2(0.78, 0.78)
			dragon_ui.hover_zoom = false
			dragon_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_holder.add_child(dragon_ui)
			dragon_ui.setup(dragon_card, false)
			dragon_ui.scale = Vector2(0.78, 0.78)
			dragon_ui.position = Vector2(0, 1)
			for ch in dragon_ui.get_children():
				if ch is Control:
					ch.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Right: Deck Crest, Title, Flagship Dragon Name & Stats, and Enter Arena CTA
		var right_v = VBoxContainer.new()
		right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_v.alignment = BoxContainer.ALIGNMENT_CENTER
		right_v.add_theme_constant_override("separation", 6)
		right_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main_hbox.add_child(right_v)

		var h_head = HBoxContainer.new()
		h_head.add_theme_constant_override("separation", 6)
		h_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic_path = "res://assets/icons/" + el + ".png"
		if ResourceLoader.exists(ic_path):
			var tex = TextureRect.new()
			tex.texture = load(ic_path)
			tex.custom_minimum_size = Vector2(26, 26)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h_head.add_child(tex)
		var d_title = Label.new()
		d_title.text = str(d.get("name", "Starter Deck")).replace(" (" + el.capitalize() + " Starter)", "")
		d_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_title.add_theme_font_size_override("font_size", 14)
		d_title.add_theme_color_override("font_color", col.lightened(0.30))
		d_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h_head.add_child(d_title)
		right_v.add_child(h_head)

		var dragon_badge = Label.new()
		if dragon_card != null:
			dragon_badge.text = "🐉 Flagship: " + dragon_card.name + "\n⚔ " + str(dragon_card.attack) + " ATK   •   ♥ " + str(dragon_card.hp) + " HP"
		else:
			dragon_badge.text = "🐉 " + el.capitalize() + " Dragon"
		dragon_badge.add_theme_font_size_override("font_size", 12)
		dragon_badge.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
		dragon_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_v.add_child(dragon_badge)

		var ability_preview = Label.new()
		if dragon_card != null and not dragon_card.ability.is_empty():
			ability_preview.text = "✦ " + str(dragon_card.ability.get("name", "")) + ": " + str(dragon_card.ability.get("description", ""))
		else:
			ability_preview.text = str(d.get("description", ""))
		ability_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_preview.add_theme_font_size_override("font_size", 10)
		ability_preview.add_theme_color_override("font_color", Color(0.80, 0.84, 0.92))
		ability_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ability_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right_v.add_child(ability_preview)

		var cta_panel = PanelContainer.new()
		cta_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cta_sb = StyleBoxFlat.new()
		cta_sb.bg_color = Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 0.92)
		cta_sb.border_color = col.lightened(0.25)
		cta_sb.set_border_width_all(1)
		cta_sb.set_corner_radius_all(6)
		cta_sb.content_margin_top = 4
		cta_sb.content_margin_bottom = 4
		cta_panel.add_theme_stylebox_override("panel", cta_sb)
		var play_lbl = Label.new()
		play_lbl.text = "⚔ Select & Enter Arena ➔"
		play_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play_lbl.add_theme_font_size_override("font_size", 12)
		play_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
		play_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cta_panel.add_child(play_lbl)
		right_v.add_child(cta_panel)

		var deck_idx = i
		card_btn.pressed.connect(func():
			if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
			var battle_scene = load("res://scenes/battle.tscn").instantiate()
			battle_scene.is_vs_ai = vs_ai
			battle_scene.set("selected_starter_deck_index", deck_idx)
			get_tree().root.add_child(battle_scene)
			queue_free()
		)
		grid.add_child(card_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "✖ Cancel"
	cancel_btn.custom_minimum_size = Vector2(160, 34)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(func():
		if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
		modal.queue_free()
	)
	vbox.add_child(cancel_btn)


func _on_pack_opening_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/pack_opening.tscn")

func _on_deck_builder_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/deck_builder.tscn")

func _on_collection_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/card_collection.tscn")

func _on_test_suite_pressed() -> void:
	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		sm.play_ui_click()
		if sm.has_method("show_audio_settings_modal"):
			sm.show_audio_settings_modal(self)

func _show_verification_toast(msg: String) -> void:
	if is_instance_valid(_toast_panel):
		_toast_panel.queue_free()
	_toast_panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.22, 0.96)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.78, 0.25, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 10
	_toast_panel.add_theme_stylebox_override("panel", sb)

	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78, 1.0))
	lbl.add_theme_font_size_override("font_size", 13)
	_toast_panel.add_child(lbl)

	add_child(_toast_panel)
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.position = Vector2(240, 22)
	_toast_panel.modulate.a = 0.0

	var tw = create_tween()
	tw.tween_property(_toast_panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.2)
	tw.tween_property(_toast_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast_panel.queue_free)

func _on_quit_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().quit()
