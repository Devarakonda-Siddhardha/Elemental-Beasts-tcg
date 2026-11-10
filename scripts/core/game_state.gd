class_name GameState
extends RefCounted

signal turn_started(turn: int, active_player: int)
signal turn_ended(turn: int, active_player: int)
signal card_drawn(player_id: int, card: CardData)
signal card_played(player_id: int, card: CardData)
signal beast_summoned(player_id: int, beast: BeastInstance)
signal beast_evolved(player_id: int, beast: BeastInstance)
signal beast_direct_summoned(player_id: int, beast: BeastInstance, stones_spent: int)
signal beasts_fused(player_id: int, fused_beast: BeastInstance)
signal beast_transcended(player_id: int, beast: BeastInstance)
signal beast_ascended(player_id: int, beast: BeastInstance)
signal god_dragon_summoned(player_id: int, beast: BeastInstance)
signal spell_cast(player_id: int, card: CardData)
signal realm_changed(player_id: int, realm_card: CardData, replaced_realm: CardData)
signal relic_attached(player_id: int, relic: CardData, beast: BeastInstance)
signal rift_set(player_id: int, rift: CardData)
signal rift_triggered(player_id: int, rift: CardData, message: String)
signal paralysis_tested(player_id: int, beast: BeastInstance, recovered: bool, coin: String)
signal combat_resolved(result: Dictionary)
signal deck_shuffled(player_id: int)
signal card_cost_paid(player_id: int, card: CardData, mana_spent: int, stones_spent: int)
signal game_ended(winner_id: int, reason: String)

var turn_number: int = 1
var active_player_id: int = 0 # 0 = Player, 1 = Opponent
var is_game_over: bool = false
var winner_id: int = -1
var player_has_summoned_god_dragon: Array[bool] = [false, false]
var active_realm: CardData = null
var active_realm_owner_id: int = -1

# Player states (0 and 1)
var player_hp: Array[int] = [RulesConfig.STARTING_PLAYER_HP, RulesConfig.STARTING_PLAYER_HP]
var player_mana: Array[ManaManager] = [ManaManager.new(), ManaManager.new()]
var player_stones: Array[StoneManager] = [StoneManager.new(), StoneManager.new()]
var player_decks: Array[Array] = [[], []]
var player_hands: Array[Array] = [[], []]
var player_discards: Array[Array] = [[], []]
var player_fields: Array[Array] = [[], []]
var player_rifts: Array[Array] = [[], []]

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

func can_pay_card_cost(player_id: int, cost: int) -> bool:
	if cost <= 0:
		return true
	var mana_mgr = player_mana[player_id]
	var stone_mgr = player_stones[player_id]
	return (mana_mgr.current_mana + stone_mgr.get_total_stones()) >= cost

func pay_card_cost(player_id: int, cost: int, card: CardData = null) -> Dictionary:
	if cost <= 0:
		return {"success": true, "mana_spent": 0, "stones_spent": 0}
	var mana_mgr = player_mana[player_id]
	var stone_mgr = player_stones[player_id]
	var total_avail = mana_mgr.current_mana + stone_mgr.get_total_stones()
	if total_avail < cost:
		return {"success": false, "error": "Insufficient resources (need %d total Mana / Element Stones)" % cost}

	var mana_to_spend = mini(mana_mgr.current_mana, cost)
	if mana_to_spend > 0:
		mana_mgr.spend(mana_to_spend)

	var stone_deficit = cost - mana_to_spend
	var stones_spent = 0
	if stone_deficit > 0:
		var pref_elem = card.element if card != null else ""
		if pref_elem != "" and pref_elem != "neutral" and stone_mgr.get_stone_count(pref_elem) > 0:
			var from_pref = mini(stone_mgr.get_stone_count(pref_elem), stone_deficit)
			stone_mgr.spend_stones({pref_elem: from_pref})
			stone_deficit -= from_pref
			stones_spent += from_pref
		if stone_deficit > 0:
			stone_mgr.spend_stones({"any_stone": stone_deficit})
			stones_spent += stone_deficit

	card_cost_paid.emit(player_id, card, mana_to_spend, stones_spent)
	return {"success": true, "mana_spent": mana_to_spend, "stones_spent": stones_spent}

func start_game(deck0_ids: Array = [], deck1_ids: Array = [], starting_player: int = 0) -> void:
	is_game_over = false
	winner_id = -1
	turn_number = 1
	active_player_id = clampi(starting_player, 0, 1)
	active_realm = null
	active_realm_owner_id = -1
	
	for p in range(2):
		player_hp[p] = RulesConfig.STARTING_PLAYER_HP
		player_mana[p].reset()
		player_stones[p].clear()
		player_hands[p].clear()
		player_discards[p].clear()
		player_fields[p].clear()
		player_rifts[p].clear()
		player_has_summoned_god_dragon[p] = false
		
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
					"ascends_from": orig.ascends_from,
					"description": orig.description,
					"status": orig.status
				})
				player_decks[p].append(copy)
				
		player_decks[p].shuffle()
		deck_shuffled.emit(p)
		
		# Draw initial hand (5 cards)
		for i in range(RulesConfig.STARTING_HAND_SIZE):
			draw_card(p)
			
	# Start Turn 1 for starting_player
	start_turn()

