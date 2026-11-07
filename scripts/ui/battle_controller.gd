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

# UI Nodes
const FIELD_CARD_SCALE: float = 0.64
const HAND_CARD_SCALE: float = 0.6
const PREVIEW_CARD_SCALE: float = 1.15
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

@onready var preview_holder: Control = $SelectedPanel/PreviewHolder
var preview_card: CardUI = null

@onready var player_hand_container: HBoxContainer = $HandArea/HandContainer
@onready var player_field_container: HBoxContainer = $PlayerField/BeastSlots
@onready var opponent_field_container: HBoxContainer = $OpponentField/BeastSlots

@onready var turn_label: Label = $TurnPanel/TurnLabel
@onready var active_player_label: Label = $TurnPanel/ActivePlayerLabel
@onready var end_turn_button: Button = $TurnPanel/EndTurnButton
@onready var log_label: RichTextLabel = $LogPanel/LogText
@onready var prompt_banner: Label = $PromptBanner

@onready var legacy_toggle_button: Button = $LegacyToggle
@onready var menu_button: Button = $MenuButton

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
	game_state.combat_resolved.connect(_on_combat_resolved)
	game_state.deck_shuffled.connect(_on_deck_shuffled)
	game_state.game_ended.connect(_on_game_ended)
	
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	if legacy_toggle_button:
		legacy_toggle_button.toggled.connect(_on_legacy_toggle)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
		
	if opponent_panel:
		opponent_panel.gui_input.connect(_on_opponent_panel_input)
	var opp_field = $OpponentField
	if opp_field:
		opp_field.gui_input.connect(_on_opponent_panel_input)
		
	_build_static_ui()
	
	var player_deck = GameState.load_starter_deck_ids_by_index(selected_starter_deck_index)
	var ai_deck_idx = (selected_starter_deck_index + 3) % 6
	var ai_deck = GameState.load_starter_deck_ids_by_index(ai_deck_idx)
	
	log_message("[color=#ffd166]◆ Duel Initialized — 30 ♥ | 5 💧[/color]")
	game_state.start_game(player_deck, ai_deck, 0)
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

func _update_mana_pips(container: HBoxContainer, current: int) -> void:
	if container.get_child_count() != RulesConfig.MAX_NORMAL_MANA:
		for c in container.get_children():
			c.queue_free()
		for i in range(RulesConfig.MAX_NORMAL_MANA):
			var p = Panel.new()
			p.custom_minimum_size = Vector2(22, 22)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(p)
	for i in range(container.get_child_count()):
		var p: Panel = container.get_child(i)
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(11)
		sb.set_border_width_all(2)
		if i < current:
			sb.bg_color = Color(0.2, 0.65, 1.0)
			sb.border_color = Color(0.75, 0.95, 1.0)
			sb.shadow_color = Color(0.3, 0.7, 1.0, 0.6)
			sb.shadow_size = 4
		else:
			sb.bg_color = Color(0.18, 0.18, 0.22)
			sb.border_color = Color(0.45, 0.45, 0.5)
		p.add_theme_stylebox_override("panel", sb)

