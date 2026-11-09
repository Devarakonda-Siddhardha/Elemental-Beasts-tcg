class_name BattleController
extends Control

@export var is_vs_ai: bool = true
@export var use_legacy_art: bool = false
@export var selected_starter_deck_index: int = 0
@export var skip_coin_flip_overlay: bool = false

var game_state: GameState
var ai_controller: AIController
var card_ui_prefab = preload("res://scenes/card_ui.tscn")

var selected_hand_card_ui: CardUI = null
var selected_field_beast_ui: CardUI = null
var current_action_mode: String = "none" # "none", "evolving", "fusing", "attacking", "targeting_spell", "targeting_ability"
var selected_ability_beast_index: int = -1

# UI Nodes
const FIELD_CARD_SCALE: float = 0.64
const HAND_CARD_SCALE: float = 0.6
const PREVIEW_CARD_SCALE: float = 1.0
const ELEMENT_UI_COLORS = {
	"fire": Color(1.0, 0.4, 0.2), "lightning": Color(1.0, 0.85, 0.2), "wind": Color(0.3, 0.95, 0.55),
	"ice": Color(0.4, 0.85, 1.0), "shadow": Color(0.78, 0.45, 1.0), "mechanical": Color(0.85, 0.8, 0.75)
}

@onready var player_hp_label: Label = $PlayerBar/LifeCrest/HPLabel
@onready var player_mana_label: Label = $PlayerBar/ManaLabel
@onready var player_mana_pips: HBoxContainer = $PlayerBar/ManaPips
@onready var player_stones_container: HBoxContainer = $PlayerStonePanel/StonesContainer

@onready var opponent_panel: Panel = $OpponentBar
@onready var opponent_hp_label: Label = $OpponentBar/LifeCrest/HPLabel
@onready var opponent_mana_label: Label = $OpponentBar/ManaLabel
@onready var opponent_mana_pips: HBoxContainer = $OpponentBar/ManaPips
@onready var opponent_stones_container: HBoxContainer = $OpponentStonePanel/StonesContainer

@onready var piles_grid: GridContainer = $PilesPanel/Grid
var pile_labels: Dictionary = {}
var pile_cells: Dictionary = {}

@onready var selected_panel: Panel = get_node_or_null("SelectedPanel")
@onready var preview_holder: Control = $SelectedPanel/PreviewHolder
var preview_card: CardUI = null

@onready var player_hand_container: HBoxContainer = $HandArea/HandContainer
@onready var player_field_container: HBoxContainer = $PlayerField/BeastSlots
@onready var opponent_field_container: HBoxContainer = $OpponentField/BeastSlots

@onready var turn_label: Label = $TurnPanel/TurnLabel
@onready var active_player_label: Label = $TurnPanel/ActivePlayerLabel
@onready var end_turn_button: Button = $TurnPanel/EndTurnButton
@onready var log_panel: Panel = $LogPanel
@onready var log_label: RichTextLabel = $LogPanel/LogText
@onready var prompt_banner: Label = $PromptBanner

@onready var legacy_toggle_button: Button = $LegacyToggle
@onready var menu_button: Button = $MenuButton

var _prev_hand_size: int = 0
var _animate_hand_fan: bool = true

func _ready() -> void:
	game_state = GameState.new()
	ai_controller = AIController.new(game_state, 1)
	
	# Connect signals
	game_state.turn_started.connect(_on_turn_started)
	game_state.turn_ended.connect(_on_turn_ended)
	game_state.card_drawn.connect(_on_card_drawn)
	game_state.beast_summoned.connect(_on_beast_summoned)
	game_state.beast_evolved.connect(_on_beast_evolved)
	game_state.beasts_fused.connect(_on_beasts_fused)
	game_state.beast_transcended.connect(_on_beast_transcended)
	game_state.beast_ascended.connect(_on_beast_ascended)
	game_state.god_dragon_summoned.connect(_on_god_dragon_summoned)
	game_state.combat_resolved.connect(_on_combat_resolved)
	game_state.deck_shuffled.connect(_on_deck_shuffled)
	game_state.paralysis_tested.connect(_on_paralysis_tested)
	game_state.game_ended.connect(_on_game_ended)
	
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if legacy_toggle_button and not legacy_toggle_button.toggled.is_connected(_on_legacy_toggle):
		legacy_toggle_button.toggled.connect(_on_legacy_toggle)
	if menu_button and not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)
		
	if opponent_panel and not opponent_panel.gui_input.is_connected(_on_opponent_panel_input):
		opponent_panel.gui_input.connect(_on_opponent_panel_input)
	var opp_field = $OpponentField
	if opp_field and not opp_field.gui_input.is_connected(_on_opponent_panel_input):
		opp_field.gui_input.connect(_on_opponent_panel_input)
		
	_build_static_ui()
	if log_panel:
		log_panel.visible = false
	
	var player_deck = GameState.load_starter_deck_ids_by_index(selected_starter_deck_index)
	var ai_deck_idx = (selected_starter_deck_index + 3) % 6
	var ai_deck = GameState.load_starter_deck_ids_by_index(ai_deck_idx)
	
	log_message("[color=#ffd166]◆ Duel Initialized — 30 ♥ | 5 💧[/color]")
	game_state.start_game(player_deck, ai_deck, 0)
	_animate_hand_fan = true
	refresh_full_ui()
	if not skip_coin_flip_overlay:
		_show_start_of_match_coin_flip(player_deck, ai_deck)

func refresh_full_ui() -> void:
	update_hud()
	refresh_player_hand()
	refresh_fields()

func _build_static_ui() -> void:
	# Neon slot frames behind both battlefields (blue = opponent, amber = you)
	for pair in [[$OpponentField/SlotFrames, Color(0.25, 0.7, 1.0)], [$PlayerField/SlotFrames, Color(1.0, 0.6, 0.15)]]:
		var box: HBoxContainer = pair[0]
		for c in box.get_children():
			c.queue_free()
		for i in range(RulesConfig.MAX_FIELD_BEASTS):
			var sf = SlotFrame.new()
			sf.accent = pair[1]
			sf.custom_minimum_size = Vector2(200, 278) * FIELD_CARD_SCALE
			box.add_child(sf)
	# Deck / Discard / Banish grid (opponent row, then your row)
	for c in piles_grid.get_children():
		c.queue_free()
	var zone_tooltips = {"Deck": "Deck (Click to Inspect / Shuffle)", "Discard": "Discard Pile (Click to Inspect)", "Banish": "Banish Zone"}
	var zone_symbols = {"Deck": "❖ 0", "Discard": "✖ 0", "Banish": "✦ 0"}
	for owner in ["enemy", "player"]:
		for zone in ["Deck", "Discard", "Banish"]:
			var cell = PanelContainer.new()
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.05, 0.03, 0.1, 0.85)
			sb.set_border_width_all(1)
			sb.border_color = Color(0.7, 0.55, 0.25, 0.8) if owner == "player" else Color(0.4, 0.6, 0.9, 0.8)
			sb.set_corner_radius_all(6)
			cell.add_theme_stylebox_override("panel", sb)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell.tooltip_text = zone_tooltips[zone]
			var v = VBoxContainer.new()
			v.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_theme_constant_override("separation", 2)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icon = TextureRect.new()
			icon.custom_minimum_size = Vector2(0, 44)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if zone != "Banish":
				icon.texture = load("res://assets/art/card_back.png")
				if zone == "Discard":
					icon.modulate = Color(0.75, 0.45, 0.5)
			else:
				icon.texture = load("res://assets/icons/shadow.png") if ResourceLoader.exists("res://assets/icons/shadow.png") else null
			var lbl = Label.new()
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.text = zone_symbols[zone]
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(icon)
			v.add_child(lbl)
			cell.add_child(v)
			piles_grid.add_child(cell)
			var cell_key = owner + "_" + zone
			pile_labels[cell_key] = lbl
			pile_cells[cell_key] = cell
			if owner == "player" and (zone == "Deck" or zone == "Discard"):
				var z_cap = zone
				cell.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						if z_cap == "Deck":
							open_deck_search_modal("✦ YOUR REMAINING DECK (SHUFFLED VIEW) ✦", game_state.get_deck(0), Callable(), true)
						else:
							open_deck_search_modal("✦ YOUR DISCARD PILE ✦", game_state.get_discard(0), Callable(), false)
				)

	# Connect On-Field Deck and Discard Slots matching reference playmat
	var p_deck = get_node_or_null("PlayerDeckSlot")
	if p_deck and not p_deck.gui_input.is_connected(self._on_player_deck_input):
		p_deck.gui_input.connect(self._on_player_deck_input)
	var p_disc = get_node_or_null("PlayerDiscardSlot")
	if p_disc and not p_disc.gui_input.is_connected(self._on_player_discard_input):
		p_disc.gui_input.connect(self._on_player_discard_input)
	var op_disc = get_node_or_null("OpponentDiscardSlot")
	if op_disc and not op_disc.gui_input.is_connected(self._on_opponent_discard_input):
		op_disc.gui_input.connect(self._on_opponent_discard_input)

	# Build Top-Right Utility Buttons: Audio Settings (🔊) & Battle Log Toggle (📜)
	_setup_utility_and_log_controls()

func _setup_utility_and_log_controls() -> void:
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.09, 0.04, 0.16, 0.92)
	btn_sb.border_color = Color(0.88, 0.68, 0.28, 1.0)
	btn_sb.set_border_width_all(2)
	btn_sb.set_corner_radius_all(10)

	if not has_node("AudioSettingsBtn"):
		var audio_btn := Button.new()
		audio_btn.name = "AudioSettingsBtn"
		audio_btn.text = "🔊"
		audio_btn.tooltip_text = "Audio & Commentator Voice Settings"
		audio_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		audio_btn.offset_left = -96.0
		audio_btn.offset_top = 52.0
		audio_btn.offset_right = -54.0
		audio_btn.offset_bottom = 92.0
		audio_btn.add_theme_font_size_override("font_size", 16)
		audio_btn.add_theme_stylebox_override("normal", btn_sb)
		audio_btn.add_theme_stylebox_override("hover", btn_sb)
		audio_btn.add_theme_stylebox_override("pressed", btn_sb)
		audio_btn.pressed.connect(func():
			if has_node("/root/SoundManager"):
				var sm = get_node("/root/SoundManager")
				sm.play_ui_click()
				if sm.has_method("show_audio_settings_modal"):
					sm.show_audio_settings_modal(self)
		)
		add_child(audio_btn)

	if not has_node("LogToggleBtn"):
		var log_btn := Button.new()
		log_btn.name = "LogToggleBtn"
		log_btn.text = "📜"
		log_btn.tooltip_text = "Toggle Battle Log On / Off"
		log_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		log_btn.offset_left = -48.0
		log_btn.offset_top = 52.0
		log_btn.offset_right = -8.0
		log_btn.offset_bottom = 92.0
		log_btn.add_theme_font_size_override("font_size", 16)
		log_btn.add_theme_stylebox_override("normal", btn_sb)
		log_btn.add_theme_stylebox_override("hover", btn_sb)
		log_btn.add_theme_stylebox_override("pressed", btn_sb)
		log_btn.pressed.connect(_toggle_battle_log)
		add_child(log_btn)

	if log_panel and not log_panel.has_node("CloseLogBtn"):
		var close_log := Button.new()
		close_log.name = "CloseLogBtn"
		close_log.text = "—"
		close_log.tooltip_text = "Hide Battle Log"
		close_log.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		close_log.offset_left = -28.0
		close_log.offset_top = 3.0
		close_log.offset_right = -4.0
		close_log.offset_bottom = 23.0
		close_log.add_theme_font_size_override("font_size", 11)
		close_log.pressed.connect(_toggle_battle_log)
		log_panel.add_child(close_log)