static func load_starter_deck_ids_by_index(deck_idx: int = 0) -> Array[String]:
	var path = "res://data/default_decks.json"
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		var text = f.get_as_text()
		f.close()
		var json = JSON.new()
		if json.parse(text) == OK:
			var data = json.get_data()
			var decks = data.get("decks", [])
			if decks.size() > 0:
				var idx = clampi(deck_idx, 0, decks.size() - 1)
				var out: Array[String] = []
				for cid in decks[idx].get("cards", []):
					out.append(str(cid))
				return out
	return []

func get_default_deck_ids() -> Array[String]:
	return [
		"little_dragon", "little_dragon", "little_dragon", "little_dragon",
		"shadow_dragon", "shadow_dragon", "shadow_dragon",
		"lightning_dragon", "lightning_dragon", "lightning_dragon",
		"spark_wraith_dragon", "spark_wraith_dragon",
		"transcendent_shadow_dragon",
		"transcendent_lightning_dragon",
		"ascended_spark_wraith_dragon",
		"god_dragon",
		"compass", "compass", "compass",
		"lightning_strike",
		"inferno_surge",
		"zephyr_gust",
		"glacial_freeze",
		"abyssal_drain",
		"kinetic_overdrive",
		"dragon_elixir",
		"shadow_stone", "shadow_stone", "shadow_stone", "shadow_stone", "shadow_stone",
		"lightning_stone", "lightning_stone", "lightning_stone", "lightning_stone", "lightning_stone",
		"fire_stone",
		"wind_stone",
		"ice_stone",
		"mechanical_stone"
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
	
	# Refresh on-field beasts and test paralysis recovery via coin flip
	for b in player_fields[p]:
		if b is BeastInstance:
			if b.is_paralyzed:
				var rec = b.check_paralysis_recovery()
				paralysis_tested.emit(p, b, rec.recovered, rec.coin)
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
	if card.id != "little_dragon" and card.sub_type != "base_dragon":
		return null
		
	var field = player_fields[player_id]
	if field.size() >= RulesConfig.MAX_FIELD_BEASTS:
		return null
		
	var cost: int = card.mana_cost if card.mana_cost > 0 else RulesConfig.LITTLE_DRAGON_MANA_COST
	if not can_pay_card_cost(player_id, cost):
		return null
		
	pay_card_cost(player_id, cost, card)
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
	
	var check = EvolutionEngine.can_evolve(beast, evo_card, stone_mgr, active_realm)
	if not check.valid:
		return false
		
	if EvolutionEngine.execute_evolution(beast, evo_card, stone_mgr, active_realm):
		hand.remove_at(evo_card_hand_index)
		
		# On-Evolve Ability Triggers
		var evo_ability = evo_card.ability if evo_card.ability else {}
		var evo_effect = evo_ability.get("effect", "")
		if evo_card.id == "fire_dragon" or evo_effect == "bonus_attack_on_evolve":
			beast.bonus_attack += int(evo_ability.get("bonus_attack", 3))
		elif evo_card.id == "ice_dragon" or evo_effect == "freeze_enemy_on_evolve":
			var enemy_id = 1 if player_id == 0 else 0
			if player_fields[enemy_id].size() > 0:
				var eb: BeastInstance = player_fields[enemy_id][0]
				eb.freeze_turns = maxi(eb.freeze_turns, int(evo_ability.get("freeze_turns", 1)))
		elif evo_card.id == "wind_dragon" or evo_effect == "bounce_creature_on_evolve":
			var enemy_id = 1 if player_id == 0 else 0
			if player_fields[enemy_id].size() > 0:
				var bounced: BeastInstance = player_fields[enemy_id].pop_back()
				bounced.cleanse()
				player_hands[enemy_id].append(bounced.card_data)
			elif player_fields[player_id].size() > 1:
				for bi in range(player_fields[player_id].size()):
					if player_fields[player_id][bi] != beast:
						var bounced: BeastInstance = player_fields[player_id].pop_at(bi)
						bounced.cleanse()
						player_hands[player_id].append(bounced.card_data)
						break

		beast_evolved.emit(player_id, beast)
		card_played.emit(player_id, evo_card)
		return true
	return false

func get_direct_summon_stone_cost(card: CardData) -> Dictionary:
	if not card:
		return {}
	var el: String = card.element.to_lower()
	if el.is_empty():
		return {}
	var stones_needed: int = 4
	if active_realm != null and active_realm.card_type == "realm":
		var reduction: int = int(active_realm.ability.get("stone_reduction", 1))
		stones_needed = maxi(2, stones_needed - reduction)
	return {el: stones_needed}

func can_direct_summon_evolved_beast(player_id: int, card: CardData) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"valid": false, "error": "Not your turn"}
	if not card:
		return {"valid": false, "error": "Invalid card"}
	if card.card_type != "beast" or card.evolution_stage != 1:
		return {"valid": false, "error": "Only Stage 1 Evolved Dragons can be directly summoned"}
		
	var field: Array = player_fields[player_id]
	if field.size() >= RulesConfig.MAX_FIELD_BEASTS:
		return {"valid": false, "error": "Battlefield is full (max " + str(RulesConfig.MAX_FIELD_BEASTS) + " beasts)"}
		
	var cost: Dictionary = get_direct_summon_stone_cost(card)
	var el: String = card.element.to_lower()
	var stone_mgr: StoneManager = player_stones[player_id]
	if not stone_mgr.has_stones(cost):
		var needed: int = cost.get(el, 4)
		return {"valid": false, "error": "Requires %d %s Stones to direct summon %s" % [needed, el.capitalize(), card.name]}
		
	return {"valid": true, "error": "", "cost": cost, "element": el}

