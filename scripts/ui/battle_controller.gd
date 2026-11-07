class_name BattleController
extends Control

@export var is_vs_ai: bool = true
@export var use_legacy_art: bool = false

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
	# Start match
	log_message("[color=#ffd166]◆ Duel Started — 30 ❤️ | 5 💧[/color]")
	game_state.start_game()
	refresh_full_ui()

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
	var zone_tooltips = {"Deck": "Deck", "Discard": "Discard Pile", "Banish": "Banish Zone"}
	var zone_symbols = {"Deck": "🃏 0", "Discard": "💀 0", "Banish": "🌀 0"}
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
			var icon = TextureRect.new()
			icon.custom_minimum_size = Vector2(0, 44)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
			v.add_child(icon)
			v.add_child(lbl)
			cell.add_child(v)
			piles_grid.add_child(cell)
			pile_labels[owner + "_" + zone] = lbl

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
		pile_labels["player_Deck"].text = "🃏 " + str(game_state.player_decks[0].size())
		pile_labels["player_Discard"].text = "💀 " + str(game_state.player_discards[0].size())
		pile_labels["player_Banish"].text = "🌀 0"
		pile_labels["enemy_Deck"].text = "🃏 " + str(game_state.player_decks[1].size())
		pile_labels["enemy_Discard"].text = "💀 " + str(game_state.player_discards[1].size())
		pile_labels["enemy_Banish"].text = "🌀 0"

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
			elif card.id == "compass" and mana_mgr.can_spend(RulesConfig.COMPASS_MANA_COST):
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
		
	# If Compass -> cast directly
	if card.id == "compass":
		var res = game_state.cast_compass(0, hand_index)
		if res.success:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
				get_node("/root/SoundManager").play_mana_spend()
			log_message("  🧭 Compass: " + res.details)
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]  ⚠️ " + res.error + "[/color]")
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
		log_message("  🃏 Drew [b]" + card.name + "[/b]")

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