func _toggle_battle_log() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	if log_panel:
		log_panel.visible = not log_panel.visible

func _on_player_deck_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_ui_click()
		open_deck_search_modal("✦ YOUR REMAINING DECK (SHUFFLED VIEW) ✦", game_state.get_deck(0), Callable(), true)

func _on_player_discard_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_ui_click()
		open_deck_search_modal("✦ YOUR DISCARD PILE ✦", game_state.get_discard(0), Callable(), false)

func _on_opponent_discard_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_ui_click()
		open_deck_search_modal("✦ OPPONENT'S DISCARD PILE ✦", game_state.get_discard(1), Callable(), false)

func _update_mana_pips(container: HBoxContainer, current: int) -> void:
	# Render a single glowing sapphire Mana Symbol Crest with the current Mana number inside it (e.g., "5")
	if container.get_child_count() != 1 or not container.get_child(0).has_meta("is_mana_symbol_orb"):
		for c in container.get_children():
			c.queue_free()
		var orb_holder := Control.new()
		orb_holder.set_meta("is_mana_symbol_orb", true)
		orb_holder.custom_minimum_size = Vector2(58, 58)
		orb_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(orb_holder)

		var orb := Panel.new()
		orb.name = "ManaOrb"
		orb.position = Vector2.ZERO
		orb.size = Vector2(58, 58)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orb_holder.add_child(orb)

		var inner_ring := Panel.new()
		inner_ring.name = "InnerRing"
		inner_ring.position = Vector2(4, 4)
		inner_ring.size = Vector2(50, 50)
		inner_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orb.add_child(inner_ring)

		var num_lbl := Label.new()
		num_lbl.name = "ManaNum"
		num_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		num_lbl.offset_top = 4.0
		num_lbl.offset_bottom = 36.0
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 22)
		num_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		num_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.12, 0.35, 0.70))
		num_lbl.add_theme_constant_override("shadow_offset_x", 1)
		num_lbl.add_theme_constant_override("shadow_offset_y", 1)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orb.add_child(num_lbl)

		var cap_lbl := Label.new()
		cap_lbl.name = "ManaTag"
		cap_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		cap_lbl.offset_top = -18.0
		cap_lbl.offset_bottom = -3.0
		cap_lbl.text = "MANA"
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap_lbl.add_theme_font_size_override("font_size", 10)
		cap_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
		cap_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orb.add_child(cap_lbl)

	var holder: Control = container.get_child(0)
	var orb_panel: Panel = holder.get_node("ManaOrb")
	var ring_panel: Panel = orb_panel.get_node("InnerRing")
	var num_label: Label = orb_panel.get_node("ManaNum")

	var outer_sb := StyleBoxFlat.new()
	outer_sb.set_corner_radius_all(29)
	outer_sb.set_border_width_all(2)
	var inner_sb := StyleBoxFlat.new()
	inner_sb.set_corner_radius_all(25)
	inner_sb.set_border_width_all(1)

	if current > 0:
		outer_sb.bg_color = Color(0.06, 0.34, 0.78, 0.98)
		outer_sb.border_color = Color(0.95, 0.82, 0.35, 1.0)
		outer_sb.shadow_color = Color(0.20, 0.72, 1.0, 0.50)
		outer_sb.shadow_size = 8
		inner_sb.bg_color = Color(0.16, 0.62, 0.98, 0.95)
		inner_sb.border_color = Color(0.78, 0.96, 1.0, 0.9)
	else:
		outer_sb.bg_color = Color(0.14, 0.16, 0.24, 0.95)
		outer_sb.border_color = Color(0.45, 0.48, 0.56, 0.85)
		inner_sb.bg_color = Color(0.20, 0.22, 0.30, 0.9)
		inner_sb.border_color = Color(0.38, 0.40, 0.48, 0.7)

	orb_panel.add_theme_stylebox_override("panel", outer_sb)
	ring_panel.add_theme_stylebox_override("panel", inner_sb)
	num_label.text = str(current)

func update_hud() -> void:
	var p_hp = game_state.player_hp[0]
	player_hp_label.text = str(p_hp)
	var p_mana = game_state.get_mana(0).current_mana
	player_mana_label.visible = false
	_update_mana_pips(player_mana_pips, p_mana)
	refresh_stones_display(0, player_stones_container)

	var op_hp = game_state.player_hp[1]
	opponent_hp_label.text = str(op_hp)
	var op_mana = game_state.get_mana(1).current_mana
	opponent_mana_label.visible = false
	_update_mana_pips(opponent_mana_pips, op_mana)
	refresh_stones_display(1, opponent_stones_container)

	if pile_labels.has("player_Deck"):
		pile_labels["player_Deck"].text = "❖ " + str(game_state.player_decks[0].size())
		pile_labels["player_Discard"].text = "✖ " + str(game_state.player_discards[0].size())
		pile_labels["player_Banish"].text = "✦ 0"
		pile_labels["enemy_Deck"].text = "❖ " + str(game_state.player_decks[1].size())
		pile_labels["enemy_Discard"].text = "✖ " + str(game_state.player_discards[1].size())
		pile_labels["enemy_Banish"].text = "✦ 0"

	# Update On-Field Deck and Discard Slot Badges matching reference playmat
	var p_deck_badge: Label = get_node_or_null("PlayerDeckSlot/CountBadge")
	if p_deck_badge:
		p_deck_badge.text = "❖ " + str(game_state.player_decks[0].size())
	var p_disc_badge: Label = get_node_or_null("PlayerDiscardSlot/CountBadge")
	if p_disc_badge:
		p_disc_badge.text = "✖ " + str(game_state.player_discards[0].size())
	var op_deck_badge: Label = get_node_or_null("OpponentDeckSlot/CountBadge")
	if op_deck_badge:
		op_deck_badge.text = "❖ " + str(game_state.player_decks[1].size())
	var op_disc_badge: Label = get_node_or_null("OpponentDiscardSlot/CountBadge")
	if op_disc_badge:
		op_disc_badge.text = "✖ " + str(game_state.player_discards[1].size())

	turn_label.text = "TURN " + str(game_state.turn_number)
	if game_state.active_player_id == 0:
		active_player_label.text = "YOUR TURN"
		active_player_label.modulate = Color(0.3, 1.0, 0.4)
		end_turn_button.disabled = false
	else:
		active_player_label.text = "OPPONENT'S TURN" if is_vs_ai else "PLAYER 2'S TURN"
		active_player_label.modulate = Color(1.0, 0.4, 0.4)
		end_turn_button.disabled = is_vs_ai

	_update_realm_banner()

func _update_realm_banner() -> void:
	var r_badge: Button = get_node_or_null("ActiveRealmBadge")
	if not r_badge:
		r_badge = Button.new()
		r_badge.name = "ActiveRealmBadge"
		r_badge.position = Vector2(18, 250)
		r_badge.custom_minimum_size = Vector2(190, 48)
		r_badge.add_theme_font_size_override("font_size", 11)
		r_badge.pressed.connect(func():
			if game_state.active_realm != null:
				var temp_ui: CardUI = card_ui_prefab.instantiate()
				temp_ui.card_data = game_state.active_realm
				_on_any_card_hovered(temp_ui, true)
				temp_ui.queue_free()
		)
		add_child(r_badge)

	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	if game_state.active_realm != null:
		var r_el = game_state.active_realm.element.to_lower()
		var col: Color = ELEMENT_UI_COLORS.get(r_el, Color(0.95, 0.78, 0.28))
		sb.bg_color = Color(0.08, 0.07, 0.16, 0.96)
		sb.border_color = col
		r_badge.text = "❖ REALM: " + game_state.active_realm.name.to_upper() + "\n(Evolutions: -1 ◈ Stone)"
		r_badge.add_theme_color_override("font_color", col.lightened(0.3))
		r_badge.tooltip_text = game_state.active_realm.description
	else:
		sb.bg_color = Color(0.05, 0.05, 0.10, 0.75)
		sb.border_color = Color(0.35, 0.35, 0.45, 0.65)
		r_badge.text = "❖ NO ACTIVE REALM\n(Play a Realm Card)"
		r_badge.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
		r_badge.tooltip_text = "Play a Realm Location card to reduce Dragon Evolution stone requirements by 1!"
	r_badge.add_theme_stylebox_override("normal", sb)
	r_badge.add_theme_stylebox_override("hover", sb)
	r_badge.add_theme_stylebox_override("pressed", sb)