func direct_summon_evolved_beast(player_id: int, hand_index: int) -> BeastInstance:
	if player_id != active_player_id or is_game_over:
		return null
	var hand: Array = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return null
	var card: CardData = hand[hand_index]
	var check = can_direct_summon_evolved_beast(player_id, card)
	if not check.valid:
		return null
		
	var cost: Dictionary = check.get("cost", get_direct_summon_stone_cost(card))
	var stone_mgr: StoneManager = player_stones[player_id]
	if not stone_mgr.spend_stones(cost):
		return null
		
	hand.remove_at(hand_index)
	var beast = BeastInstance.create(card, player_id, turn_number)
	player_fields[player_id].append(beast)
	
	# Apply on-summon / on-evolve abilities
	var evo_ability = card.ability if card.ability else {}
	var evo_effect = evo_ability.get("effect", "")
	if card.id == "fire_dragon" or evo_effect == "bonus_attack_on_evolve":
		beast.bonus_attack += int(evo_ability.get("bonus_attack", 3))
	elif card.id == "ice_dragon" or evo_effect == "freeze_enemy_on_evolve":
		var enemy_id = 1 if player_id == 0 else 0
		if player_fields[enemy_id].size() > 0:
			var eb: BeastInstance = player_fields[enemy_id][0]
			eb.freeze_turns = maxi(eb.freeze_turns, int(evo_ability.get("freeze_turns", 1)))
	elif card.id == "wind_dragon" or evo_effect == "bounce_creature_on_evolve":
		var enemy_id = 1 if player_id == 0 else 0
		if player_fields[enemy_id].size() > 0:
			var bounced: BeastInstance = player_fields[enemy_id].pop_back()
			bounced.cleanse()
			player_hands[enemy_id].append(bounced.card_data)
		elif player_fields[player_id].size() > 1:
			for bi in range(player_fields[player_id].size()):
				if player_fields[player_id][bi] != beast:
					var bounced: BeastInstance = player_fields[player_id].pop_at(bi)
					bounced.cleanse()
					player_hands[player_id].append(bounced.card_data)
					break

	var stones_spent: int = cost.get(card.element.to_lower(), 4)
	beast_direct_summoned.emit(player_id, beast, stones_spent)
	beast_summoned.emit(player_id, beast)
	card_played.emit(player_id, card)
	return beast

func play_realm(player_id: int, hand_index: int) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.card_type != "realm":
		return {"success": false, "error": "Card is not a Realm / Location card"}
		
	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient Mana / Element Stones (requires " + str(card.mana_cost) + ")"}
		
	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	
	var old_realm: CardData = active_realm
	var old_owner: int = active_realm_owner_id
	if old_realm != null and old_owner >= 0 and old_owner <= 1:
		player_discards[old_owner].append(old_realm)
		
	active_realm = card
	active_realm_owner_id = player_id
	realm_changed.emit(player_id, card, old_realm)
	card_played.emit(player_id, card)
	return {
		"success": true,
		"realm": card,
		"replaced_realm": old_realm,
		"details": card.name + " is now the active Realm! Evolution stone requirements reduced by 1."
	}

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

func transcend_beast(player_id: int, field_index: int, hand_index: int) -> BeastInstance:
	if player_id != active_player_id or is_game_over:
		return null
	var field = player_fields[player_id]
	var hand = player_hands[player_id]
	if field_index < 0 or field_index >= field.size():
		return null
	if hand_index < 0 or hand_index >= hand.size():
		return null
		
	var field_beast: BeastInstance = field[field_index]
	var hand_card: CardData = hand[hand_index]
	var stone_mgr = player_stones[player_id]
	
	var check = TranscendenceEngine.can_transcend(field_beast, hand_card, stone_mgr)
	if not check.valid:
		return null
		
	var transcendent_beast = TranscendenceEngine.execute_transcendence(field_beast, hand_card, stone_mgr, turn_number)
	if transcendent_beast:
		field[field_index] = transcendent_beast
		hand.remove_at(hand_index)
		beast_transcended.emit(player_id, transcendent_beast)
		card_played.emit(player_id, hand_card)
		return transcendent_beast
	return null

