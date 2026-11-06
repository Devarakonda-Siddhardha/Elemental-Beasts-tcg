class_name GameState
extends RefCounted

signal turn_started(turn: int, active_player: int)
signal turn_ended(turn: int, active_player: int)
signal card_drawn(player_id: int, card: CardData)
signal card_played(player_id: int, card: CardData)
signal beast_summoned(player_id: int, beast: BeastInstance)
signal beast_evolved(player_id: int, beast: BeastInstance)
signal beasts_fused(player_id: int, fused_beast: BeastInstance)
signal spell_cast(player_id: int, card: CardData)
signal combat_resolved(result: Dictionary)
signal game_ended(winner_id: int, reason: String)

var turn_number: int = 1
var active_player_id: int = 0 # 0 = Player, 1 = Opponent
var is_game_over: bool = false
var winner_id: int = -1

# Player states (0 and 1)
var player_hp: Array[int] = [RulesConfig.STARTING_PLAYER_HP, RulesConfig.STARTING_PLAYER_HP]
var player_mana: Array[ManaManager] = [ManaManager.new(), ManaManager.new()]
var player_stones: Array[StoneManager] = [StoneManager.new(), StoneManager.new()]
var player_decks: Array[Array] = [[], []]
var player_hands: Array[Array] = [[], []]
var player_discards: Array[Array] = [[], []]
var player_fields: Array[Array] = [[], []]

var card_db: Dictionary = {}

func _init() -> void:
	card_db = CardData.load_database()

func get_field(player_id: int) -> Array:
	return player_fields[player_id]

func get_hand(player_id: int) -> Array:
	return player_hands[player_id]

func get_deck(player_id: int) -> Array:
	return player_decks[player_id]

func get_discard(player_id: int) -> Array:
	return player_discards[player_id]

func get_mana(player_id: int) -> ManaManager:
	return player_mana[player_id]

func get_stones(player_id: int) -> StoneManager:
	return player_stones[player_id]

func start_game(deck0_ids: Array = [], deck1_ids: Array = []) -> void:
	is_game_over = false
	winner_id = -1
	turn_number = 1
	active_player_id = 0
	
	for p in range(2):
		player_hp[p] = RulesConfig.STARTING_PLAYER_HP
		player_mana[p].reset()
		player_stones[p].clear()
		player_hands[p].clear()
		player_discards[p].clear()
		player_fields[p].clear()
		
		# Build deck
		var deck_ids = deck0_ids if p == 0 else deck1_ids
		if deck_ids.is_empty():
			deck_ids = get_default_deck_ids()
			
		player_decks[p].clear()
		for cid in deck_ids:
			if card_db.has(cid):
				# Create fresh copy
				var orig = card_db[cid]
				var copy = CardData.from_dict({
					"id": orig.id,
					"name": orig.name,
					"card_type": orig.card_type,
					"sub_type": orig.sub_type,
					"element": orig.element,
					"mana_cost": orig.mana_cost,
					"stone_cost": orig.stone_cost,
					"hp": orig.hp,
					"max_hp": orig.max_hp,
					"attack": orig.attack,
					"ability": orig.ability,
					"evolution_stage": orig.evolution_stage,
					"evolves_from": orig.evolves_from,
					"fusion_materials": orig.fusion_materials,
					"description": orig.description,
					"status": orig.status
				})
				player_decks[p].append(copy)
				
		player_decks[p].shuffle()
		
		# Draw initial hand (5 cards)
		for i in range(RulesConfig.STARTING_HAND_SIZE):
			draw_card(p)
			
	# Start Turn 1 for Player 0
	start_turn()

func get_default_deck_ids() -> Array[String]:
	return [
		"little_dragon", "little_dragon", "little_dragon", "little_dragon",
		"wind_dragon", "wind_dragon",
		"shadow_dragon", "shadow_dragon",
		"fire_dragon", "fire_dragon",
		"lightning_dragon", "lightning_dragon",
		"volcovolt_dragon", "spark_wraith_dragon", "techno_frost_dragon",
		"compass", "compass",
		"lightning_strike", "lightning_strike",
		"dragon_elixir", "elemental_shield",
		"fire_stone", "fire_stone", "lightning_stone", "lightning_stone",
		"shadow_stone", "shadow_stone", "wind_stone", "wind_stone", "ice_stone"
	]

