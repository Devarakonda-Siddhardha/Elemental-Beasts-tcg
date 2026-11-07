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
@onready var player_hp_label: Label = $HUD/PlayerPanel/HPLabel
@onready var player_hp_bar: ProgressBar = $HUD/PlayerPanel/HPBar
@onready var player_mana_label: Label = $HUD/PlayerPanel/ManaLabel
@onready var player_mana_bar: ProgressBar = $HUD/PlayerPanel/ManaBar
@onready var player_stones_container: HBoxContainer = $HUD/PlayerPanel/StonesContainer

@onready var opponent_panel: Panel = $HUD/OpponentPanel
@onready var opponent_hp_label: Label = $HUD/OpponentPanel/HPLabel
@onready var opponent_hp_bar: ProgressBar = $HUD/OpponentPanel/HPBar
@onready var opponent_mana_label: Label = $HUD/OpponentPanel/ManaLabel
@onready var opponent_mana_bar: ProgressBar = $HUD/OpponentPanel/ManaBar
@onready var opponent_stones_container: HBoxContainer = $HUD/OpponentPanel/StonesContainer

@onready var player_deck_count_label: Label = $Board/PilesLeft/PlayerDeckBox/Label
@onready var player_discard_count_label: Label = $Board/PilesLeft/PlayerDiscardBox/Label
@onready var player_discard_preview: TextureRect = $Board/PilesLeft/PlayerDiscardBox/Slot/Preview

@onready var enemy_deck_count_label: Label = $Board/PilesLeft/EnemyDeckBox/Label
@onready var enemy_discard_count_label: Label = $Board/PilesLeft/EnemyDiscardBox/Label
@onready var enemy_discard_preview: TextureRect = $Board/PilesLeft/EnemyDiscardBox/Slot/Preview

@onready var player_hand_container: HBoxContainer = $Board/PlayerHandScroll/HandContainer
@onready var player_field_container: HBoxContainer = $Board/PlayerField/BeastSlots
@onready var opponent_field_container: HBoxContainer = $Board/OpponentField/BeastSlots

@onready var turn_label: Label = $HUD/TurnInfo/TurnLabel
@onready var active_player_label: Label = $HUD/TurnInfo/ActivePlayerLabel
@onready var end_turn_button: Button = $HUD/TurnInfo/EndTurnButton
@onready var log_label: RichTextLabel = $HUD/LogPanel/LogText
@onready var prompt_banner: Label = $HUD/PromptBanner

@onready var legacy_toggle_button: CheckButton = $HUD/TopBar/LegacyToggle
@onready var menu_button: Button = $HUD/TopBar/MenuButton

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
	var opp_field = $Board/OpponentField
	if opp_field:
		opp_field.gui_input.connect(_on_opponent_panel_input)
		
	# Start match
	game_state.start_game()
	log_message("[color=#ffd166]Welcome to Elemental Beasts TCG - Legacy Reborn![/color]")
	log_message("Both players start with 30 HP and receive 5 Mana refreshed each turn.")
	refresh_full_ui()

func refresh_full_ui() -> void:
	update_hud()
	refresh_player_hand()
	refresh_fields()