func ascend_beast(player_id: int, field_index: int, hand_index: int) -> BeastInstance:
	if player_id != active_player_id or is_game_over:
		return null
	var field = player_fields[player_id]
	var hand = player_hands[player_id]
	if field_index < 0 or field_index >= field.size():
		return null
	if hand_index < 0 or hand_index >= hand.size():
		return null
		
	var field_beast: BeastInstance = field[field_index]
	var hand_card: CardData = hand[hand_index]
	var stone_mgr = player_stones[player_id]
	
	var check = AscensionEngine.can_ascend(field_beast, hand_card, stone_mgr)
	if not check.valid:
		return null
		
	var ascended_beast = AscensionEngine.execute_ascension(field_beast, hand_card, stone_mgr, turn_number)
	if ascended_beast:
		field[field_index] = ascended_beast
		hand.remove_at(hand_index)
		beast_ascended.emit(player_id, ascended_beast)
		card_played.emit(player_id, hand_card)
		return ascended_beast
	return null

func summon_god_dragon(player_id: int, hand_index: int) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var hand_card: CardData = hand[hand_index]
	if hand_card.id != "god_dragon":
		return {"success": false, "error": "Card is not God Dragon"}
		
	var field = player_fields[player_id]
	var stone_mgr = player_stones[player_id]
	var already_summoned = player_has_summoned_god_dragon[player_id]
	
	var res = GodDragonRitual.execute_god_dragon_ritual(
		hand_card,
		field,
		stone_mgr,
		already_summoned,
		player_id,
		turn_number
	)
	if res.success:
		player_has_summoned_god_dragon[player_id] = true
		hand.remove_at(hand_index)
		var god_beast: BeastInstance = res.beast
		god_dragon_summoned.emit(player_id, god_beast)
		card_played.emit(player_id, hand_card)
		
		# Genesis Roar: banish all enemy field beasts and deal 10 direct damage
		var enemy_id = 1 if player_id == 0 else 0
		var enemy_field = player_fields[enemy_id]
		for enemy_beast in enemy_field:
			if enemy_beast is BeastInstance:
				player_discards[enemy_id].append(enemy_beast.card_data)
				for mat in enemy_beast.fusion_materials:
					player_discards[enemy_id].append(mat)
		enemy_field.clear()
		deal_player_damage(enemy_id, 10)
		
		return {"success": true, "beast": god_beast}
	return res

func cast_compass(player_id: int, hand_index: int, chosen_stone: CardData = null) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "compass":
		return {"success": false, "error": "Card is not Compass"}
		
	if not can_pay_card_cost(player_id, RulesConfig.COMPASS_MANA_COST):
		return {"success": false, "error": "Insufficient resources (need 2 Mana / Element Stones)"}
		
	pay_card_cost(player_id, RulesConfig.COMPASS_MANA_COST, card)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)
	
	var res = AbilityResolver.execute_compass(player_decks[player_id], hand, chosen_stone)
	if res.success:
		deck_shuffled.emit(player_id)
	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return res

func cast_draconic_tome(player_id: int, hand_index: int, chosen_dragon: CardData = null) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "draconic_tome":
		return {"success": false, "error": "Card is not Draconic Tome"}
		
	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (need " + str(card.mana_cost) + " Mana / Element Stones)"}
		
	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)
	
	var res = AbilityResolver.execute_draconic_tome(player_decks[player_id], hand, chosen_dragon)
	if res.success:
		deck_shuffled.emit(player_id)
	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return res

func cast_ancient_insight(player_id: int, hand_index: int) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "ancient_insight":
		return {"success": false, "error": "Card is not Ancient Insight"}

	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (need " + str(card.mana_cost) + " Mana / Element Stones)"}

	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)

	var drawn_cards: Array = []
	var draw_count: int = int(card.ability.get("draw_count", 2))
	for _i in range(draw_count):
		var d_card = draw_card(player_id)
		if d_card != null:
			drawn_cards.append(d_card)

	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return {
		"success": true,
		"cards": drawn_cards,
		"details": "Drew " + str(drawn_cards.size()) + " card(s) from deck."
	}

func cast_draconic_calling(player_id: int, hand_index: int, discard_hand_index: int = -1, chosen_dragons: Array = []) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "draconic_calling":
		return {"success": false, "error": "Card is not Draconic Calling"}

	if hand.size() < 2:
		return {"success": false, "error": "Requires at least 1 other card in hand to discard"}

	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (need " + str(card.mana_cost) + " Mana / Element Stones)"}

	# Determine which card in hand to discard (other than Draconic Calling itself)
	var disc_idx: int = discard_hand_index
	if disc_idx < 0 or disc_idx >= hand.size() or disc_idx == hand_index:
		disc_idx = 0 if hand_index != 0 else 1

	var discarded_card: CardData = hand[disc_idx]
	pay_card_cost(player_id, card.mana_cost, card)

	# Remove both Draconic Calling and the discarded card safely
	if disc_idx > hand_index:
		hand.remove_at(disc_idx)
		hand.remove_at(hand_index)
	else:
		hand.remove_at(hand_index)
		hand.remove_at(disc_idx)

	player_discards[player_id].append(card)
	player_discards[player_id].append(discarded_card)

	var res = AbilityResolver.execute_draconic_calling(player_decks[player_id], hand, chosen_dragons)
	if res.success:
		deck_shuffled.emit(player_id)
		res["discarded"] = discarded_card
		res["details"] = "Discarded " + discarded_card.name + ". " + str(res.get("details", ""))
	else:
		res["discarded"] = discarded_card
	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return res