func refresh_stones_display(player_id: int, container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	var stone_mgr = game_state.get_stones(player_id)
	for el in RulesConfig.CONFIRMED_ELEMENTS:
		var count = stone_mgr.get_stone_count(el)
		var col: Color = ELEMENT_UI_COLORS.get(el, Color.WHITE)
		var v = VBoxContainer.new()
		v.custom_minimum_size = Vector2(42, 0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path = "res://assets/icons/" + el + ".png"
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		if count == 0:
			icon.modulate = Color(1, 1, 1, 0.45)
		var cnt = Label.new()
		cnt.text = "×" + str(count)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 13)
		cnt.add_theme_color_override("font_color", col if count > 0 else Color(0.6, 0.6, 0.65, 0.55))
		v.add_child(icon)
		v.add_child(cnt)
		container.add_child(v)

func _wrap_card(card_ui: CardUI, s: float) -> Control:
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(200, 278) * s
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_ui.set("is_compact", true)
	holder.add_child(card_ui)
	card_ui.base_scale = Vector2(s, s)
	card_ui.scale = card_ui.base_scale
	# CardUI pivots around its centre (100,139); compensate so it sits in the holder
	card_ui.position = -Vector2(100, 139) * (1.0 - s)
	card_ui.card_hovered.connect(_on_any_card_hovered)
	return holder

func _on_any_card_hovered(card_ui: CardUI, is_hovered: bool) -> void:
	if not is_hovered or card_ui == null or card_ui.card_data == null:
		if selected_panel and selected_panel.visible:
			selected_panel.visible = false
		return
	if selected_panel:
		selected_panel.visible = true
	if preview_card == null:
		preview_card = card_ui_prefab.instantiate()
		preview_card.hover_zoom = false
		preview_card.set("is_compact", false)
		preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_holder.add_child(preview_card)
		preview_card.scale = Vector2(PREVIEW_CARD_SCALE, PREVIEW_CARD_SCALE)
		preview_card.position = -Vector2(100, 139) * (1.0 - PREVIEW_CARD_SCALE)
		if preview_holder.has_node("Hint"):
			preview_holder.get_node("Hint").visible = false
	preview_card.set("is_compact", false)
	if preview_card.has_method("set_compact"):
		preview_card.set_compact(false)
	if card_ui.beast_instance_ref:
		preview_card.setup_from_beast(card_ui.beast_instance_ref)
		preview_card.is_on_field = false
	else:
		preview_card.setup(card_ui.card_data, use_legacy_art)
	if preview_card.has_method("set_compact"):
		preview_card.set_compact(false)

func refresh_player_hand() -> void:
	for child in player_hand_container.get_children():
		child.queue_free()

	var hand = game_state.get_hand(0)
	var mana_mgr = game_state.get_mana(0)
	var stone_mgr = game_state.get_stones(0)
	var field = game_state.get_field(0)

	# Fan/overlap cards so the whole hand fits the hand area
	var cw = 200.0 * HAND_CARD_SCALE
	var avail = player_hand_container.get_parent().size.x
	if avail <= 0:
		avail = 700.0
	var sep = -14
	if hand.size() > 1:
		sep = mini(-14, int((avail - cw * hand.size()) / float(hand.size() - 1)))
	player_hand_container.add_theme_constant_override("separation", sep)

	var should_fan_in: bool = _animate_hand_fan or (hand.size() > _prev_hand_size)
	_prev_hand_size = hand.size()
	_animate_hand_fan = false

	var mid = (hand.size() - 1) * 0.5
	var first_card_ui: CardUI = null
	var base_pos := -Vector2(100, 139) * (1.0 - HAND_CARD_SCALE)
	for i in range(hand.size()):
		var card: CardData = hand[i]
		var card_ui: CardUI = card_ui_prefab.instantiate()
		player_hand_container.add_child(_wrap_card(card_ui, HAND_CARD_SCALE))
		card_ui.setup(card, use_legacy_art)
		if card_ui.has_method("set_compact"):
			card_ui.set_compact(true)
		var offset_from_mid = float(i) - mid
		var target_rot: float = offset_from_mid * 3.8
		var target_y_arc: float = (offset_from_mid * offset_from_mid) * 2.2
		var target_pos := base_pos + Vector2(0.0, target_y_arc)

		if should_fan_in and is_inside_tree():
			card_ui.rotation_degrees = 0.0
			card_ui.position = base_pos + Vector2(-offset_from_mid * 28.0, 46.0)
			card_ui.scale = card_ui.base_scale * 0.72
			var f_tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			f_tw.tween_interval(float(i) * 0.032)
			f_tw.tween_property(card_ui, "position", target_pos, 0.24)
			f_tw.parallel().tween_property(card_ui, "rotation_degrees", target_rot, 0.24)
			f_tw.parallel().tween_property(card_ui, "scale", card_ui.base_scale, 0.24)
		else:
			card_ui.rotation_degrees = target_rot
			card_ui.position = target_pos

		var idx_capture := i
		card_ui.card_hovered.connect(func(_c: CardUI, hovered: bool):
			_on_hand_card_fan_hover(idx_capture, hovered)
		)

		if first_card_ui == null:
			first_card_ui = card_ui

		var playable = false
		if game_state.active_player_id == 0:
			if card.card_type == "stone" and stone_mgr.can_place_stone():
				playable = true
			elif card.card_type == "realm" and mana_mgr.can_spend(card.mana_cost):
				playable = true
			elif (card.id == "little_dragon" or card.sub_type == "base_dragon") and mana_mgr.can_spend(card.mana_cost if card.mana_cost > 0 else 2) and field.size() < 4:
				playable = true
			elif card.evolution_stage == 1:
				for b in field:
					if EvolutionEngine.can_evolve(b, card, stone_mgr, game_state.active_realm).valid:
						playable = true
						break
			elif card.sub_type == "fusion_dragon":
				if FusionEngine.can_fuse(field, card).valid:
					playable = true
			elif card.sub_type == "transcendent_dragon":
				for b in field:
					if TranscendenceEngine.can_transcend(b, card, stone_mgr).valid:
						playable = true
						break
			elif card.sub_type == "ascended_dragon":
				for b in field:
					if AscensionEngine.can_ascend(b, card, stone_mgr).valid:
						playable = true
						break
			elif card.id == "god_dragon":
				if GodDragonRitual.can_summon_god_dragon(card, field, stone_mgr, game_state.player_has_summoned_god_dragon[0]).valid:
					playable = true
			elif (card.id == "compass" or card.id == "draconic_tome" or card.id == "ancient_insight" or card.id == "elemental_convergence") and mana_mgr.can_spend(card.mana_cost):
				playable = true
			elif card.id == "draconic_calling" and mana_mgr.can_spend(card.mana_cost) and hand.size() >= 2:
				playable = true
			elif card.id == "soul_rebirth" and mana_mgr.can_spend(card.mana_cost):
				for dc in game_state.get_discard(0):
					if dc is CardData and dc.card_type == "beast":
						playable = true
						break
			elif card.card_type == "spell" and mana_mgr.can_spend(card.mana_cost):
				playable = true

		card_ui.set_playable(playable)
		var h_idx = i
		card_ui.card_clicked.connect(func(c): _on_hand_card_clicked(c, h_idx))

	if preview_card == null and first_card_ui != null:
		_on_any_card_hovered(first_card_ui, true)

func _on_hand_card_fan_hover(hovered_idx: int, is_hovered: bool) -> void:
	var count := player_hand_container.get_child_count()
	if count == 0:
		return
	var mid := (count - 1) * 0.5
	var base_pos := -Vector2(100, 139) * (1.0 - HAND_CARD_SCALE)
	for i in range(count):
		var holder: Control = player_hand_container.get_child(i)
		if holder.get_child_count() == 0:
			continue
		var cui: CardUI = holder.get_child(0)
		var offset_from_mid := float(i) - mid
		var rest_rot: float = offset_from_mid * 3.8
		var rest_y: float = (offset_from_mid * offset_from_mid) * 2.2
		var target_pos := base_pos + Vector2(0.0, rest_y)
		var target_rot := rest_rot
		if is_hovered:
			if i == hovered_idx:
				target_pos = base_pos + Vector2(0.0, -24.0)
				target_rot = 0.0
			else:
				var push_dir := -1.0 if i < hovered_idx else 1.0
				var dist := float(abs(i - hovered_idx))
				var push_px := push_dir * (18.0 / maxf(1.0, dist * 0.65))
				target_pos = base_pos + Vector2(push_px, rest_y + 4.0)
				target_rot = rest_rot + push_dir * 2.5
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(cui, "position", target_pos, 0.14)
		tw.parallel().tween_property(cui, "rotation_degrees", target_rot, 0.14)

func _format_ability_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	var parts: Array = []
	for elem in cost.keys():
		var amt = cost[elem]
		var elem_icon = ""
		match elem:
			"fire": elem_icon = "🔥 Fire"
			"water": elem_icon = "💧 Water"
			"ice": elem_icon = "❄️ Ice"
			"wind": elem_icon = "🌪️ Wind"
			"lightning": elem_icon = "⚡ Lightning"
			"shadow": elem_icon = "🌑 Shadow"
			"mechanical": elem_icon = "⚙️ Mech"
			"any_stone": elem_icon = "💎 Any Stone"
			_: elem_icon = elem.capitalize()
		parts.append(str(amt) + " " + elem_icon)
	return ", ".join(parts)

func _on_paralysis_tested(player_id: int, beast: BeastInstance, recovered: bool, coin: String) -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_coin_flip()
	var p_name = "Your" if player_id == 0 else "Opponent's"
	if recovered:
		log_message("  🪙 [b]" + p_name + " " + beast.card_data.name + "[/b] flipped [b]HEADS[/b]! Paralysis broken! ⚡➔✨")
	else:
		log_message("  🪙 [b]" + p_name + " " + beast.card_data.name + "[/b] flipped [b]TAILS[/b]! Remains Paralyzed this turn! ⚡")

func refresh_fields() -> void:
	for child in player_field_container.get_children():
		child.queue_free()
	for i in range(game_state.player_fields[0].size()):
		var b: BeastInstance = game_state.player_fields[0][i]
		var c_ui: CardUI = card_ui_prefab.instantiate()
		var wrapper = _wrap_card(c_ui, FIELD_CARD_SCALE)
		player_field_container.add_child(wrapper)
		c_ui.setup_from_beast(b)
		if c_ui.has_method("set_compact"):
			c_ui.set_compact(true)
		c_ui.set_attack_ready(b.can_attack(game_state.turn_number) and game_state.active_player_id == 0)
		if b.stun_turns > 0:
			c_ui.set_status_display("stun", b.stun_turns)
		elif b.freeze_turns > 0:
			c_ui.set_status_display("freeze", b.freeze_turns)
		elif b.is_paralyzed:
			c_ui.set_status_display("paralysis", 0)
		var f_idx = i
		c_ui.card_clicked.connect(func(c): _on_player_field_clicked(c, f_idx))
		c_ui.card_right_clicked.connect(func(c): _on_player_field_right_clicked(c, f_idx))

		# Visible ability activation button directly on the beast card wrapper
		if b.card_data.ability and b.card_data.ability.get("trigger") == "activated":
			var abil_btn = Button.new()
			abil_btn.name = "AbilityButton"
			var abil_name = b.card_data.ability.get("name", "Ability")
			abil_btn.text = "⚡ " + abil_name.to_upper()
			abil_btn.custom_minimum_size = Vector2(120, 24)
			abil_btn.position = Vector2(4, 150)
			abil_btn.z_index = 5

			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.08, 0.18, 0.32, 0.95)
			sb.border_color = Color(0.35, 0.85, 1.0, 0.95)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(4)
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			abil_btn.add_theme_stylebox_override("normal", sb)

			var sb_h = sb.duplicate()
			sb_h.bg_color = Color(0.18, 0.38, 0.68, 1.0)
			sb_h.border_color = Color(0.7, 0.98, 1.0, 1.0)
			abil_btn.add_theme_stylebox_override("hover", sb_h)
			abil_btn.add_theme_font_size_override("font_size", 10)

			var check = AbilityResolver.can_activate_ability(b, game_state.player_stones[0], game_state.player_hands[0])
			if not check.valid or game_state.active_player_id != 0:
				abil_btn.modulate = Color(0.65, 0.65, 0.65, 0.6)
				abil_btn.tooltip_text = check.error if not check.valid else "Not your turn"
			else:
				abil_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
				abil_btn.tooltip_text = "Activate " + abil_name + " (" + _format_ability_cost(b.card_data.ability.get("cost", {})) + ")"

			abil_btn.pressed.connect(func(): _on_beast_ability_triggered(f_idx))
			wrapper.add_child(abil_btn)

	for child in opponent_field_container.get_children():
		child.queue_free()
	for i in range(game_state.player_fields[1].size()):
		var b: BeastInstance = game_state.player_fields[1][i]
		var c_ui: CardUI = card_ui_prefab.instantiate()
		opponent_field_container.add_child(_wrap_card(c_ui, FIELD_CARD_SCALE))
		c_ui.setup_from_beast(b)
		if c_ui.has_method("set_compact"):
			c_ui.set_compact(true)
		if b.stun_turns > 0:
			c_ui.set_status_display("stun", b.stun_turns)
		elif b.freeze_turns > 0:
			c_ui.set_status_display("freeze", b.freeze_turns)
		elif b.is_paralyzed:
			c_ui.set_status_display("paralysis", 0)
		var f_idx = i
		c_ui.card_clicked.connect(func(c): _on_opponent_field_clicked(c, f_idx))