func update_hud() -> void:
	# Player 0 HUD
	var p_hp = game_state.player_hp[0]
	player_hp_label.text = "HP: " + str(p_hp) + "/30"
	if player_hp_bar:
		player_hp_bar.value = p_hp
	var p_mana = game_state.get_mana(0).current_mana
	player_mana_label.text = "MANA: " + str(p_mana) + "/5"
	player_mana_bar.value = p_mana
	refresh_stones_display(0, player_stones_container)
	
	# Opponent HUD
	var op_hp = game_state.player_hp[1]
	opponent_hp_label.text = "HP: " + str(op_hp) + "/30"
	if opponent_hp_bar:
		opponent_hp_bar.value = op_hp
	var op_mana = game_state.get_mana(1).current_mana
	opponent_mana_label.text = "MANA: " + str(op_mana) + "/5"
	opponent_mana_bar.value = op_mana
	refresh_stones_display(1, opponent_stones_container)
	
	# Piles Tracking
	if player_deck_count_label:
		player_deck_count_label.text = "DECK: " + str(game_state.player_decks[0].size())
	if enemy_deck_count_label:
		enemy_deck_count_label.text = "ENEMY DECK: " + str(game_state.player_decks[1].size())
		
	if player_discard_count_label:
		var p_disc = game_state.player_discards[0]
		player_discard_count_label.text = "DISCARD: " + str(p_disc.size())
		if player_discard_preview and not p_disc.is_empty():
			var top_card: CardData = p_disc[-1]
			var tpath = CardUI.get_template_path(top_card.element, top_card.card_type, top_card.sub_type)
			if ResourceLoader.exists(tpath):
				player_discard_preview.texture = load(tpath)
				
	if enemy_discard_count_label:
		var op_disc = game_state.player_discards[1]
		enemy_discard_count_label.text = "DISCARD: " + str(op_disc.size())
		if enemy_discard_preview and not op_disc.is_empty():
			var top_card: CardData = op_disc[-1]
			var tpath = CardUI.get_template_path(top_card.element, top_card.card_type, top_card.sub_type)
			if ResourceLoader.exists(tpath):
				enemy_discard_preview.texture = load(tpath)
	
	# Turn Info
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
		if count > 0:
			var badge = HBoxContainer.new()
			var icon = TextureRect.new()
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_path = "res://assets/icons/" + el + ".png"
			if ResourceLoader.exists(icon_path):
				icon.texture = load(icon_path)
			var lbl = Label.new()
			lbl.text = "x" + str(count)
			badge.add_child(icon)
			badge.add_child(lbl)
			container.add_child(badge)

func refresh_player_hand() -> void:
	for child in player_hand_container.get_children():
		child.queue_free()
		
	var hand = game_state.get_hand(0)
	var mana_mgr = game_state.get_mana(0)
	var stone_mgr = game_state.get_stones(0)
	var field = game_state.get_field(0)
	
	for i in range(hand.size()):
		var card: CardData = hand[i]
		var card_ui: CardUI = card_ui_prefab.instantiate()
		player_hand_container.add_child(card_ui)
		card_ui.setup(card, use_legacy_art)
		
		# Determine playability
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