func cast_soul_rebirth(player_id: int, hand_index: int, chosen_dragon: CardData = null) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "soul_rebirth":
		return {"success": false, "error": "Card is not Soul Rebirth"}

	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (need " + str(card.mana_cost) + " Mana / Element Stones)"}

	var discard = player_discards[player_id]
	var has_dragon_in_discard := false
	for c in discard:
		if c is CardData and c.card_type == "beast":
			has_dragon_in_discard = true
			break
	if not has_dragon_in_discard:
		return {"success": false, "error": "No Dragon Beast cards in your discard pile"}

	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	var res = AbilityResolver.execute_soul_rebirth(discard, hand, chosen_dragon)
	discard.append(card)

	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return res

func cast_elemental_convergence(player_id: int, hand_index: int, chosen_stones: Array = []) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "elemental_convergence":
		return {"success": false, "error": "Card is not Elemental Convergence"}

	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (need " + str(card.mana_cost) + " Mana / Element Stones)"}

	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)

	var res = AbilityResolver.execute_elemental_convergence(player_decks[player_id], hand, chosen_stones)
	if res.success:
		deck_shuffled.emit(player_id)
	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return res

func cast_dragon_hoard(player_id: int, hand_index: int, discard_hand_index: int = -1) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "dragon_hoard":
		return {"success": false, "error": "Card is not Dragon's Hoard"}

	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (requires " + str(card.mana_cost) + " Mana / Element Stones)"}

	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)

	# Draw 3 cards
	var drawn_cards: Array = []
	for _i in range(3):
		var d = draw_card(player_id)
		if d:
			drawn_cards.append(d)

	# Discard 1 card from hand
	var discarded: CardData = null
	if hand.size() > 0:
		var d_idx = discard_hand_index
		if d_idx < 0 or d_idx >= hand.size():
			d_idx = hand.size() - 1
		discarded = hand.pop_at(d_idx)
		player_discards[player_id].append(discarded)

	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return {
		"success": true,
		"drawn": drawn_cards,
		"discarded": discarded,
		"details": "Drew " + str(drawn_cards.size()) + " cards and discarded " + (discarded.name if discarded else "none") + "."
	}

func cast_elemental_alchemy(player_id: int, hand_index: int, discard_stone_elem: String = "") -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "elemental_alchemy":
		return {"success": false, "error": "Card is not Elemental Alchemy"}

	var stone_mgr = player_stones[player_id]
	var mana_mgr = player_mana[player_id]
	var stone_deficit = maxi(0, card.mana_cost - mana_mgr.current_mana)
	if stone_mgr.get_total_stones() < (stone_deficit + 1):
		return {"success": false, "error": "Requires at least 1 Element Stone in your Stone Pile to discard in addition to card cost"}

	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (requires " + str(card.mana_cost) + " Mana / Element Stones)"}

	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)

	# Discard 1 stone from stone pile
	var spent_elem = ""
	if discard_stone_elem != "" and stone_mgr.get_stone_count(discard_stone_elem) > 0:
		spent_elem = discard_stone_elem
		stone_mgr.spend_stones({spent_elem: 1})
	else:
		for elem in stone_mgr.stone_pile.keys():
			if stone_mgr.get_stone_count(elem) > 0:
				spent_elem = elem
				stone_mgr.spend_stones({spent_elem: 1})
				break

	# Search deck for up to 2 stone cards and add to stone pile
	var deck = player_decks[player_id]
	var added_stones: Array = []
	for i in range(deck.size() - 1, -1, -1):
		var dc = deck[i]
		if dc is CardData and dc.card_type == "stone":
			added_stones.append(dc)
			deck.remove_at(i)
			stone_mgr.add_stone_direct(dc.element, 1)
			if added_stones.size() >= 2:
				break

	deck.shuffle()
	deck_shuffled.emit(player_id)
	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return {
		"success": true,
		"discarded_element": spent_elem,
		"added_stones": added_stones,
		"details": "Discarded 1 " + spent_elem.capitalize() + " Stone and extracted " + str(added_stones.size()) + " Stones from deck to Stone Pile."
	}

func cast_draconic_resurgence(player_id: int, hand_index: int, chosen_dragons: Array = []) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "draconic_resurgence":
		return {"success": false, "error": "Card is not Draconic Resurgence"}

	var discard = player_discards[player_id]
	var dragon_count = 0
	for dc in discard:
		if dc is CardData and dc.card_type == "beast":
			dragon_count += 1
	if dragon_count == 0:
		return {"success": false, "error": "No Dragon Beasts in your discard pile to recover"}

	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (requires " + str(card.mana_cost) + " Mana / Element Stones)"}

	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)

	# Take up to 2 dragons from discard back into deck
	var recycled: Array = []
	var deck = player_decks[player_id]
	if chosen_dragons.size() > 0:
		for cd in chosen_dragons:
			if cd in discard:
				discard.erase(cd)
				deck.append(cd)
				recycled.append(cd)
				if recycled.size() >= 2:
					break
	else:
		for i in range(discard.size() - 1, -1, -1):
			var dc = discard[i]
			if dc is CardData and dc.card_type == "beast":
				discard.remove_at(i)
				deck.append(dc)
				recycled.append(dc)
				if recycled.size() >= 2:
					break

	discard.append(card)
	deck.shuffle()
	deck_shuffled.emit(player_id)
	var drawn = draw_card(player_id)

	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return {
		"success": true,
		"recycled": recycled,
		"drawn": drawn,
		"details": "Recycled " + str(recycled.size()) + " Dragon(s) into deck and drew 1 card."
	}