func update_hud() -> void:
	var p_hp = game_state.player_hp[0]
	player_hp_label.text = str(p_hp)
	var p_mana = game_state.get_mana(0).current_mana
	player_mana_label.text = "MANA  " + str(p_mana) + "/" + str(RulesConfig.MAX_NORMAL_MANA)
	_update_mana_pips(player_mana_pips, p_mana)
	refresh_stones_display(0, player_stones_container)

	var op_hp = game_state.player_hp[1]
	opponent_hp_label.text = str(op_hp)
	var op_mana = game_state.get_mana(1).current_mana
	opponent_mana_label.text = "MANA  " + str(op_mana) + "/" + str(RulesConfig.MAX_NORMAL_MANA)
	_update_mana_pips(opponent_mana_pips, op_mana)
	refresh_stones_display(1, opponent_stones_container)

	if pile_labels.has("player_Deck"):
		pile_labels["player_Deck"].text = "❖ " + str(game_state.player_decks[0].size())
		pile_labels["player_Discard"].text = "✖ " + str(game_state.player_discards[0].size())
		pile_labels["player_Banish"].text = "✦ 0"
		pile_labels["enemy_Deck"].text = "❖ " + str(game_state.player_decks[1].size())
		pile_labels["enemy_Discard"].text = "✖ " + str(game_state.player_discards[1].size())
		pile_labels["enemy_Banish"].text = "✦ 0"

	turn_label.text = "TURN " + str(game_state.turn_number)
	if game_state.active_player_id == 0:
		active_player_label.text = "YOUR TURN"
		active_player_label.modulate = Color(0.3, 1.0, 0.4)
		end_turn_button.disabled = false
	else:
		active_player_label.text = "OPPONENT'S TURN" if is_vs_ai else "PLAYER 2'S TURN"
		active_player_label.modulate = Color(1.0, 0.4, 0.4)
		end_turn_button.disabled = is_vs_ai

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
		return
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
	var sep = -18
	if hand.size() > 1:
		sep = mini(-18, int((avail - cw * hand.size()) / float(hand.size() - 1)))
	player_hand_container.add_theme_constant_override("separation", sep)

	var mid = (hand.size() - 1) * 0.5
	var first_card_ui: CardUI = null
	for i in range(hand.size()):
		var card: CardData = hand[i]
		var card_ui: CardUI = card_ui_prefab.instantiate()
		player_hand_container.add_child(_wrap_card(card_ui, HAND_CARD_SCALE))
		card_ui.setup(card, use_legacy_art)
		if card_ui.has_method("set_compact"):
			card_ui.set_compact(true)
		var offset_from_mid = float(i) - mid
		card_ui.rotation_degrees = offset_from_mid * 2.2
		card_ui.position.y += abs(offset_from_mid) * 3.5
		if first_card_ui == null:
			first_card_ui = card_ui

		var playable = false
		if game_state.active_player_id == 0:
			if card.card_type == "stone" and stone_mgr.can_place_stone():
				playable = true
			elif card.id == "little_dragon" and mana_mgr.can_spend(2) and field.size() < 4:
				playable = true
			elif card.evolution_stage == 1:
				for b in field:
					if EvolutionEngine.can_evolve(b, card, stone_mgr).valid:
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
			elif (card.id == "compass" or card.id == "draconic_tome") and mana_mgr.can_spend(card.mana_cost):
				playable = true
			elif card.card_type == "spell" and mana_mgr.can_spend(card.mana_cost):
				playable = true

		card_ui.set_playable(playable)
		var h_idx = i
		card_ui.card_clicked.connect(func(c): _on_hand_card_clicked(c, h_idx))

	if preview_card == null and first_card_ui != null:
		_on_any_card_hovered(first_card_ui, true)

func refresh_fields() -> void:
	for child in player_field_container.get_children():
		child.queue_free()
	for i in range(game_state.player_fields[0].size()):
		var b: BeastInstance = game_state.player_fields[0][i]
		var c_ui: CardUI = card_ui_prefab.instantiate()
		player_field_container.add_child(_wrap_card(c_ui, FIELD_CARD_SCALE))
		c_ui.setup_from_beast(b)
		if c_ui.has_method("set_compact"):
			c_ui.set_compact(true)
		c_ui.set_attack_ready(b.can_attack(game_state.turn_number) and game_state.active_player_id == 0)
		if b.stun_turns > 0:
			c_ui.set_status_display("stun", b.stun_turns)
		elif b.freeze_turns > 0:
			c_ui.set_status_display("freeze", b.freeze_turns)
		var f_idx = i
		c_ui.card_clicked.connect(func(c): _on_player_field_clicked(c, f_idx))
		c_ui.card_right_clicked.connect(func(c): _on_player_field_right_clicked(c, f_idx))

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
		var f_idx = i
		c_ui.card_clicked.connect(func(c): _on_opponent_field_clicked(c, f_idx))

