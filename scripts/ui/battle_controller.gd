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
@onready var player_mana_label: Label = $HUD/PlayerPanel/ManaLabel
@onready var player_mana_bar: ProgressBar = $HUD/PlayerPanel/ManaBar
@onready var player_stones_container: HBoxContainer = $HUD/PlayerPanel/StonesContainer

@onready var opponent_hp_label: Label = $HUD/OpponentPanel/HPLabel
@onready var opponent_mana_label: Label = $HUD/OpponentPanel/ManaLabel
@onready var opponent_mana_bar: ProgressBar = $HUD/OpponentPanel/ManaBar
@onready var opponent_stones_container: HBoxContainer = $HUD/OpponentPanel/StonesContainer

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
	player_hp_label.text = "HP: " + str(game_state.player_hp[0]) + "/30"
	var p_mana = game_state.get_mana(0).current_mana
	player_mana_label.text = "MANA: " + str(p_mana) + "/5"
	player_mana_bar.value = p_mana
	refresh_stones_display(0, player_stones_container)
	
	# Opponent HUD
	opponent_hp_label.text = "HP: " + str(game_state.player_hp[1]) + "/30"
	var op_mana = game_state.get_mana(1).current_mana
	opponent_mana_label.text = "MANA: " + str(op_mana) + "/5"
	opponent_mana_bar.value = op_mana
	refresh_stones_display(1, opponent_stones_container)
	
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
			log_message("[color=#2a9d8f]You placed " + card.name + " into your Stone Pile.[/color]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]Already placed a Stone this turn (limit 1/turn).[/color]")
		return
		
	# If Little Dragon -> summon directly
	if card.id == "little_dragon":
		var beast = game_state.summon_little_dragon(0, hand_index)
		if beast:
			log_message("[color=#e9c46a]Summoned Little Dragon for 2 Mana.[/color]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]Cannot summon Little Dragon (requires 2 Mana and field space).[/color]")
		return
		
	# If Compass -> cast directly
	if card.id == "compass":
		var res = game_state.cast_compass(0, hand_index)
		if res.success:
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
			log_message("[color=#ffb703]ELEMENTAL FUSION! " + card.name + " emerges onto the battlefield![/color]")
			refresh_full_ui()
		else:
			log_message("[color=#e76f51]Cannot fuse " + card.name + ". Required materials not on field.[/color]")
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
				log_message("[color=#48cae4]DRAGON EVOLUTION! Little Dragon evolved into " + beast.card_data.name + "![/color]")
			else:
				log_message("[color=#e76f51]Evolution failed. Insufficient stones or invalid target.[/color]")
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
				log_message("[color=#00b4d8]Spell cast on " + target.card_data.name + "![/color]")
			else:
				log_message("[color=#e76f51]Spell failed: " + res.error + "[/color]")
		reset_action_mode()
		refresh_full_ui()
		return

func reset_action_mode() -> void:
	current_action_mode = "none"
	selected_hand_card_ui = null
	selected_field_beast_ui = null
	prompt_banner.visible = false

func _on_end_turn_pressed() -> void:
	if game_state.active_player_id == 0 and not game_state.is_game_over:
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
	var msg = "[b][color=#e63946]GAME OVER! Player " + str(winner + 1) + " WINS! (" + reason + ")[/color][/b]"
	log_message(msg)
	prompt_banner.text = "GAME OVER! Player " + str(winner + 1) + " WINS!"
	prompt_banner.visible = true

func _on_legacy_toggle(toggled_on: bool) -> void:
	use_legacy_art = toggled_on
	refresh_full_ui()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func log_message(text: String) -> void:
	if log_label:
		log_label.append_text(text + "\n")