func cast_call_to_arms(player_id: int, hand_index: int, chosen_dragon: CardData = null) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.id != "call_to_arms":
		return {"success": false, "error": "Card is not Dragon Call to Arms"}

	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (requires " + str(card.mana_cost) + " Mana / Element Stones)"}

	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)

	var deck = player_decks[player_id]
	var selected_card: CardData = null
	if chosen_dragon and chosen_dragon in deck:
		deck.erase(chosen_dragon)
		selected_card = chosen_dragon
	else:
		for i in range(deck.size()):
			var dc = deck[i]
			if dc is CardData and dc.card_type == "beast" and dc.evolution_stage > 0:
				selected_card = dc
				deck.remove_at(i)
				break

	if selected_card:
		hand.append(selected_card)
		deck.shuffle()
		deck_shuffled.emit(player_id)

	spell_cast.emit(player_id, card)
	card_played.emit(player_id, card)
	return {
		"success": true,
		"card": selected_card,
		"details": ("Added " + selected_card.name + " to hand from deck." if selected_card else "No evolved dragons found in deck.")
	}


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
		return {"success": false, "error": target_beast.card_data.name + " is immune to all Spell cards!"}
		
	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources (requires " + str(card.mana_cost) + " Mana / Element Stones)"}
		
	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	player_discards[player_id].append(card)

	# Opposing reaction rifts (e.g. Zephyr Barrier)
	var rift_res = trigger_rifts_on_spell(player_id, card, target_beast)
	if rift_res.get("negated", false):
		cleanup_dead_beasts()
		return {"success": true, "negated": true, "message": rift_res.get("message", "Spell negated by Rift!")}
	
	var effect = card.ability.get("effect", "")
	match effect:
		"draw_cards":
			var amt = card.ability.get("amount", 2)
			for _i in range(amt):
				draw_card(player_id)
		"direct_damage":
			var dmg = card.ability.get("damage", 4)
			var p_dmg = card.ability.get("player_damage", dmg)
			if target_beast:
				target_beast.take_damage(dmg)
			else:
				var enemy_id = 1 if player_id == 0 else 0
				deal_player_damage(enemy_id, p_dmg)
		"heal_target":
			var amt = card.ability.get("amount", 6)
			if target_beast:
				target_beast.heal(amt)
			else:
				heal_player(player_id, amt)
		"buff_shield":
			var amt = card.ability.get("amount", 5)
			if target_beast:
				target_beast.shield_hp += amt
		"wind_gust":
			var dmg = card.ability.get("damage", 3)
			if target_beast:
				target_beast.take_damage(dmg)
			else:
				var enemy_id = 1 if player_id == 0 else 0
				deal_player_damage(enemy_id, dmg)
			var draws = card.ability.get("draw_count", 1)
			for d in range(draws):
				draw_card(player_id)
		"freeze_target":
			var dmg = card.ability.get("damage", 2)
			var turns = card.ability.get("freeze_turns", 1)
			if target_beast:
				target_beast.take_damage(dmg)
				target_beast.apply_status("freeze", turns)
			else:
				var enemy_id = 1 if player_id == 0 else 0
				deal_player_damage(enemy_id, dmg)
		"life_drain":
			var dmg = card.ability.get("damage", 3)
			var heal = card.ability.get("heal_amount", 3)
			if target_beast:
				target_beast.take_damage(dmg)
			else:
				var enemy_id = 1 if player_id == 0 else 0
				deal_player_damage(enemy_id, dmg)
			heal_player(player_id, heal)
		"buff_beast":
			var atk = card.ability.get("attack_buff", 2)
			var shd = card.ability.get("shield_amount", 4)
			if target_beast:
				target_beast.bonus_attack += atk
				target_beast.shield_hp += shd
		"cleanse_and_heal":
			var heal = card.ability.get("heal_amount", 6)
			if target_beast:
				target_beast.cleanse()
				target_beast.heal(heal)
			else:
				heal_player(player_id, heal)
		"molten_meteor":
			var dmg = card.ability.get("damage", 3)
			var p_dmg = card.ability.get("player_damage", 2)
			var enemy_id = 1 if player_id == 0 else 0
			for eb in player_fields[enemy_id]:
				if eb is BeastInstance and not eb.is_dead():
					eb.take_damage(dmg)
			deal_player_damage(enemy_id, p_dmg)
		"stun_strike":
			var dmg = card.ability.get("damage", 3)
			var turns = card.ability.get("stun_turns", 1)
			if target_beast:
				target_beast.take_damage(dmg)
				target_beast.apply_status("stun", turns)
			else:
				var enemy_id = 1 if player_id == 0 else 0
				deal_player_damage(enemy_id, dmg)
		"tailwind_blessing":
			var atk_buff = card.ability.get("attack_buff", 3)
			if target_beast:
				target_beast.bonus_attack += atk_buff
			elif player_fields[player_id].size() > 0:
				player_fields[player_id][0].bonus_attack += atk_buff
			draw_card(player_id)
		"permafrost_shatter":
			var base_dmg = card.ability.get("damage", 3)
			var frozen_dmg = card.ability.get("frozen_damage", 6)
			if target_beast:
				var actual = frozen_dmg if target_beast.freeze_turns > 0 else base_dmg
				target_beast.take_damage(actual)
			else:
				var enemy_id = 1 if player_id == 0 else 0
				deal_player_damage(enemy_id, base_dmg)
		"umbral_hex":
			var dmg = card.ability.get("damage", 4)
			if target_beast:
				target_beast.take_damage(dmg)
			else:
				var enemy_id = 1 if player_id == 0 else 0
				deal_player_damage(enemy_id, dmg)
			draw_card(player_id)
		"nano_repair":
			var heal = card.ability.get("heal_amount", 5)
			var shd = card.ability.get("shield_amount", 3)
			if target_beast:
				target_beast.heal(heal)
				target_beast.shield_hp += shd
			elif player_fields[player_id].size() > 0:
				player_fields[player_id][0].heal(heal)
				player_fields[player_id][0].shield_hp += shd
			else:
				heal_player(player_id, heal)
		"buff_attack_shield":
			var atk = card.ability.get("bonus_attack", 2)
			var shd = card.ability.get("bonus_shield", 4)
			if target_beast:
				target_beast.bonus_attack += atk
				target_beast.shield_hp += shd
			elif player_fields[player_id].size() > 0:
				player_fields[player_id][0].bonus_attack += atk
				player_fields[player_id][0].shield_hp += shd
		"cleave_damage":
			var main_dmg = card.ability.get("damage", 4)
			var aoe_dmg = card.ability.get("aoe_damage", 2)
			var enemy_id = 1 if player_id == 0 else 0
			if target_beast:
				target_beast.take_damage(main_dmg)
				for eb in player_fields[enemy_id]:
					if eb is BeastInstance and eb != target_beast and not eb.is_dead():
						eb.take_damage(aoe_dmg)
			else:
				deal_player_damage(enemy_id, main_dmg)
				for eb in player_fields[enemy_id]:
					if eb is BeastInstance and not eb.is_dead():
						eb.take_damage(aoe_dmg)
		"inflict_paralysis":
			if target_beast:
				target_beast.is_paralyzed = true
			elif player_fields[1 if player_id == 0 else 0].size() > 0:
				player_fields[1 if player_id == 0 else 0][0].is_paralyzed = true
		"frost_armor":
			var shd = card.ability.get("bonus_shield", 6)
			if target_beast:
				target_beast.shield_hp += shd
			elif player_fields[player_id].size() > 0:
				player_fields[player_id][0].shield_hp += shd
		"bounce_friendly_beast":
			if target_beast and target_beast in player_fields[player_id]:
				player_fields[player_id].erase(target_beast)
				target_beast.cleanse()
				target_beast.current_hp = target_beast.max_hp
				player_hands[player_id].append(target_beast.card_data)
			elif player_fields[player_id].size() > 0:
				var b = player_fields[player_id].pop_back()
				b.cleanse()
				b.current_hp = b.max_hp
				player_hands[player_id].append(b.card_data)
		"sacrifice_beast_draw_mana":
			if player_fields[player_id].size() > 0:
				var sac_target = target_beast if (target_beast and target_beast in player_fields[player_id]) else player_fields[player_id][0]
				player_fields[player_id].erase(sac_target)
				player_discards[player_id].append(sac_target.card_data)
			for _i in range(3):
				draw_card(player_id)
			player_mana[player_id].add(2)
				
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