func refresh_fields() -> void:
	# Player 0 Field
	for child in player_field_container.get_children():
		child.queue_free()
	for i in range(game_state.player_fields[0].size()):
		var b: BeastInstance = game_state.player_fields[0][i]
		var c_ui: CardUI = card_ui_prefab.instantiate()
		player_field_container.add_child(c_ui)
		c_ui.setup_from_beast(b)
		c_ui.set_attack_ready(b.can_attack(game_state.turn_number) and game_state.active_player_id == 0)
		if b.stun_turns > 0:
			c_ui.set_status_display("stun", b.stun_turns)
		elif b.freeze_turns > 0:
			c_ui.set_status_display("freeze", b.freeze_turns)
		var f_idx = i
		c_ui.card_clicked.connect(func(c): _on_player_field_clicked(c, f_idx))
		c_ui.card_right_clicked.connect(func(c): _on_player_field_right_clicked(c, f_idx))
		
	# Opponent Field
	for child in opponent_field_container.get_children():
		child.queue_free()
	for i in range(game_state.player_fields[1].size()):
		var b: BeastInstance = game_state.player_fields[1][i]
		var c_ui: CardUI = card_ui_prefab.instantiate()
		opponent_field_container.add_child(c_ui)
		c_ui.setup_from_beast(b)
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
			log_message("[color=#2a9d8f]You placed " + card.name + " into your Stone Pile.[/color]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]Already placed a Stone this turn (limit 1/turn).[/color]")
		return
		
	# If Little Dragon -> summon directly
	if card.id == "little_dragon":
		var beast = game_state.summon_little_dragon(0, hand_index)
		if beast:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_card_play()
				get_node("/root/SoundManager").play_mana_spend()
			log_message("[color=#e9c46a]Summoned Little Dragon for 2 Mana.[/color]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]Cannot summon Little Dragon (requires 2 Mana and field space).[/color]")
		return
		
	# If Compass -> cast directly
	if card.id == "compass":
		var res = game_state.cast_compass(0, hand_index)
		if res.success:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_spell()
				get_node("/root/SoundManager").play_mana_spend()
			log_message("[color=#f4a261]Compass: " + res.details + "[/color]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]Compass failed: " + res.error + "[/color]")
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
			log_message("[color=#ffb703]ELEMENTAL FUSION! " + card.name + " emerges onto the battlefield![/color]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]Cannot fuse " + card.name + ". Required materials not on field.[/color]")
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
			log_message("[color=#ffd700][b]THE GOD DRAGON DESCENDS![/b] Genesis Roar banishes all enemy beasts and deals 10 direct damage![/color]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]God Dragon Ritual failed: " + res.error + "[/color]")
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
				log_message("[color=#48cae4]DRAGON EVOLUTION! Little Dragon evolved into " + beast.card_data.name + "![/color]")
			else:
				log_message("[color=#e76f51]Evolution failed. Insufficient stones or invalid target.[/color]")
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
				log_message("[color=#e0aaff]TRANSCENDENCE ACHIEVED! " + res_beast.card_data.name + " descends with pure elemental majesty![/color]")
			else:
				log_message("[color=#e76f51]Transcendence failed. Insufficient stones or invalid target.[/color]")
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
				log_message("[color=#ffd166]DRAGON ASCENSION! " + res_beast.card_data.name + " transcends mortal limits![/color]")
			else:
				log_message("[color=#e76f51]Ascension failed. Insufficient stones or invalid target.[/color]")
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
				log_message("[color=#00b4d8]Spell cast on " + beast.card_data.name + "![/color]")
			else:
				log_message("[color=#e76f51]Spell failed: " + res.error + "[/color]")
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
		log_message("[color=#ffb703]" + beast.card_data.name + " activated ability: " + res.details + "[/color]")
		refresh_full_ui()
	else:
		log_message("[color=#e76f51]Ability failed: " + res.error + "[/color]")

func _on_opponent_field_clicked(card_ui: CardUI, field_index: int) -> void:
	if current_action_mode == "attacking" and selected_field_beast_ui:
		var attacker = selected_field_beast_ui.beast_instance_ref
		var defender = game_state.player_fields[1][field_index]
		var res = game_state.attack_beast(attacker, defender)
		if res.success:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_attack()
				get_node("/root/SoundManager").play_damage()
			log_message("[color=#e63946]Combat: " + res.details + "[/color]")
		else:
			log_message("[color=#e76f51]Attack failed: " + res.error + "[/color]")
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
				log_message("[color=#00b4d8]Spell cast on " + target.card_data.name + "![/color]")
			else:
				log_message("[color=#e76f51]Spell failed: " + res.error + "[/color]")
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
				log_message("[color=#e63946]DIRECT HIT: " + res.details + "[/color]")
			else:
				log_message("[color=#e76f51]Direct attack failed: " + res.error + "[/color]")
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
					log_message("[color=#00b4d8]Spell cast directly on Opponent![/color]")
				else:
					log_message("[color=#e76f51]Spell failed: " + res.error + "[/color]")
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
					log_message("[color=#a8dadc]" + l + "[/color]")
				refresh_full_ui()
			)

func _on_turn_started(turn: int, player_id: int) -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_turn_change()
		get_node("/root/SoundManager").play_mana_refresh()
	log_message("[b]Turn " + str(turn) + " started for Player " + str(player_id + 1) + " (Mana refreshed to 5)[/b]")
	update_hud()

func _on_turn_ended(turn: int, player_id: int) -> void:
	update_hud()

func _on_card_drawn(player_id: int, card: CardData) -> void:
	if player_id == 0:
		log_message("You drew " + card.name + ".")

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