func draw_card(player_id: int) -> CardData:
	if is_game_over:
		return null
	var deck = player_decks[player_id]
	if deck.is_empty():
		# Deck out condition
		var other_player = 1 if player_id == 0 else 0
		end_game(other_player, "Player " + str(player_id + 1) + " ran out of cards.")
		return null
		
	var card = deck.pop_front()
	var hand = player_hands[player_id]
	if hand.size() < RulesConfig.MAX_HAND_SIZE:
		hand.append(card)
		card_drawn.emit(player_id, card)
	else:
		# Overdraw discard
		player_discards[player_id].append(card)
	return card

func start_turn() -> void:
	if is_game_over:
		return
		
	var p = active_player_id
	# Rule 1: Every player receives 5 Mana at the beginning of every turn.
	# Mana is replenished to 5 each turn. Unspent Mana does not carry over.
	player_mana[p].turn_refresh()
	
	# Rule 2: Stone placement allowance reset
	player_stones[p].turn_refresh()
	
	# Refresh on-field beasts
	for b in player_fields[p]:
		if b is BeastInstance:
			b.turn_refresh()
			
	turn_started.emit(turn_number, active_player_id)
	
	# Draw phase (after turn 1)
	if turn_number > 1 or p == 1:
		draw_card(p)

func end_turn() -> void:
	if is_game_over:
		return
		
	var prev_player = active_player_id
	turn_ended.emit(turn_number, prev_player)
	
	# Clear unspent mana to 0
	player_mana[prev_player].current_mana = 0
	player_mana[prev_player].mana_changed.emit(0, RulesConfig.MAX_NORMAL_MANA)
	
	# Switch active player
	if active_player_id == 0:
		active_player_id = 1
	else:
		active_player_id = 0
		turn_number += 1
		
	start_turn()

func play_stone_from_hand(player_id: int, hand_index: int) -> bool:
	if player_id != active_player_id or is_game_over:
		return false
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card: CardData = hand[hand_index]
	if card.card_type != "stone":
		return false
		
	var stone_mgr = player_stones[player_id]
	if not stone_mgr.can_place_stone():
		return false
		
	if stone_mgr.place_stone(card.element):
		hand.remove_at(hand_index)
		card_played.emit(player_id, card)
		return true
	return false

func summon_little_dragon(player_id: int, hand_index: int) -> BeastInstance:
	if player_id != active_player_id or is_game_over:
		return null
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return null
	var card: CardData = hand[hand_index]
	if card.id != "little_dragon":
		return null
		
	var field = player_fields[player_id]
	if field.size() >= RulesConfig.MAX_FIELD_BEASTS:
		return null
		
	var mana_mgr = player_mana[player_id]
	# Rule: Little Dragon costs exactly 2 Mana to play.
	if not mana_mgr.can_spend(RulesConfig.LITTLE_DRAGON_MANA_COST):
		return null
		
	mana_mgr.spend(RulesConfig.LITTLE_DRAGON_MANA_COST)
	hand.remove_at(hand_index)
	
	var beast = BeastInstance.create(card, player_id, turn_number)
	field.append(beast)
	beast_summoned.emit(player_id, beast)
	card_played.emit(player_id, card)
	return beast

func evolve_beast(player_id: int, beast_field_index: int, evo_card_hand_index: int) -> bool:
	if player_id != active_player_id or is_game_over:
		return false
	var field = player_fields[player_id]
	var hand = player_hands[player_id]
	
	if beast_field_index < 0 or beast_field_index >= field.size():
		return false
	if evo_card_hand_index < 0 or evo_card_hand_index >= hand.size():
		return false
		
	var beast: BeastInstance = field[beast_field_index]
	var evo_card: CardData = hand[evo_card_hand_index]
	var stone_mgr = player_stones[player_id]
	
	var check = EvolutionEngine.can_evolve(beast, evo_card, stone_mgr)
	if not check.valid:
		return false
		
	if EvolutionEngine.execute_evolution(beast, evo_card, stone_mgr):
		hand.remove_at(evo_card_hand_index)
		beast_evolved.emit(player_id, beast)
		card_played.emit(player_id, evo_card)
		return true
	return false

func fuse_beasts(player_id: int, fusion_card_hand_index: int) -> BeastInstance:
	if player_id != active_player_id or is_game_over:
		return null
	var field = player_fields[player_id]
	var hand = player_hands[player_id]
	if fusion_card_hand_index < 0 or fusion_card_hand_index >= hand.size():
		return null
		
	var fusion_card: CardData = hand[fusion_card_hand_index]
	var check = FusionEngine.can_fuse(field, fusion_card)
	if not check.valid:
		return null
		
	var fused_beast = FusionEngine.execute_fusion(field, fusion_card, player_id, turn_number)
	if fused_beast:
		hand.remove_at(fusion_card_hand_index)
		beasts_fused.emit(player_id, fused_beast)
		card_played.emit(player_id, fusion_card)
		return fused_beast
	return null