func play_relic(player_id: int, hand_index: int, target_beast: BeastInstance) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.card_type != "relic":
		return {"success": false, "error": "Card is not a relic"}
	if not target_beast or target_beast.is_dead() or not (target_beast in player_fields[player_id]):
		return {"success": false, "error": "Must attach relic to a friendly active Beast"}
		
	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources to equip relic (requires " + str(card.mana_cost) + " Mana / Element Stones)"}
		
	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	target_beast.attach_relic(card)
	relic_attached.emit(player_id, card, target_beast)
	card_played.emit(player_id, card)
	return {"success": true, "relic": card, "beast": target_beast}

func play_rift(player_id: int, hand_index: int) -> Dictionary:
	if player_id != active_player_id or is_game_over:
		return {"success": false, "error": "Not your turn"}
	var hand = player_hands[player_id]
	if hand_index < 0 or hand_index >= hand.size():
		return {"success": false, "error": "Invalid hand index"}
	var card: CardData = hand[hand_index]
	if card.card_type != "rift":
		return {"success": false, "error": "Card is not a rift"}
		
	if not can_pay_card_cost(player_id, card.mana_cost):
		return {"success": false, "error": "Insufficient resources to set rift (requires " + str(card.mana_cost) + " Mana / Element Stones)"}
		
	pay_card_cost(player_id, card.mana_cost, card)
	hand.remove_at(hand_index)
	player_rifts[player_id].append(card)
	rift_set.emit(player_id, card)
	card_played.emit(player_id, card)
	return {"success": true, "rift": card}