func _on_hand_card_clicked(card_ui: CardUI, hand_index: int) -> void:
	if game_state.active_player_id != 0 or game_state.is_game_over:
		return
		
	var card = card_ui.card_data
	
	# If Stone card -> place directly (unlimited stone cards per turn)
	if card.card_type == "stone":
		if game_state.play_stone_from_hand(0, hand_index):
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_stone_place()
			log_message("  ◈ Placed [b]" + card.name + "[/b]")
			refresh_full_ui()
		return

	# If Realm / Location card -> place directly in active Realm slot (replaces any previous Realm)
	if card.card_type == "realm":
		var r_res = game_state.play_realm(0, hand_index)
		if r_res.success:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
				get_node("/root/SoundManager").play_mana_spend()
			if r_res.replaced_realm != null:
				log_message("  ❖ Realm [b]" + card.name + "[/b] replaced [b]" + r_res.replaced_realm.name + "[/b]! (Evolutions: -1 ◈)")
			else:
				log_message("  ❖ Activated Realm [b]" + card.name + "[/b]! (Evolutions: -1 ◈)")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ " + r_res.error + "[/color]")
		return
		
	# If Little Dragon or Fierce Little Dragon -> summon directly
	if card.id == "little_dragon" or card.sub_type == "base_dragon":
		var beast = game_state.summon_little_dragon(0, hand_index)
		if beast:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_card_play()
				get_node("/root/SoundManager").play_mana_spend()
			log_message("  🐉 Summoned [b]" + beast.card_data.name + "[/b]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ Need 2 💧 & field space[/color]")
		return
		
	# If Compass -> open interactive Deck Search View for Element Stones!
	if card.id == "compass":
		if not game_state.get_mana(0).can_spend(RulesConfig.COMPASS_MANA_COST):
			log_message("[color=#e76f51]  ⚠️ Need 2 💧 for Compass[/color]")
			return
		var stones_in_deck: Array = []
		for c in game_state.get_deck(0):
			if c is CardData and c.card_type == "stone":
				stones_in_deck.append(c)
		if stones_in_deck.is_empty():
			var res_empty = game_state.cast_compass(0, hand_index)
			log_message("[color=#e76f51]  ⚠️ " + res_empty.details + "[/color]")
			refresh_full_ui()
			return
		open_deck_search_modal(
			"✦ COMPASS — SELECT AN ELEMENT STONE FROM YOUR DECK ✦",
			stones_in_deck,
			func(chosen: CardData):
				var cur_idx = game_state.get_hand(0).find(card)
				if cur_idx != -1:
					var res = game_state.cast_compass(0, cur_idx, chosen)
					if res.success:
						if has_node("/root/SoundManager"):
							get_node("/root/SoundManager").play_spell()
							get_node("/root/SoundManager").play_mana_spend()
						log_message("  ✦ Compass: " + res.details)
						refresh_full_ui()
		)
		return

	# If Draconic Tome -> open interactive Deck Search View for Dragon Beasts!
	if card.id == "draconic_tome":
		if not game_state.get_mana(0).can_spend(card.mana_cost):
			log_message("[color=#e76f51]  ⚠️ Need 2 💧 for Draconic Tome[/color]")
			return
		var dragons_in_deck: Array = []
		for c in game_state.get_deck(0):
			if c is CardData and c.card_type == "beast":
				dragons_in_deck.append(c)
		if dragons_in_deck.is_empty():
			var res_empty = game_state.cast_draconic_tome(0, hand_index)
			log_message("[color=#e76f51]  ⚠️ " + res_empty.details + "[/color]")
			refresh_full_ui()
			return
		open_deck_search_modal(
			"✦ DRACONIC TOME — SELECT A DRAGON BEAST FROM YOUR DECK ✦",
			dragons_in_deck,
			func(chosen: CardData):
				var cur_idx = game_state.get_hand(0).find(card)
				if cur_idx != -1:
					var res = game_state.cast_draconic_tome(0, cur_idx, chosen)
					if res.success:
						if has_node("/root/SoundManager"):
							get_node("/root/SoundManager").play_spell()
							get_node("/root/SoundManager").play_mana_spend()
						log_message("  ✦ Draconic Tome: " + res.details)
						refresh_full_ui()
		)
		return

	# If Ancient Insight -> Draw 2 cards immediately (1 Mana)
	if card.id == "ancient_insight":
		var res_ai = game_state.cast_ancient_insight(0, hand_index)
		if res_ai.success:
			_animate_hand_fan = true
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
				get_node("/root/SoundManager").play_mana_spend()
			log_message("  ✦ Ancient Insight: " + res_ai.details)
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ " + res_ai.error + "[/color]")
		return

	# If Draconic Calling -> Discard 1 card from hand, then search deck for up to 2 Dragon Beast cards
	if card.id == "draconic_calling":
		if not game_state.get_mana(0).can_spend(card.mana_cost):
			log_message("[color=#e76f51]  ⚠️ Need 2 💧 for Draconic Calling[/color]")
			return
		var other_hand_cards: Array = []
		var hand_ref: Array = game_state.get_hand(0)
		for idx_c in range(hand_ref.size()):
			if idx_c != hand_index:
				other_hand_cards.append(hand_ref[idx_c])
		if other_hand_cards.is_empty():
			log_message("[color=#e76f51]  ⚠️ Need at least 1 other card in hand to discard for Draconic Calling[/color]")
			return
		open_deck_search_modal(
			"✦ DRACONIC CALLING (STEP 1/3) — SELECT 1 CARD FROM HAND TO DISCARD ✦",
			other_hand_cards,
			func(discard_choice: CardData):
				var dragons_1: Array = []
				for dc in game_state.get_deck(0):
					if dc is CardData and dc.card_type == "beast":
						dragons_1.append(dc)
				if dragons_1.is_empty():
					var c_idx = game_state.get_hand(0).find(card)
					var d_idx = game_state.get_hand(0).find(discard_choice)
					if c_idx != -1:
						var res_no_d = game_state.cast_draconic_calling(0, c_idx, d_idx, [])
						log_message("[color=#e76f51]  ⚠️ " + res_no_d.details + "[/color]")
						refresh_full_ui()
					return
				open_deck_search_modal(
					"✦ DRACONIC CALLING (STEP 2/3) — SELECT 1ST DRAGON FROM DECK ✦",
					dragons_1,
					func(first_dragon: CardData):
						var dragons_2: Array = []
						var skipped_first := false
						for dc2 in game_state.get_deck(0):
							if dc2 is CardData and dc2.card_type == "beast":
								if dc2 == first_dragon and not skipped_first:
									skipped_first = true
									continue
								dragons_2.append(dc2)
						if dragons_2.is_empty():
							var c_idx = game_state.get_hand(0).find(card)
							var d_idx = game_state.get_hand(0).find(discard_choice)
							if c_idx != -1:
								var res1 = game_state.cast_draconic_calling(0, c_idx, d_idx, [first_dragon])
								if res1.success:
									_animate_hand_fan = true
									if has_node("/root/SoundManager"):
										get_node("/root/SoundManager").play_spell()
										get_node("/root/SoundManager").play_mana_spend()
									log_message("  ✦ Draconic Calling: " + res1.details)
								refresh_full_ui()
							return
						open_deck_search_modal(
							"✦ DRACONIC CALLING (STEP 3/3) — SELECT 2ND DRAGON FROM DECK ✦",
							dragons_2,
							func(second_dragon: CardData):
								var c_idx = game_state.get_hand(0).find(card)
								var d_idx = game_state.get_hand(0).find(discard_choice)
								if c_idx != -1:
									var res2 = game_state.cast_draconic_calling(0, c_idx, d_idx, [first_dragon, second_dragon])
									if res2.success:
										_animate_hand_fan = true
										if has_node("/root/SoundManager"):
											get_node("/root/SoundManager").play_spell()
											get_node("/root/SoundManager").play_mana_spend()
										log_message("  ✦ Draconic Calling: " + res2.details)
									refresh_full_ui()
						)
				)
		)
		return

	# If Soul Rebirth -> Put 1 Dragon Beast card from discard pile into hand (1 Mana)
	if card.id == "soul_rebirth":
		if not game_state.get_mana(0).can_spend(card.mana_cost):
			log_message("[color=#e76f51]  ⚠️ Need 1 💧 for Soul Rebirth[/color]")
			return
		var discard_dragons: Array = []
		for dc in game_state.get_discard(0):
			if dc is CardData and dc.card_type == "beast":
				discard_dragons.append(dc)
		if discard_dragons.is_empty():
			log_message("[color=#e76f51]  ⚠️ No Dragon Beast cards in your discard pile![/color]")
			return
		open_deck_search_modal(
			"✦ SOUL REBIRTH — RECOVER 1 DRAGON FROM YOUR DISCARD PILE ✦",
			discard_dragons,
			func(chosen_dragon: CardData):
				var cur_idx = game_state.get_hand(0).find(card)
				if cur_idx != -1:
					var res_sr = game_state.cast_soul_rebirth(0, cur_idx, chosen_dragon)
					if res_sr.success:
						_animate_hand_fan = true
						if has_node("/root/SoundManager"):
							get_node("/root/SoundManager").play_spell()
							get_node("/root/SoundManager").play_mana_spend()
						log_message("  ✦ Soul Rebirth: " + res_sr.details)
						refresh_full_ui()
		)
		return

	# If Elemental Convergence -> Search deck for up to 2 Element Stones
	if card.id == "elemental_convergence":
		if not game_state.get_mana(0).can_spend(card.mana_cost):
			log_message("[color=#e76f51]  ⚠️ Need 2 💧 for Elemental Convergence[/color]")
			return
		var stones_1: Array = []
		for sc in game_state.get_deck(0):
			if sc is CardData and sc.card_type == "stone":
				stones_1.append(sc)
		if stones_1.is_empty():
			var res_empty = game_state.cast_elemental_convergence(0, hand_index, [])
			log_message("[color=#e76f51]  ⚠️ " + res_empty.details + "[/color]")
			refresh_full_ui()
			return
		open_deck_search_modal(
			"✦ ELEMENTAL CONVERGENCE (1/2) — SELECT 1ST ELEMENT STONE ✦",
			stones_1,
			func(first_stone: CardData):
				var stones_2: Array = []
				var skipped := false
				for sc2 in game_state.get_deck(0):
					if sc2 is CardData and sc2.card_type == "stone":
						if sc2 == first_stone and not skipped:
							skipped = true
							continue
						stones_2.append(sc2)
				if stones_2.is_empty():
					var cur_idx = game_state.get_hand(0).find(card)
					if cur_idx != -1:
						var res_ec1 = game_state.cast_elemental_convergence(0, cur_idx, [first_stone])
						if res_ec1.success:
							_animate_hand_fan = true
							if has_node("/root/SoundManager"):
								get_node("/root/SoundManager").play_spell()
								get_node("/root/SoundManager").play_mana_spend()
							log_message("  ✦ Elemental Convergence: " + res_ec1.details)
						refresh_full_ui()
					return
				open_deck_search_modal(
					"✦ ELEMENTAL CONVERGENCE (2/2) — SELECT 2ND ELEMENT STONE ✦",
					stones_2,
					func(second_stone: CardData):
						var cur_idx = game_state.get_hand(0).find(card)
						if cur_idx != -1:
							var res_ec2 = game_state.cast_elemental_convergence(0, cur_idx, [first_stone, second_stone])
							if res_ec2.success:
								_animate_hand_fan = true
								if has_node("/root/SoundManager"):
									get_node("/root/SoundManager").play_spell()
									get_node("/root/SoundManager").play_mana_spend()
								log_message("  ✦ Elemental Convergence: " + res_ec2.details)
							refresh_full_ui()
				)
		)
		return

	# If Dragon's Hoard -> Draw 3 cards, discard 1 card (1 Mana)
	if card.id == "dragon_hoard":
		var res_dh = game_state.cast_dragon_hoard(0, hand_index)
		if res_dh.success:
			_animate_hand_fan = true
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
				get_node("/root/SoundManager").play_mana_spend()
			log_message("  ✦ Dragon's Hoard: " + res_dh.details)
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ " + res_dh.error + "[/color]")
		return

	# If Elemental Alchemy -> Discard 1 Stone from stone pile, search deck for 2 stones (1 Mana)
	if card.id == "elemental_alchemy":
		var res_ea = game_state.cast_elemental_alchemy(0, hand_index)
		if res_ea.success:
			_animate_hand_fan = true
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
				get_node("/root/SoundManager").play_mana_spend()
			log_message("  ✦ Elemental Alchemy: " + res_ea.details)
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ " + res_ea.error + "[/color]")
		return

	# If Draconic Resurgence -> Recycle 2 dragons from discard into deck, draw 1 card (1 Mana)
	if card.id == "draconic_resurgence":
		var res_dr = game_state.cast_draconic_resurgence(0, hand_index)
		if res_dr.success:
			_animate_hand_fan = true
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
				get_node("/root/SoundManager").play_mana_spend()
			log_message("  ✦ Draconic Resurgence: " + res_dr.details)
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ " + res_dr.error + "[/color]")
		return

	# If Call to Arms -> Search deck for 1 evolved Dragon card to hand (1 Mana)
	if card.id == "call_to_arms":
		var evolved_dragons: Array = []
		for dc in game_state.get_deck(0):
			if dc is CardData and dc.card_type == "beast" and dc.evolution_stage > 0:
				evolved_dragons.append(dc)
		if evolved_dragons.is_empty():
			var res_cta_empty = game_state.cast_call_to_arms(0, hand_index)
			log_message("[color=#e76f51]  ⚠️ " + res_cta_empty.details + "[/color]")
			refresh_full_ui()
			return
		open_deck_search_modal(
			"✦ CALL TO ARMS — SELECT AN EVOLVED DRAGON FROM YOUR DECK ✦",
			evolved_dragons,
			func(chosen_dragon: CardData):
				var cur_idx = game_state.get_hand(0).find(card)
				if cur_idx != -1:
					var res_cta = game_state.cast_call_to_arms(0, cur_idx, chosen_dragon)
					if res_cta.success:
						_animate_hand_fan = true
						if has_node("/root/SoundManager"):
							get_node("/root/SoundManager").play_spell()
							get_node("/root/SoundManager").play_mana_spend()
						log_message("  ✦ Dragon Call to Arms: " + res_cta.details)
					refresh_full_ui()
		)
		return

	# If Evolution card -> enter evolving mode
	if card.evolution_stage == 1:
		selected_hand_card_ui = card_ui
		current_action_mode = "evolving"
		prompt_banner.text = "Select a Little Dragon on your battlefield to Evolve into " + card.name + "!"
		prompt_banner.visible = true
		return
		
	# If Fusion card -> execute fusion directly if materials available
	if card.sub_type == "fusion_dragon":
		var fused = game_state.fuse_beasts(0, hand_index)
		if fused:
			if has_node("/root/SoundManager"):
				var sm = get_node("/root/SoundManager")
				sm.play_fusion()
				sm.play_stone_spend()
				if sm.has_method("play_voice"):
					sm.play_voice("vo_fusion")
			log_message("  ✨ Fused into [b]" + fused.card_data.name + "[/b]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ Missing fusion materials[/color]")
		return

	# If Transcendent card -> enter transcending mode
	if card.sub_type == "transcendent_dragon":
		selected_hand_card_ui = card_ui
		current_action_mode = "transcending"
		prompt_banner.text = "Select an elemental dragon on field to Transcend into " + card.name + " (5 matching stones)!"
		prompt_banner.visible = true
		return

	# If Ascended card -> enter ascending mode
	if card.sub_type == "ascended_dragon":
		selected_hand_card_ui = card_ui
		current_action_mode = "ascending"
		prompt_banner.text = "Select a fusion dragon on field to Ascend into " + card.name + " (3 stones of each element)!"
		prompt_banner.visible = true
		return

	# If God Dragon -> perform ritual from hand
	if card.id == "god_dragon":
		var res = game_state.summon_god_dragon(0, hand_index)
		if res.success:
			if has_node("/root/SoundManager"):
				var sm = get_node("/root/SoundManager")
				sm.play_fusion()
				sm.play_victory()
				if sm.has_method("play_voice"):
					sm.play_voice("vo_god_dragon")
			log_message("  ✨ [b]God Dragon[/b] descended!")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")
		return
		
	# If Spell card -> enter targeting mode
	if card.card_type == "spell":
		selected_hand_card_ui = card_ui
		current_action_mode = "targeting_spell"
		prompt_banner.text = "Select a target beast (or opponent) for " + card.name + "!"
		prompt_banner.visible = true
		return