func cast_compass(player_id: int, hand_index: int) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "compass":
		return {"success": false, "error": "Card is not Compass"}
		
	var mana_mgr = player_mana[player_id]
	if not mana_mgr.can_spend(RulesConfig.COMPASS_MANA_COST):
		return {"success": false, "error": "Insufficient Mana (requires 2 Mana)"}
		
	mana_mgr.spend(RulesConfig.COMPASS_MANA_COST)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)
	
	var res = AbilityResolver.execute_compass(player_decks[player_id], hand)
	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return res

func cast_spell(player_id: int, hand_index: int, target_beast: BeastInstance = null) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.card_type != "spell":
		return {"success": false, "error": "Card is not a spell"}
		
	# Check Spell Immunity (Shadow Dragon)
	if target_beast and target_beast.is_immune_to_spells():
		return {"success": false, "error": target_beast.card_data.name + " is immune to all Spell cards (Cloak of Darkness)!"}
		
	var mana_mgr = player_mana[player_id]
	if not mana_mgr.can_spend(card.mana_cost):
		return {"success": false, "error": "Insufficient Mana"}
		
	mana_mgr.spend(card.mana_cost)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)
	
	var effect = card.ability.get("effect", "")
	match effect:
		"direct_damage":
			var dmg = card.ability.get("damage", 4)
			if target_beast:
				target_beast.take_damage(dmg)
			else:
				var enemy_id = 1 if player_id == 0 else 0
				deal_player_damage(enemy_id, dmg)
		"heal_target":
			var amt = card.ability.get("amount", 6)
			if target_beast:
				target_beast.heal(amt)
		"buff_shield":
			var amt = card.ability.get("amount", 5)
			if target_beast:
				target_beast.shield_hp += amt
				
	cleanup_dead_beasts()
	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return {"success": true, "error": ""}

func activate_beast_ability(player_id: int, beast_field_index: int, targets: Array = []) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var field = player_fields[player_id]
	if beast_field_index < 0 or beast_field_index >= field.size():
		return {"success": false, "error": "Invalid beast index"}
		
	var beast: BeastInstance = field[beast_field_index]
	var stone_mgr = player_stones[player_id]
	var enemy_id = 1 if player_id == 0 else 0
	
	var res = AbilityResolver.execute_beast_ability(
		beast,
		stone_mgr,
		field,
		player_fields[enemy_id],
		player_decks[player_id],
		player_hands[player_id],
		player_discards[player_id],
		targets
	)
	cleanup_dead_beasts()
	return res

func attack_beast(attacker: BeastInstance, defender: BeastInstance) -> Dictionary:
	if is_game_over:
		return {"success": false, "error": "Game is already over"}
	var res = CombatEngine.execute_beast_combat(attacker, defender, turn_number)
	if res.success:
		cleanup_dead_beasts()
		combat_resolved.emit(res)
	return res

func attack_player_direct(attacker: BeastInstance) -> Dictionary:
	if is_game_over:
		return {"success": false, "error": "Game is already over"}
	var enemy_id = 1 if attacker.controller_id == 0 else 0
	var res = CombatEngine.execute_direct_attack(attacker, enemy_id, self, turn_number)
	if res.success:
		combat_resolved.emit(res)
	return res

func deal_player_damage(player_id: int, amount: int) -> void:
	player_hp[player_id] = maxi(0, player_hp[player_id] - amount)
	if player_hp[player_id] <= 0:
		var winning_player = 1 if player_id == 0 else 0
		end_game(winning_player, "Player " + str(player_id + 1) + "'s HP reached 0.")

func cleanup_dead_beasts() -> void:
	for p in range(2):
		var to_remove: Array = []
		for b in player_fields[p]:
			if b is BeastInstance and b.is_dead():
				to_remove.append(b)
		for dead_beast in to_remove:
			player_fields[p].erase(dead_beast)
			player_discards[p].append(dead_beast.card_data)
			# If it had underlying fusion materials, discard them as well
			for mat in dead_beast.fusion_materials:
				player_discards[p].append(mat)

func end_game(winner: int, reason: String) -> void:
	is_game_over = true
	winner_id = winner
	game_ended.emit(winner_id, reason)