func trigger_rifts_on_attack(attacker: BeastInstance, _defender) -> Dictionary:
	var enemy_id = 1 if attacker.controller_id == 0 else 0
	var rifts = player_rifts[enemy_id]
	if rifts.is_empty():
		return {"triggered": false}
	
	var to_trigger: CardData = null
	for r in rifts:
		if r.ability and r.ability.get("trigger") == "on_enemy_attack":
			to_trigger = r
			break
			
	if not to_trigger:
		return {"triggered": false}
		
	rifts.erase(to_trigger)
	player_discards[enemy_id].append(to_trigger)
	
	var effect = to_trigger.ability.get("effect", "")
	var msg = ""
	if effect == "damage_attacker":
		var dmg = int(to_trigger.ability.get("damage", 4))
		attacker.take_damage(dmg)
		msg = to_trigger.name + " detonated, dealing " + str(dmg) + " damage to " + attacker.card_data.name + "!"
	elif effect == "paralyze_attacker":
		attacker.is_paralyzed = true
		msg = to_trigger.name + " triggered! " + attacker.card_data.name + " was paralyzed!"
		
	rift_triggered.emit(enemy_id, to_trigger, msg)
	return {"triggered": true, "rift": to_trigger, "message": msg}

func trigger_rifts_on_spell(caster_id: int, spell_card: CardData, _target) -> Dictionary:
	var enemy_id = 1 if caster_id == 0 else 0
	var rifts = player_rifts[enemy_id]
	if rifts.is_empty():
		return {"triggered": false, "negated": false}
		
	var to_trigger: CardData = null
	for r in rifts:
		if r.ability and r.ability.get("trigger") == "on_enemy_spell":
			to_trigger = r
			break
			
	if not to_trigger:
		return {"triggered": false, "negated": false}
		
	rifts.erase(to_trigger)
	player_discards[enemy_id].append(to_trigger)
	
	var effect = to_trigger.ability.get("effect", "")
	var msg = ""
	var negated = false
	if effect == "negate_and_heal":
		negated = true
		var heal = int(to_trigger.ability.get("heal_amount", 3))
		heal_player(enemy_id, heal)
		msg = to_trigger.name + " activated! " + spell_card.name + " was negated and Player " + str(enemy_id + 1) + " restored " + str(heal) + " HP!"
		
	rift_triggered.emit(enemy_id, to_trigger, msg)
	return {"triggered": true, "negated": negated, "rift": to_trigger, "message": msg}

func attack_beast(attacker: BeastInstance, defender: BeastInstance) -> Dictionary:
	if is_game_over:
		return {"success": false, "error": "Game is already over"}
	var enemy_id = defender.controller_id
	var rift_res = trigger_rifts_on_attack(attacker, defender)
	if attacker.is_dead() or attacker.is_paralyzed or attacker.stun_turns > 0:
		cleanup_dead_beasts()
		return {"success": true, "interrupted_by_rift": true, "rift_message": rift_res.get("message", "")}

	var res = CombatEngine.execute_beast_combat(attacker, defender, turn_number, self, get_field(enemy_id))
	if res.success:
		cleanup_dead_beasts()
		combat_resolved.emit(res)
	return res

func attack_player_direct(attacker: BeastInstance) -> Dictionary:
	if is_game_over:
		return {"success": false, "error": "Game is already over"}
	var enemy_id = 1 if attacker.controller_id == 0 else 0
	var rift_res = trigger_rifts_on_attack(attacker, null)
	if attacker.is_dead() or attacker.is_paralyzed or attacker.stun_turns > 0:
		cleanup_dead_beasts()
		return {"success": true, "interrupted_by_rift": true, "rift_message": rift_res.get("message", "")}

	var res = CombatEngine.execute_direct_attack(attacker, enemy_id, self, turn_number)
	if res.success:
		combat_resolved.emit(res)
	return res

func deal_player_damage(player_id: int, amount: int) -> void:
	player_hp[player_id] = maxi(0, player_hp[player_id] - amount)
	if player_hp[player_id] <= 0:
		var winning_player = 1 if player_id == 0 else 0
		end_game(winning_player, "Player " + str(player_id + 1) + "'s HP reached 0.")

func heal_player(player_id: int, amount: int) -> void:
	player_hp[player_id] = mini(RulesConfig.STARTING_PLAYER_HP, player_hp[player_id] + amount)

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
			# If it had attached relics, discard them as well
			for rel in dead_beast.attached_relics:
				player_discards[p].append(rel)

func end_game(winner: int, reason: String) -> void:
	is_game_over = true
	winner_id = winner
	game_ended.emit(winner_id, reason)