func _on_player_field_clicked(card_ui: CardUI, field_index: int) -> void:
	var beast: BeastInstance = game_state.player_fields[0][field_index]
	
	if current_action_mode == "evolving":
		# Attempt evolution
		var hand = game_state.get_hand(0)
		var h_idx = hand.find(selected_hand_card_ui.card_data)
		if h_idx != -1:
			var success = game_state.evolve_beast(0, field_index, h_idx)
			if success:
				if has_node("/root/SoundManager"):
					var sm = get_node("/root/SoundManager")
					sm.play_evolution()
					sm.play_stone_spend()
					if sm.has_method("play_voice"):
						sm.play_voice("vo_evolution")
				log_message("  ✨ Evolved into [b]" + beast.card_data.name + "[/b]")
			else:
				log_message("[color=#e76f51]  ⚠️ Evolution failed[/color]")
		reset_action_mode()
		refresh_full_ui()
		return

	if current_action_mode == "transcending":
		var hand = game_state.get_hand(0)
		var h_idx = hand.find(selected_hand_card_ui.card_data)
		if h_idx != -1:
			var res_beast = game_state.transcend_beast(0, field_index, h_idx)
			if res_beast:
				if has_node("/root/SoundManager"):
					var sm = get_node("/root/SoundManager")
					sm.play_evolution()
					sm.play_stone_spend()
					if sm.has_method("play_voice"):
						sm.play_voice("vo_transcendence")
				log_message("  ✨ Transcended into [b]" + res_beast.card_data.name + "[/b]")
			else:
				log_message("[color=#e76f51]  ⚠️ Transcendence failed[/color]")
		reset_action_mode()
		refresh_full_ui()
		return

	if current_action_mode == "ascending":
		var hand = game_state.get_hand(0)
		var h_idx = hand.find(selected_hand_card_ui.card_data)
		if h_idx != -1:
			var res_beast = game_state.ascend_beast(0, field_index, h_idx)
			if res_beast:
				if has_node("/root/SoundManager"):
					var sm = get_node("/root/SoundManager")
					sm.play_fusion()
					sm.play_stone_spend()
					if sm.has_method("play_voice"):
						sm.play_voice("vo_ascension")
				log_message("  ✨ Ascended into [b]" + res_beast.card_data.name + "[/b]")
			else:
				log_message("[color=#e76f51]  ⚠️ Ascension failed[/color]")
		reset_action_mode()
		refresh_full_ui()
		return
		
	if current_action_mode == "targeting_spell" and selected_hand_card_ui:
		var hand = game_state.get_hand(0)
		var h_idx = hand.find(selected_hand_card_ui.card_data)
		if h_idx != -1:
			var res = game_state.cast_spell(0, h_idx, beast)
			if res.success:
				if has_node("/root/SoundManager"):
					get_node("/root/SoundManager").play_spell()
					get_node("/root/SoundManager").play_mana_spend()
				log_message("  🪄 Cast spell on [b]" + beast.card_data.name + "[/b]")
			else:
				log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")
		reset_action_mode()
		refresh_full_ui()
		return

	if current_action_mode == "targeting_ability":
		reset_action_mode()
	var can_atk = beast.can_attack(game_state.turn_number) and game_state.active_player_id == 0
	var has_activated_ability = beast.card_data.ability and beast.card_data.ability.get("trigger") == "activated"
	var can_abil = has_activated_ability and beast.can_use_ability() and game_state.active_player_id == 0

	if can_atk and can_abil:
		open_beast_action_modal(field_index)
		return
	elif can_atk:
		selected_field_beast_ui = card_ui
		current_action_mode = "attacking"
		prompt_banner.text = "Select an enemy beast to attack, or click enemy player for direct attack!"
		prompt_banner.visible = true
		return
	elif can_abil:
		_on_beast_ability_triggered(field_index)
		return