func _on_hand_card_clicked(card_ui: CardUI, hand_index: int) -> void:
	if game_state.active_player_id != 0 or game_state.is_game_over:
		return
		
	var card = card_ui.card_data
	
	# If Stone card -> place directly
	if card.card_type == "stone":
		if game_state.play_stone_from_hand(0, hand_index):
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_stone_place()
			log_message("  💎 Placed [b]" + card.name + "[/b]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ Limit 1 Stone/turn[/color]")
		return
		
	# If Little Dragon -> summon directly
	if card.id == "little_dragon":
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
				get_node("/root/SoundManager").play_fusion()
				get_node("/root/SoundManager").play_stone_spend()
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
				get_node("/root/SoundManager").play_fusion()
				get_node("/root/SoundManager").play_victory()
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
					get_node("/root/SoundManager").play_evolution()
					get_node("/root/SoundManager").play_stone_spend()
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
					get_node("/root/SoundManager").play_evolution()
					get_node("/root/SoundManager").play_stone_spend()
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
					get_node("/root/SoundManager").play_fusion()
					get_node("/root/SoundManager").play_stone_spend()
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

	# Select beast to attack with
	if beast.can_attack(game_state.turn_number) and game_state.active_player_id == 0:
		selected_field_beast_ui = card_ui
		current_action_mode = "attacking"
		prompt_banner.text = "Select an enemy beast to attack, or click enemy player for direct attack!"
		prompt_banner.visible = true
		return

func _on_player_field_right_clicked(card_ui: CardUI, field_index: int) -> void:
	# Right click activates beast special ability
	if game_state.active_player_id != 0 or game_state.is_game_over:
		return
	var beast = game_state.player_fields[0][field_index]
	var res = game_state.activate_beast_ability(0, field_index)
	if res.success:
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_spell()
		log_message("  ⚡ [b]" + beast.card_data.name + "[/b]: " + res.details)
		refresh_full_ui()
	else:
		log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")

func _on_opponent_field_clicked(card_ui: CardUI, field_index: int) -> void:
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
					get_node("/root/SoundManager").play_attack()
					get_node("/root/SoundManager").play_damage()
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
	prompt_banner.visible = false

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
		get_node("/root/SoundManager").play_turn_change()
		get_node("/root/SoundManager").play_mana_refresh()
	log_message("[color=#7bdff2]◆ Turn " + str(turn) + " — " + ("You" if player_id == 0 else "Opponent") + "[/color]")
	update_hud()

func _on_turn_ended(turn: int, player_id: int) -> void:
	update_hud()

func _on_card_drawn(player_id: int, card: CardData) -> void:
	if player_id == 0:
		log_message("  ❖ Drew [b]" + card.name + "[/b]")

func _on_beast_summoned(player_id: int, beast: BeastInstance) -> void:
	pass

func _on_beast_evolved(player_id: int, beast: BeastInstance) -> void:
	pass

func _on_beasts_fused(player_id: int, beast: BeastInstance) -> void:
	pass

func _on_combat_resolved(res: Dictionary) -> void:
	pass

func _on_game_ended(winner: int, reason: String) -> void:
	if has_node("/root/SoundManager"):
		if winner == 0:
			get_node("/root/SoundManager").play_victory()
		else:
			get_node("/root/SoundManager").play_defeat()
	var msg = "[b][color=#e63946]GAME OVER! Player " + str(winner + 1) + " WINS! (" + reason + ")[/color][/b]"
	log_message(msg)
	prompt_banner.text = "GAME OVER! Player " + str(winner + 1) + " WINS!"
	prompt_banner.visible = true

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
		get_node("/root/SoundManager").play_card_hover()

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
	coin_holder.custom_minimum_size = Vector2(240, 240)
	coin_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(coin_holder)

	var coin_tex = TextureRect.new()
	var heads_tex = load("res://assets/art/coin_heads.png") if ResourceLoader.exists("res://assets/art/coin_heads.png") else null
	var tails_tex = load("res://assets/art/coin_tails.png") if ResourceLoader.exists("res://assets/art/coin_tails.png") else null
	coin_tex.texture = heads_tex
	coin_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_tex.size = Vector2(220, 220)
	coin_tex.position = Vector2(10, 10)
	coin_tex.pivot_offset = Vector2(110, 110)
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
			get_node("/root/SoundManager").play_fusion()
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
			else:
				coin_tex.texture = tails_tex
				status_lbl.text = "☾ TAILS — ABYSSAL SHADOW CREST! Opponent Goes First!"
				status_lbl.add_theme_color_override("font_color", Color(0.82, 0.58, 1.0))
				log_message("[color=#c77dff]◆ Coin Toss: TAILS (Abyssal Crest) — Opponent takes Turn 1![/color]")
				game_state.start_game(player_deck, ai_deck, 1)
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