func open_beast_action_modal(field_index: int) -> void:
	if has_node("BeastActionModal"):
		get_node("BeastActionModal").queue_free()

	var beast: BeastInstance = game_state.player_fields[0][field_index]
	var ability = beast.card_data.ability if beast.card_data.ability else {}
	var abil_name = ability.get("name", "Ability")
	var abil_cost = _format_ability_cost(ability.get("cost", {}))
	var abil_desc = ability.get("description", "")

	var modal = ColorRect.new()
	modal.name = "BeastActionModal"
	modal.color = Color(0.02, 0.02, 0.06, 0.8)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.z_index = 50
	add_child(modal)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 250)
	panel.position = Vector2((1280 - 520) / 2.0, (720 - 250) / 2.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	modal.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			modal.queue_free()
	)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.16, 0.98)
	sb.border_color = Color(0.3, 0.8, 1.0, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	modal.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "✦ " + beast.card_data.name.to_upper() + " — CHOOSE ACTION ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "Attack Power: " + str(beast.get_attack()) + "  |  HP: " + str(beast.current_hp) + "/" + str(beast.max_hp) + "\nAbility: " + abil_name + " (Cost: " + abil_cost + ")\n" + abil_desc
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(desc)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var btn_attack = Button.new()
	btn_attack.text = "⚔️ Attack Enemy (" + str(beast.get_attack()) + " ATK)"
	btn_attack.custom_minimum_size = Vector2(170, 42)
	btn_attack.pressed.connect(func():
		modal.queue_free()
		selected_field_beast_ui = null
		for child in player_field_container.get_children():
			var c = child.get_child(0)
			if c is CardUI and c.beast_instance_ref == beast:
				selected_field_beast_ui = c
				break
		current_action_mode = "attacking"
		prompt_banner.text = "Select an enemy beast to attack, or click enemy player for direct attack!"
		prompt_banner.visible = true
	)
	hbox.add_child(btn_attack)

	var btn_abil = Button.new()
	btn_abil.text = "⚡ Activate Ability"
	btn_abil.custom_minimum_size = Vector2(170, 42)
	var check = AbilityResolver.can_activate_ability(beast, game_state.player_stones[0], game_state.player_hands[0])
	if not check.valid:
		btn_abil.disabled = true
		btn_abil.tooltip_text = check.error
	btn_abil.pressed.connect(func():
		modal.queue_free()
		_on_beast_ability_triggered(field_index)
	)
	hbox.add_child(btn_abil)

	var btn_cancel = Button.new()
	btn_cancel.text = "✖ Cancel"
	btn_cancel.custom_minimum_size = Vector2(80, 42)
	btn_cancel.pressed.connect(func():
		modal.queue_free()
	)
	hbox.add_child(btn_cancel)

func _on_beast_ability_triggered(field_index: int) -> void:
	if game_state.active_player_id != 0 or game_state.is_game_over:
		return
	if field_index < 0 or field_index >= game_state.player_fields[0].size():
		return
	var beast: BeastInstance = game_state.player_fields[0][field_index]
	var check = AbilityResolver.can_activate_ability(beast, game_state.player_stones[0], game_state.player_hands[0])
	if not check.valid:
		log_message("[color=#e76f51]  ⚠️ " + check.error + "[/color]")
		return

	var ability = beast.card_data.ability if beast.card_data.ability else {}
	var effect = ability.get("effect", "")
	var needs_target = effect in [
		"inflict_paralysis", "volcanic_storm", "emp_railgun",
		"shadow_siphon", "subzero_bite", "magma_eruption", "storm_dive", "searing_cyclone"
	]

	if needs_target and game_state.player_fields[1].size() > 0:
		current_action_mode = "targeting_ability"
		selected_ability_beast_index = field_index
		prompt_banner.text = "⚡ Select target enemy beast for " + beast.card_data.name + "'s " + ability.get("name", "Ability") + " (Right-Click or ESC to Cancel)!"
		prompt_banner.visible = true
	else:
		if needs_target and game_state.player_fields[1].is_empty() and effect in ["inflict_paralysis", "volcanic_storm", "magma_eruption", "storm_dive"]:
			log_message("[color=#e76f51]  ⚠️ No opposing Beasts on battlefield to target![/color]")
			return

		var res = game_state.activate_beast_ability(0, field_index)
		if res.success:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
			log_message("  ⚡ [b]" + beast.card_data.name + "[/b]: " + res.details)
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")

func _on_player_field_right_clicked(card_ui: CardUI, field_index: int) -> void:
	if current_action_mode != "none":
		reset_action_mode()
		refresh_full_ui()
		return
	if game_state.active_player_id != 0 or game_state.is_game_over:
		return
	_on_beast_ability_triggered(field_index)

func _on_opponent_field_clicked(card_ui: CardUI, field_index: int) -> void:
	if current_action_mode == "targeting_ability" and selected_ability_beast_index != -1:
		var target = game_state.player_fields[1][field_index]
		var beast = game_state.player_fields[0][selected_ability_beast_index]
		var res = game_state.activate_beast_ability(0, selected_ability_beast_index, [target])
		if res.success:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
			log_message("  ⚡ [b]" + beast.card_data.name + "[/b]: " + res.details)
		else:
			log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")
		reset_action_mode()
		refresh_full_ui()
		return

	if current_action_mode == "attacking" and selected_field_beast_ui:
		var attacker = selected_field_beast_ui.beast_instance_ref
		var defender = game_state.player_fields[1][field_index]
		var res = game_state.attack_beast(attacker, defender)
		if res.success:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_attack()
				get_node("/root/SoundManager").play_damage()
			log_message("  ⚔️ [b]" + res.get("attacker_name", attacker.card_data.name) + "[/b] ➔ " + str(res.get("damage_dealt", attacker.get_attack())) + " dmg")
		else:
			log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")
		reset_action_mode()
		refresh_full_ui()
		return

	if current_action_mode == "targeting_spell" and selected_hand_card_ui:
		var target = game_state.player_fields[1][field_index]
		var hand = game_state.get_hand(0)
		var h_idx = hand.find(selected_hand_card_ui.card_data)
		if h_idx != -1:
			var res = game_state.cast_spell(0, h_idx, target)
			if res.success:
				if has_node("/root/SoundManager"):
					get_node("/root/SoundManager").play_spell()
					get_node("/root/SoundManager").play_mana_spend()
				log_message("  🪄 Cast spell on [b]" + target.card_data.name + "[/b]")
			else:
				log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")
		reset_action_mode()
		refresh_full_ui()
		return

func _on_opponent_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_action_mode == "attacking" and selected_field_beast_ui:
			var attacker = selected_field_beast_ui.beast_instance_ref
			var res = game_state.attack_player_direct(attacker)
			if res.success:
				if has_node("/root/SoundManager"):
					var sm = get_node("/root/SoundManager")
					sm.play_attack()
					sm.play_damage()
					if not game_state.is_game_over and sm.has_method("play_voice"):
						sm.play_voice("vo_direct_attack")
				log_message("  ⚔️ [b]" + res.get("attacker_name", attacker.card_data.name) + "[/b] ➔ " + str(res.get("damage_dealt", attacker.get_attack())) + " dmg")
			else:
				log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")
			reset_action_mode()
			refresh_full_ui()
		elif current_action_mode == "targeting_spell" and selected_hand_card_ui:
			var hand = game_state.get_hand(0)
			var h_idx = hand.find(selected_hand_card_ui.card_data)
			if h_idx != -1:
				var res = game_state.cast_spell(0, h_idx, null)
				if res.success:
					if has_node("/root/SoundManager"):
						get_node("/root/SoundManager").play_spell()
						get_node("/root/SoundManager").play_damage()
					log_message("  🪄 Cast spell on Opponent")
				else:
					log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")
			reset_action_mode()
			refresh_full_ui()

func reset_action_mode() -> void:
	current_action_mode = "none"
	selected_hand_card_ui = null
	selected_field_beast_ui = null
	selected_ability_beast_index = -1
	prompt_banner.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if has_node("BeastActionModal"):
				get_node("BeastActionModal").queue_free()
			if current_action_mode != "none":
				reset_action_mode()
				refresh_full_ui()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if has_node("BeastActionModal"):
				get_node("BeastActionModal").queue_free()
			if has_node("DeckSearchModal"):
				get_node("DeckSearchModal").queue_free()
			if current_action_mode != "none":
				reset_action_mode()
				refresh_full_ui()

func _on_end_turn_pressed() -> void:
	if game_state.active_player_id == 0 and not game_state.is_game_over:
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_ui_click()
		reset_action_mode()
		game_state.end_turn()
		refresh_full_ui()
		
		if is_vs_ai:
			# Execute AI turn with a small timer
			var timer = get_tree().create_timer(0.6)
			timer.timeout.connect(func():
				var logs = ai_controller.execute_turn()
				for l in logs:
					log_message("[color=#a8dadc]  " + l + "[/color]")
				refresh_full_ui()
			)

func _on_turn_started(turn: int, player_id: int) -> void:
	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		sm.play_turn_change()
		sm.play_mana_refresh()
		if turn > 1 and sm.has_method("play_voice"):
			sm.play_voice("vo_your_turn" if player_id == 0 else "vo_enemy_turn")
	log_message("[color=#7bdff2]◆ Turn " + str(turn) + " — " + ("You" if player_id == 0 else "Opponent") + "[/color]")
	update_hud()

func _on_turn_ended(turn: int, player_id: int) -> void:
	update_hud()

func _on_card_drawn(player_id: int, card: CardData) -> void:
	if player_id == 0:
		log_message("  ❖ Drew [b]" + card.name + "[/b]")

func _on_beast_summoned(player_id: int, beast: BeastInstance) -> void:
	call_deferred("play_card_summon_vfx", player_id, beast, false)

func _on_beast_evolved(player_id: int, beast: BeastInstance) -> void:
	call_deferred("play_card_summon_vfx", player_id, beast, true)

func _on_beasts_fused(player_id: int, beast: BeastInstance) -> void:
	call_deferred("play_card_summon_vfx", player_id, beast, true)

func _on_beast_transcended(player_id: int, beast: BeastInstance) -> void:
	call_deferred("play_card_summon_vfx", player_id, beast, true)

func _on_beast_ascended(player_id: int, beast: BeastInstance) -> void:
	call_deferred("play_card_summon_vfx", player_id, beast, true)

func _on_god_dragon_summoned(player_id: int, beast: BeastInstance) -> void:
	call_deferred("play_card_summon_vfx", player_id, beast, true)

func play_card_summon_vfx(player_id: int, beast: BeastInstance, is_major_transformation: bool = false) -> void:
	if not is_inside_tree() or beast == null or beast.card_data == null:
		return
	var field_arr: Array = game_state.get_field(player_id)
	var slot_idx: int = field_arr.find(beast)
	if slot_idx == -1:
		slot_idx = maxi(0, field_arr.size() - 1)
	var field_container: HBoxContainer = player_field_container if player_id == 0 else opponent_field_container
	var target_center := Vector2(640, 420 if player_id == 0 else 210)
	var target_card_ui: CardUI = null
	if slot_idx >= 0 and slot_idx < field_container.get_child_count():
		var slot_holder: Control = field_container.get_child(slot_idx)
		target_center = slot_holder.get_global_rect().get_center()
		if slot_holder.get_child_count() > 0 and slot_holder.get_child(0) is CardUI:
			target_card_ui = slot_holder.get_child(0)

	var el_key := beast.card_data.element.to_lower()
	var vfx_color: Color = ELEMENT_UI_COLORS.get(el_key, Color(1.0, 0.85, 0.35))
	if beast.card_data.id == "god_dragon":
		vfx_color = Color(1.0, 0.92, 0.40)

	# Animate the summoned CardUI dropping in with an energetic scale pop and flash
	if target_card_ui != null:
		var rest_pos := target_card_ui.position
		var rest_scale := target_card_ui.base_scale
		target_card_ui.scale = rest_scale * (1.42 if is_major_transformation else 1.28)
		target_card_ui.position = rest_pos + Vector2(0, -28)
		target_card_ui.modulate = Color(1.8, 1.7, 1.5, 1.0)
		var c_tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		c_tw.tween_property(target_card_ui, "scale", rest_scale, 0.30)
		c_tw.parallel().tween_property(target_card_ui, "position", rest_pos, 0.26)
		c_tw.parallel().tween_property(target_card_ui, "modulate", Color.WHITE, 0.32)

	var vfx_layer := Control.new()
	vfx_layer.name = "SummonVFXLayer"
	vfx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vfx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vfx_layer.z_index = 42
	add_child(vfx_layer)

	# Expanding Elemental Shockwave Ring 1 & 2
	for r_i in range(2 if is_major_transformation else 1):
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var init_sz := Vector2(44, 44)
		ring.size = init_sz
		ring.pivot_offset = init_sz * 0.5
		ring.position = target_center - ring.pivot_offset
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.28)
		r_sb.border_color = vfx_color.lightened(0.35)
		r_sb.set_border_width_all(4)
		r_sb.set_corner_radius_all(120)
		r_sb.shadow_color = Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.85)
		r_sb.shadow_size = 14
		ring.add_theme_stylebox_override("panel", r_sb)
		vfx_layer.add_child(ring)

		var final_sz := Vector2(230, 230) if is_major_transformation else Vector2(180, 180)
		var r_tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		r_tw.tween_interval(float(r_i) * 0.08)
		r_tw.tween_property(ring, "size", final_sz, 0.36)
		r_tw.parallel().tween_property(ring, "position", target_center - final_sz * 0.5, 0.36)
		r_tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.36)

	# Radial Elemental Sparks
	var spark_count := 16 if is_major_transformation else 10
	for s_i in range(spark_count):
		var spark := Panel.new()
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.size = Vector2(10, 10)
		spark.pivot_offset = Vector2(5, 5)
		spark.position = target_center - Vector2(5, 5)
		var s_sb := StyleBoxFlat.new()
		s_sb.bg_color = vfx_color.lightened(0.4)
		s_sb.set_corner_radius_all(5)
		s_sb.shadow_color = vfx_color
		s_sb.shadow_size = 6
		spark.add_theme_stylebox_override("panel", s_sb)
		vfx_layer.add_child(spark)

		var angle := (float(s_i) / float(spark_count)) * TAU
		var radius := (125.0 if is_major_transformation else 92.0) + float((s_i % 3) * 14)
		var offset := Vector2(cos(angle), sin(angle)) * radius
		var s_tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		s_tw.tween_property(spark, "position", target_center - Vector2(5, 5) + offset, 0.38)
		s_tw.parallel().tween_property(spark, "scale", Vector2(0.2, 0.2), 0.38)
		s_tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.38)

	var clean_tw := create_tween()
	clean_tw.tween_interval(0.50)
	clean_tw.tween_callback(vfx_layer.queue_free)

func _on_combat_resolved(res: Dictionary) -> void:
	pass

func _on_game_ended(winner: int, reason: String) -> void:
	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		if winner == 0:
			sm.play_victory()
			if sm.has_method("play_voice"):
				sm.play_voice("vo_victory")
		else:
			sm.play_defeat()
			if sm.has_method("play_voice"):
				sm.play_voice("vo_defeat")
	var msg = "[b][color=#e63946]GAME OVER! Player " + str(winner + 1) + " WINS! (" + reason + ")[/color][/b]"
	log_message(msg)
	if prompt_banner:
		prompt_banner.text = "GAME OVER! Player " + str(winner + 1) + " WINS!"
		prompt_banner.visible = true
	show_game_end_screen(winner, reason)

func _pick_mvp_dragon_card(winner_id: int) -> CardData:
	var best_card: CardData = null
	var best_score: int = -1
	if game_state != null:
		# Check winner's field first
		for b in game_state.get_field(winner_id):
			if b is BeastInstance and b.card_data != null:
				var sc: int = b.get_attack() * 3 + b.max_hp + b.card_data.evolution_stage * 15
				if sc > best_score:
					best_score = sc
					best_card = b.card_data
		# Fallback to player's hand or discard or deck
		if best_card == null:
			for pool in [game_state.get_hand(0), game_state.get_discard(0), game_state.get_deck(0)]:
				for c in pool:
					if c is CardData and c.card_type == "beast":
						var sc2: int = c.attack * 3 + c.max_hp + c.evolution_stage * 15
						if sc2 > best_score:
							best_score = sc2
							best_card = c
		if best_card == null and game_state.card_db.has("fire_dragon"):
			best_card = game_state.card_db["fire_dragon"]
	return best_card

func show_game_end_screen(winner: int, reason: String) -> Control:
	var existing = get_node_or_null("GameEndScreen")
	if existing:
		existing.free()

	var is_victory: bool = (winner == 0)
	var accent_col: Color = Color(1.0, 0.84, 0.28, 1.0) if is_victory else Color(0.92, 0.28, 0.34, 1.0)
	var border_col: Color = Color(0.98, 0.80, 0.24, 1.0) if is_victory else Color(0.82, 0.22, 0.28, 1.0)

	var overlay := ColorRect.new()
	overlay.name = "GameEndScreen"
	overlay.color = Color(0.02, 0.02, 0.05, 0.90) if is_victory else Color(0.05, 0.01, 0.03, 0.92)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 95
	add_child(overlay)

	# Radial aura glow behind modal
	var aura := Panel.new()
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.size = Vector2(760, 480)
	aura.position = Vector2(260, 120)
	var aura_sb := StyleBoxFlat.new()
	aura_sb.bg_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.12)
	aura_sb.set_corner_radius_all(240)
	aura_sb.shadow_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.38)
	aura_sb.shadow_size = 64
	aura.add_theme_stylebox_override("panel", aura_sb)
	overlay.add_child(aura)

	# Main Ornate Victory / Defeat Card Panel
	var panel := PanelContainer.new()
	panel.name = "EndModalPanel"
	panel.custom_minimum_size = Vector2(860, 520)
	panel.position = Vector2(210, 100)
	panel.pivot_offset = Vector2(430, 260)
	var p_sb := StyleBoxFlat.new()
	p_sb.bg_color = Color(0.06, 0.07, 0.14, 0.98) if is_victory else Color(0.09, 0.05, 0.09, 0.98)
	p_sb.border_color = border_col
	p_sb.set_border_width_all(4)
	p_sb.set_corner_radius_all(16)
	p_sb.shadow_color = Color(0, 0, 0, 0.9)
	p_sb.shadow_size = 28
	p_sb.content_margin_left = 28
	p_sb.content_margin_right = 28
	p_sb.content_margin_top = 22
	p_sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", p_sb)
	overlay.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	panel.add_child(root_vbox)

	# 1. Header Crest & Title Banner
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 4)
	root_vbox.add_child(header_box)

	var title_lbl := Label.new()
	title_lbl.name = "VictoryTitleLabel"
	title_lbl.text = "🏆 VICTORY! — DRAGON MASTER TRIUMPHANT 🏆" if is_victory else "💀 DEFEAT — FALLEN IN THE ARENA 💀"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", accent_col.lightened(0.18))
	header_box.add_child(title_lbl)

	var reason_lbl := Label.new()
	reason_lbl.name = "ReasonSubtitleLabel"
	reason_lbl.text = ("You conquered the Elemental Arena! (" + reason + ")") if is_victory else ("Player " + str(winner + 1) + " claimed victory. (" + reason + ")")
	reason_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_lbl.add_theme_font_size_override("font_size", 14)
	reason_lbl.add_theme_color_override("font_color", Color(0.86, 0.88, 0.95))
	header_box.add_child(reason_lbl)

	# Divider line
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = Color(border_col.r, border_col.g, border_col.b, 0.55)
	root_vbox.add_child(div)

	# 2. Center Content: Left = MVP Dragon Card Showcase, Right = Match Summary & Rewards
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 28)
	body_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(body_hbox)

	# Left Column: MVP Dragon CardUI Pedestal
	var mvp_vbox := VBoxContainer.new()
	mvp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mvp_vbox.add_theme_constant_override("separation", 6)
	body_hbox.add_child(mvp_vbox)

	var mvp_tag := Label.new()
	mvp_tag.text = "✦ CHAMPION DRAGON ✦" if is_victory else "✦ ARENA MVP DRAGON ✦"
	mvp_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp_tag.add_theme_font_size_override("font_size", 13)
	mvp_tag.add_theme_color_override("font_color", accent_col)
	mvp_vbox.add_child(mvp_tag)

	var mvp_holder := Control.new()
	mvp_holder.name = "MVPDragonHolder"
	mvp_holder.custom_minimum_size = Vector2(180, 250)
	mvp_vbox.add_child(mvp_holder)

	var mvp_card_data: CardData = _pick_mvp_dragon_card(winner)
	if mvp_card_data != null and card_ui_prefab != null:
		var mvp_ui: CardUI = card_ui_prefab.instantiate()
		mvp_ui.name = "MVPDragonCardUI"
		mvp_ui.base_scale = Vector2(0.90, 0.90)
		mvp_ui.hover_zoom = false
		mvp_holder.add_child(mvp_ui)
		mvp_ui.setup(mvp_card_data, use_legacy_art)
		mvp_ui.scale = Vector2(0.90, 0.90)
		mvp_ui.position = Vector2(0, 0)

	# Right Column: Match Statistics & Honours
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sp_sb := StyleBoxFlat.new()
	sp_sb.bg_color = Color(0.09, 0.11, 0.20, 0.95)
	sp_sb.border_color = Color(border_col.r, border_col.g, border_col.b, 0.65)
	sp_sb.set_border_width_all(2)
	sp_sb.set_corner_radius_all(12)
	sp_sb.content_margin_left = 20
	sp_sb.content_margin_right = 20
	sp_sb.content_margin_top = 16
	sp_sb.content_margin_bottom = 16
	stats_panel.add_theme_stylebox_override("panel", sp_sb)
	body_hbox.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.name = "StatsVBox"
	stats_vbox.add_theme_constant_override("separation", 10)
	stats_panel.add_child(stats_vbox)

	var stats_header := Label.new()
	stats_header.text = "📜 DUEL CHRONICLE & STATISTICS"
	stats_header.add_theme_font_size_override("font_size", 16)
	stats_header.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	stats_vbox.add_child(stats_header)

	var turns_val: int = game_state.turn_number if game_state else 1
	var p_hp: int = game_state.player_hp[0] if game_state else 0
	var o_hp: int = game_state.player_hp[1] if game_state else 0
	var p_stones: int = game_state.get_stones(0).get_total_stones() if game_state else 0
	var p_field_cnt: int = game_state.get_field(0).size() if game_state else 0
	var realm_name: String = game_state.active_realm.name if (game_state and game_state.active_realm != null) else "None"

	var stat_rows := [
		["⏳ Turns Elapsed", "Turn " + str(turns_val)],
		["♥ Final Life Points", "You: " + str(p_hp) + " HP   |   Foe: " + str(o_hp) + " HP"],
		["◈ Element Stones Harnessed", str(p_stones) + " Stones in Pile"],
		["🐉 Surviving Dragons on Field", str(p_field_cnt) + " Active Beast(s)"],
		["❖ Active Elemental Realm", realm_name],
		["🎁 ArenaSpoils", "✦ +1 Elemental Booster Pack Ready!" if is_victory else "✦ Consolation Booster Pack Available!"]
	]

	for row_pair in stat_rows:
		var r_h := HBoxContainer.new()
		var k_lbl := Label.new()
		k_lbl.text = str(row_pair[0])
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_lbl.add_theme_font_size_override("font_size", 13)
		k_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94))
		r_h.add_child(k_lbl)

		var v_lbl := Label.new()
		v_lbl.text = str(row_pair[1])
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_lbl.add_theme_font_size_override("font_size", 13)
		v_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
		r_h.add_child(v_lbl)
		stats_vbox.add_child(r_h)

	# 3. Bottom Action Buttons Row
	var btn_row := HBoxContainer.new()
	btn_row.name = "ActionButtonsRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	root_vbox.add_child(btn_row)

	var rematch_btn := Button.new()
	rematch_btn.name = "PlayAgainButton"
	rematch_btn.text = "⚔ Play Again (Rematch)"
	rematch_btn.custom_minimum_size = Vector2(220, 44)
	var rm_sb := StyleBoxFlat.new()
	rm_sb.bg_color = Color(0.14, 0.42, 0.24, 0.96)
	rm_sb.border_color = Color(0.45, 0.95, 0.62, 1.0)
	rm_sb.set_border_width_all(2)
	rm_sb.set_corner_radius_all(8)
	rematch_btn.add_theme_stylebox_override("normal", rm_sb)
	rematch_btn.add_theme_font_size_override("font_size", 15)
	rematch_btn.pressed.connect(func():
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_ui_click()
		var new_battle = load("res://scenes/battle.tscn").instantiate()
		new_battle.is_vs_ai = is_vs_ai
		new_battle.selected_starter_deck_index = selected_starter_deck_index
		get_tree().root.add_child(new_battle)
		queue_free()
	)
	btn_row.add_child(rematch_btn)

	var packs_btn := Button.new()
	packs_btn.name = "OpenPacksButton"
	packs_btn.text = "🎁 Open Booster Packs"
	packs_btn.custom_minimum_size = Vector2(220, 44)
	var pk_sb := StyleBoxFlat.new()
	pk_sb.bg_color = Color(0.42, 0.28, 0.08, 0.96)
	pk_sb.border_color = Color(1.0, 0.84, 0.28, 1.0)
	pk_sb.set_border_width_all(2)
	pk_sb.set_corner_radius_all(8)
	packs_btn.add_theme_stylebox_override("normal", pk_sb)
	packs_btn.add_theme_font_size_override("font_size", 15)
	packs_btn.pressed.connect(func():
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_ui_click()
		get_tree().change_scene_to_file("res://scenes/pack_opening.tscn")
		queue_free()
	)
	btn_row.add_child(packs_btn)

	var menu_btn := Button.new()
	menu_btn.name = "ReturnMainMenuButton"
	menu_btn.text = "🏰 Return to Main Menu"
	menu_btn.custom_minimum_size = Vector2(220, 44)
	var mn_sb := StyleBoxFlat.new()
	mn_sb.bg_color = Color(0.16, 0.18, 0.30, 0.96)
	mn_sb.border_color = Color(0.65, 0.75, 0.95, 1.0)
	mn_sb.set_border_width_all(2)
	mn_sb.set_corner_radius_all(8)
	menu_btn.add_theme_stylebox_override("normal", mn_sb)
	menu_btn.add_theme_font_size_override("font_size", 15)
	menu_btn.pressed.connect(func():
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_ui_click()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		queue_free()
	)
	btn_row.add_child(menu_btn)

	# Entrance pop-in & rising celebration particles when inside scene tree
	if is_inside_tree():
		panel.scale = Vector2(0.82, 0.82)
		panel.modulate.a = 0.0
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.34)
		tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.24)

		for p_i in range(18):
			var spark := Panel.new()
			spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spark.size = Vector2(10, 10)
			var start_x := 180.0 + float((p_i * 57) % 920)
			var start_y := 640.0 - float((p_i * 29) % 120)
			spark.position = Vector2(start_x, start_y)
			var sp_style := StyleBoxFlat.new()
			sp_style.bg_color = accent_col.lightened(0.35)
			sp_style.set_corner_radius_all(5)
			sp_style.shadow_color = accent_col
			sp_style.shadow_size = 8
			spark.add_theme_stylebox_override("panel", sp_style)
			overlay.add_child(spark)

			var p_tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			p_tw.tween_interval(float(p_i) * 0.04)
			p_tw.tween_property(spark, "position", Vector2(start_x + sin(float(p_i)) * 45.0, start_y - 260.0), 1.4)
			p_tw.parallel().tween_property(spark, "modulate:a", 0.0, 1.4)

	return overlay


func _on_legacy_toggle(toggled_on: bool) -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	use_legacy_art = toggled_on
	refresh_full_ui()

func _on_menu_pressed() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func log_message(text: String) -> void:
	if log_label:
		log_label.append_text(text + "\n")

func _on_deck_shuffled(player_id: int) -> void:
	play_deck_shuffle_animation(player_id)

func play_deck_shuffle_animation(player_id: int) -> void:
	var key = ("player" if player_id == 0 else "enemy") + "_Deck"
	var deck_cell: Control = pile_cells.get(key)
	if not deck_cell or not is_inside_tree():
		return
	var origin = deck_cell.get_global_rect().get_center()
	var card_back_tex = load("res://assets/art/card_back.png") if ResourceLoader.exists("res://assets/art/card_back.png") else null

	var fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.z_index = 45
	add_child(fx_layer)

	var num_cards = 8
	for i in range(num_cards):
		var sp = TextureRect.new()
		sp.texture = card_back_tex
		sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sp.size = Vector2(54, 75)
		sp.pivot_offset = Vector2(27, 37.5)
		sp.position = origin - sp.pivot_offset
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.add_child(sp)

		var side = -1.0 if (i % 2 == 0) else 1.0
		var spread = Vector2(side * (28.0 + float(i) * 4.5), -14.0 + float(i % 3) * 6.0)
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(float(i) * 0.025)
		tw.tween_property(sp, "position", origin - sp.pivot_offset + spread, 0.14)
		tw.parallel().tween_property(sp, "rotation_degrees", side * (16.0 + float(i) * 2.0), 0.14)
		tw.tween_property(sp, "position", origin - sp.pivot_offset + Vector2(-spread.x * 0.45, -4.0), 0.12)
		tw.parallel().tween_property(sp, "rotation_degrees", -side * 8.0, 0.12)
		tw.tween_property(sp, "position", origin - sp.pivot_offset, 0.14)
		tw.parallel().tween_property(sp, "rotation_degrees", 0.0, 0.14)

	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		if sm.has_method("play_deck_shuffle"):
			sm.play_deck_shuffle()
		else:
			sm.play_card_hover()

	var clean_tw = create_tween()
	clean_tw.tween_interval(0.68)
	clean_tw.tween_callback(fx_layer.queue_free)

func open_deck_search_modal(title_text: String, cards_to_show: Array, on_select: Callable = Callable(), shuffle_on_close: bool = false) -> void:
	if has_node("DeckSearchModal"):
		get_node("DeckSearchModal").queue_free()

	var modal = ColorRect.new()
	modal.name = "DeckSearchModal"
	modal.color = Color(0.02, 0.02, 0.06, 0.88)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.z_index = 50
	add_child(modal)

	var panel = PanelContainer.new()
	panel.position = Vector2(90, 56)
	panel.custom_minimum_size = Vector2(1100, 608)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.13, 0.98)
	sb.border_color = Color(0.95, 0.78, 0.28, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	modal.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var top_h = HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 12)
	vbox.add_child(top_h)

	var title_lbl = Label.new()
	title_lbl.text = title_text + "  (" + str(cards_to_show.size()) + " Cards)"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	top_h.add_child(title_lbl)

	var search_input = LineEdit.new()
	search_input.placeholder_text = "⌕ Filter cards..."
	search_input.custom_minimum_size = Vector2(210, 32)
	search_input.clear_button_enabled = true
	top_h.add_child(search_input)

	var shuffle_btn = Button.new()
	shuffle_btn.text = "↻ Shuffle Deck"
	shuffle_btn.custom_minimum_size = Vector2(140, 32)
	top_h.add_child(shuffle_btn)

	var close_btn = Button.new()
	close_btn.text = "✖ Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	top_h.add_child(close_btn)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	# Display a randomized/sorted copy when inspecting deck so hidden draw order is not spoiled
	var display_list: Array = cards_to_show.duplicate()
	if shuffle_on_close:
		display_list.shuffle()

	var populate_grid = func(q: String):
		for ch in grid.get_children():
			ch.queue_free()
		var clean_q = q.strip_edges().to_lower()
		for c in display_list:
			if not (c is CardData):
				continue
			if clean_q != "" and not (c.name.to_lower().contains(clean_q) or c.element.to_lower().contains(clean_q) or c.card_type.to_lower().contains(clean_q)):
				continue
			var slot = Control.new()
			slot.custom_minimum_size = Vector2(150, 212)
			var cui: CardUI = card_ui_prefab.instantiate()
			cui.base_scale = Vector2(0.74, 0.74)
			slot.add_child(cui)
			cui.setup(c, use_legacy_art)
			cui.pivot_offset = Vector2.ZERO
			cui.scale = Vector2(0.74, 0.74)
			cui.position = Vector2(1, 2)
			var card_ref: CardData = c
			cui.card_clicked.connect(func(_clicked):
				if on_select.is_valid():
					modal.queue_free()
					on_select.call(card_ref)
				else:
					_on_any_card_hovered(cui, true)
			)
			grid.add_child(slot)

	populate_grid.call("")
	search_input.text_changed.connect(func(txt: String): populate_grid.call(txt))

	shuffle_btn.pressed.connect(func():
		game_state.get_deck(0).shuffle()
		display_list.shuffle()
		populate_grid.call(search_input.text)
		play_deck_shuffle_animation(0)
		log_message("  ↻ Shuffled your Deck.")
	)

	close_btn.pressed.connect(func():
		if shuffle_on_close:
			game_state.get_deck(0).shuffle()
			play_deck_shuffle_animation(0)
		modal.queue_free()
	)

func _show_start_of_match_coin_flip(player_deck: Array, ai_deck: Array) -> void:
	if has_node("CoinFlipOverlay"):
		get_node("CoinFlipOverlay").queue_free()

	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		if sm.has_method("play_voice"):
			sm.play_voice("vo_coin_toss")

	var overlay = ColorRect.new()
	overlay.name = "CoinFlipOverlay"
	overlay.color = Color(0.02, 0.02, 0.06, 0.90)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 60
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 480)
	panel.position = Vector2(320, 120)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.98)
	sb.border_color = Color(0.95, 0.78, 0.28, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "✦ ANCIENT ELEMENTAL COIN TOSS ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "HEADS (Solar God Dragon Crest) = YOU GO FIRST\nTAILS (Abyssal Shadow Dragon Crest) = OPPONENT GOES FIRST"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.84, 0.84, 0.92))
	vbox.add_child(sub)

	var coin_holder = Control.new()
	coin_holder.custom_minimum_size = Vector2(256, 256)
	coin_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(coin_holder)

	var coin_tex = TextureRect.new()
	var heads_tex = load("res://assets/art/coin_heads.png") if ResourceLoader.exists("res://assets/art/coin_heads.png") else null
	var tails_tex = load("res://assets/art/coin_tails.png") if ResourceLoader.exists("res://assets/art/coin_tails.png") else null
	coin_tex.texture = heads_tex
	coin_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_tex.size = Vector2(240, 240)
	coin_tex.position = Vector2(8, 8)
	coin_tex.pivot_offset = Vector2(120, 120)
	coin_holder.add_child(coin_tex)

	var status_lbl = Label.new()
	status_lbl.text = "Click below to toss the Elemental Coin & shuffle both decks!"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 15)
	status_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.65))
	vbox.add_child(status_lbl)

	var toss_btn = Button.new()
	toss_btn.text = "✦ Toss Elemental Coin"
	toss_btn.custom_minimum_size = Vector2(240, 44)
	toss_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.36, 0.22, 0.06, 0.98)
	btn_sb.border_color = Color(1.0, 0.84, 0.32, 1.0)
	btn_sb.set_border_width_all(2)
	btn_sb.set_corner_radius_all(8)
	toss_btn.add_theme_stylebox_override("normal", btn_sb)
	toss_btn.add_theme_stylebox_override("hover", btn_sb)
	toss_btn.add_theme_font_size_override("font_size", 16)
	vbox.add_child(toss_btn)

	toss_btn.pressed.connect(func():
		toss_btn.disabled = true
		if has_node("/root/SoundManager"):
			var sm = get_node("/root/SoundManager")
			if sm.has_method("play_coin_flip"):
				sm.play_coin_flip()
			else:
				sm.play_fusion()
		var player_wins_toss: bool = (randi() % 2 == 0)
		var total_half_turns = 8 if player_wins_toss else 9
		status_lbl.text = "Tossing Elemental Coin..."

		var tw = create_tween()
		for step in range(total_half_turns):
			var next_is_tails = (step % 2 == 0)
			tw.tween_property(coin_tex, "scale:x", 0.04, 0.08)
			tw.tween_callback(func():
				coin_tex.texture = tails_tex if next_is_tails else heads_tex
				if has_node("/root/SoundManager"):
					get_node("/root/SoundManager").play_card_hover()
			)
			tw.tween_property(coin_tex, "scale:x", 1.0, 0.08)

		tw.tween_callback(func():
			if player_wins_toss:
				coin_tex.texture = heads_tex
				status_lbl.text = "☀ HEADS — SOLAR GOD DRAGON CREST! You Go First!"
				status_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.50))
				log_message("[color=#52b788]◆ Coin Toss: HEADS (Solar Crest) — You take Turn 1![/color]")
				game_state.start_game(player_deck, ai_deck, 0)
				if has_node("/root/SoundManager") and get_node("/root/SoundManager").has_method("play_voice"):
					get_node("/root/SoundManager").play_voice("vo_heads_first")
			else:
				coin_tex.texture = tails_tex
				status_lbl.text = "☾ TAILS — ABYSSAL SHADOW CREST! Opponent Goes First!"
				status_lbl.add_theme_color_override("font_color", Color(0.82, 0.58, 1.0))
				log_message("[color=#c77dff]◆ Coin Toss: TAILS (Abyssal Crest) — Opponent takes Turn 1![/color]")
				game_state.start_game(player_deck, ai_deck, 1)
				if has_node("/root/SoundManager") and get_node("/root/SoundManager").has_method("play_voice"):
					get_node("/root/SoundManager").play_voice("vo_tails_second")
			refresh_full_ui()
			play_deck_shuffle_animation(0)
			play_deck_shuffle_animation(1)
		)
		tw.tween_interval(1.15)
		tw.tween_property(overlay, "modulate:a", 0.0, 0.28)
		tw.tween_callback(func():
			overlay.queue_free()
			if not player_wins_toss and is_vs_ai and game_state.active_player_id == 1:
				var ai_timer = get_tree().create_timer(0.55)
				ai_timer.timeout.connect(func():
					var logs = ai_controller.execute_turn()
					for l in logs:
						log_message("[color=#a8dadc]  " + l + "[/color]")
					refresh_full_ui()
				)
		)
	)
