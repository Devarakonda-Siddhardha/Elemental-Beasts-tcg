class_name AIController
extends RefCounted

var game_state: GameState
var ai_player_id: int = 1

func _init(p_game_state: GameState, p_ai_id: int = 1) -> void:
	game_state = p_game_state
	ai_player_id = p_ai_id

func execute_turn() -> Array[String]:
	var action_log: Array[String] = []
	if game_state.active_player_id != ai_player_id or game_state.is_game_over:
		return action_log
		
	# 1. Play ALL Element Stones in hand (unlimited stone placement per turn)
	while true:
		var stone_idx = find_playable_stone_in_hand()
		if stone_idx == -1:
			break
		var card = game_state.get_hand(ai_player_id)[stone_idx]
		if game_state.play_stone_from_hand(ai_player_id, stone_idx):
			action_log.append("AI placed " + card.name + " into Stone Pile.")
		else:
			break

	# 1b. Play Realm / Location card if AI has one in hand and no Realm of its element is active
	var realm_idx = find_playable_realm_in_hand()
	if realm_idx != -1:
		var r_res = game_state.play_realm(ai_player_id, realm_idx)
		if r_res.success:
			action_log.append("AI activated Realm: " + r_res.details)
			
	# 2. Check for God Dragon Ritual
	var god_idx = find_card_in_hand("god_dragon")
	if god_idx != -1:
		var god_card = game_state.get_hand(ai_player_id)[god_idx]
		var check = GodDragonRitual.can_summon_god_dragon(
			god_card, 
			game_state.get_field(ai_player_id), 
			game_state.get_stones(ai_player_id), 
			game_state.player_has_summoned_god_dragon[ai_player_id]
		)
		if check.valid:
			var res = game_state.summon_god_dragon(ai_player_id, god_idx)
			if res.success:
				action_log.append("AI summoned God Dragon! Genesis Roar unleashed!")
				
	# 3. Check for Ascension Opportunities
	var asc_pair = find_playable_ascension()
	if asc_pair.size() == 2:
		var beast_idx = asc_pair[0]
		var asc_card_idx = asc_pair[1]
		var card = game_state.get_hand(ai_player_id)[asc_card_idx]
		var asc_beast = game_state.ascend_beast(ai_player_id, beast_idx, asc_card_idx)
		if asc_beast:
			action_log.append("AI ascended into " + card.name + "!")
			
	# 4. Check for Transcendence Opportunities
	var trans_pair = find_playable_transcendence()
	if trans_pair.size() == 2:
		var beast_idx = trans_pair[0]
		var trans_card_idx = trans_pair[1]
		var card = game_state.get_hand(ai_player_id)[trans_card_idx]
		var trans_beast = game_state.transcend_beast(ai_player_id, beast_idx, trans_card_idx)
		if trans_beast:
			action_log.append("AI transcended into " + card.name + "!")

	# 5. Check for Fusion Opportunities
	var fusion_idx = find_playable_fusion_in_hand()
	if fusion_idx != -1:
		var card = game_state.get_hand(ai_player_id)[fusion_idx]
		var fused = game_state.fuse_beasts(ai_player_id, fusion_idx)
		if fused:
			action_log.append("AI executed Elemental Fusion: " + card.name + "!")
			
	# 3. Check for Evolution Opportunities
	var evo_pair = find_playable_evolution()
	if evo_pair.size() == 2:
		var beast_idx = evo_pair[0]
		var evo_card_idx = evo_pair[1]
		var card = game_state.get_hand(ai_player_id)[evo_card_idx]
		if game_state.evolve_beast(ai_player_id, beast_idx, evo_card_idx):
			action_log.append("AI evolved Little Dragon into " + card.name + "!")

	# 3b. Check for Direct Summon Opportunities (4 matching stones for Stage 1 Dragon)
	while game_state.get_field(ai_player_id).size() < RulesConfig.MAX_FIELD_BEASTS:
		var direct_idx = find_playable_direct_summon()
		if direct_idx == -1:
			break
		var d_card = game_state.get_hand(ai_player_id)[direct_idx]
		var direct_beast = game_state.direct_summon_evolved_beast(ai_player_id, direct_idx)
		if direct_beast:
			action_log.append("AI direct summoned " + d_card.name + " (spent 4 " + d_card.element.capitalize() + " Stones)!")
		else:
			break
			
	# 4. Summon Little Dragon / Fierce Little Dragon (2 Mana each)
	while game_state.get_mana(ai_player_id).can_spend(RulesConfig.LITTLE_DRAGON_MANA_COST):
		var ld_idx = find_base_dragon_in_hand()
		if ld_idx == -1 or game_state.get_field(ai_player_id).size() >= RulesConfig.MAX_FIELD_BEASTS:
			break
		var summoned = game_state.summon_little_dragon(ai_player_id, ld_idx)
		if summoned:
			action_log.append("AI summoned " + summoned.card_data.name + " (spent 2 Mana).")
		else:
			break
			
	# 5. Play Setup Supporters (Ancient Insight, Elemental Convergence, Soul Rebirth, Draconic Calling, Compass, Draconic Tome)
	var insight_idx = find_card_in_hand("ancient_insight")
	if insight_idx != -1 and game_state.get_mana(ai_player_id).can_spend(1):
		var res = game_state.cast_ancient_insight(ai_player_id, insight_idx)
		if res.success:
			action_log.append("AI cast Ancient Insight: " + res.details)

	var conv_idx = find_card_in_hand("elemental_convergence")
	if conv_idx != -1 and game_state.get_mana(ai_player_id).can_spend(2):
		var res = game_state.cast_elemental_convergence(ai_player_id, conv_idx)
		if res.success:
			action_log.append("AI cast Elemental Convergence: " + res.details)

	var rebirth_idx = find_card_in_hand("soul_rebirth")
	if rebirth_idx != -1 and game_state.get_mana(ai_player_id).can_spend(1):
		var res = game_state.cast_soul_rebirth(ai_player_id, rebirth_idx)
		if res.success:
			action_log.append("AI cast Soul Rebirth: " + res.details)

	var calling_idx = find_card_in_hand("draconic_calling")
	if calling_idx != -1 and game_state.get_mana(ai_player_id).can_spend(2) and game_state.get_hand(ai_player_id).size() >= 2:
		var res = game_state.cast_draconic_calling(ai_player_id, calling_idx)
		if res.success:
			action_log.append("AI cast Draconic Calling: " + res.details)

	var compass_idx = find_card_in_hand("compass")
	if compass_idx != -1 and game_state.get_mana(ai_player_id).can_spend(RulesConfig.COMPASS_MANA_COST):
		var res = game_state.cast_compass(ai_player_id, compass_idx)
		if res.success:
			action_log.append("AI cast Compass: " + res.details)
			
	var tome_idx = find_card_in_hand("draconic_tome")
	if tome_idx != -1 and game_state.get_mana(ai_player_id).can_spend(2):
		var res = game_state.cast_draconic_tome(ai_player_id, tome_idx)
		if res.success:
			action_log.append("AI cast Draconic Tome: " + res.details)

	# Play any newly drawn or searched Element Stones immediately!
	while true:
		var extra_stone_idx = find_playable_stone_in_hand()
		if extra_stone_idx == -1:
			break
		var s_card = game_state.get_hand(ai_player_id)[extra_stone_idx]
		if game_state.play_stone_from_hand(ai_player_id, extra_stone_idx):
			action_log.append("AI placed " + s_card.name + " into Stone Pile.")
		else:
			break
			
	# 6. Cast Spells if possible
	var enemy_id = 0 if ai_player_id == 1 else 1
	var enemy_field = game_state.get_field(enemy_id)
	var spell_idx = find_playable_spell_in_hand()
	if spell_idx != -1:
		var spell_card = game_state.get_hand(ai_player_id)[spell_idx]
		var target: BeastInstance = null
		# Pick target not immune to spells
		for eb in enemy_field:
			if eb is BeastInstance and not eb.is_immune_to_spells() and not eb.is_dead():
				target = eb
				break
		var res = game_state.cast_spell(ai_player_id, spell_idx, target)
		if res.success:
			action_log.append("AI cast " + spell_card.name + "!")
			
	# 7. Activate Dragon Abilities
	var field = game_state.get_field(ai_player_id)
	for i in range(field.size()):
		var b: BeastInstance = field[i]
		if b.can_use_ability():
			var res = game_state.activate_beast_ability(ai_player_id, i)
			if res.success:
				action_log.append("AI activated " + b.card_data.name + "'s ability: " + res.details)
				
	# 8. Declare Attacks
	for b in field:
		if b is BeastInstance and b.can_attack(game_state.turn_number):
			var enemy_beasts = game_state.get_field(enemy_id)
			var target_beast: BeastInstance = null
			for eb in enemy_beasts:
				if eb is BeastInstance and not eb.is_dead():
					# Pick target that this beast can kill
					if eb.current_hp <= b.get_attack():
						target_beast = eb
						break
			if not target_beast and enemy_beasts.size() > 0:
				target_beast = enemy_beasts[0]
				
			if target_beast:
				var res = game_state.attack_beast(b, target_beast)
				if res.success:
					action_log.append("AI combat: " + res.details)
			else:
				# Direct attack
				var res = game_state.attack_player_direct(b)
				if res.success:
					action_log.append("AI direct attack: " + res.details)
					
	# 9. End Turn
	game_state.end_turn()
	action_log.append("AI ended turn.")
	return action_log

func find_playable_stone_in_hand() -> int:
	var stone_mgr = game_state.get_stones(ai_player_id)
	if not stone_mgr.can_place_stone():
		return -1
	var hand = game_state.get_hand(ai_player_id)
	for i in range(hand.size()):
		if hand[i].card_type == "stone":
			return i
	return -1

func find_playable_fusion_in_hand() -> int:
	var field = game_state.get_field(ai_player_id)
	var hand = game_state.get_hand(ai_player_id)
	for i in range(hand.size()):
		if hand[i].sub_type == "fusion_dragon":
			var check = FusionEngine.can_fuse(field, hand[i])
			if check.valid:
				return i
	return -1

func find_playable_realm_in_hand() -> int:
	var hand = game_state.get_hand(ai_player_id)
	var mana_mgr = game_state.get_mana(ai_player_id)
	for i in range(hand.size()):
		var c: CardData = hand[i]
		if c.card_type == "realm" and mana_mgr.can_spend(c.mana_cost):
			if game_state.active_realm == null or game_state.active_realm.id != c.id:
				return i
	return -1

func find_playable_evolution() -> Array[int]:
	var field = game_state.get_field(ai_player_id)
	var hand = game_state.get_hand(ai_player_id)
	var stone_mgr = game_state.get_stones(ai_player_id)
	
	for b_idx in range(field.size()):
		var beast: BeastInstance = field[b_idx]
		for h_idx in range(hand.size()):
			var card: CardData = hand[h_idx]
			if card.evolution_stage == 1:
				var check = EvolutionEngine.can_evolve(beast, card, stone_mgr, game_state.active_realm)
				if check.valid:
					return [b_idx, h_idx]
	return []

func find_card_in_hand(card_id: String) -> int:
	var hand = game_state.get_hand(ai_player_id)
	for i in range(hand.size()):
		if hand[i].id == card_id:
			return i
	return -1

func find_base_dragon_in_hand() -> int:
	var hand = game_state.get_hand(ai_player_id)
	for i in range(hand.size()):
		if hand[i].id == "little_dragon" or hand[i].sub_type == "base_dragon":
			return i
	return -1

func find_playable_spell_in_hand() -> int:
	var hand = game_state.get_hand(ai_player_id)
	var mana_mgr = game_state.get_mana(ai_player_id)
	for i in range(hand.size()):
		if hand[i].card_type == "spell" and mana_mgr.can_spend(hand[i].mana_cost):
			return i
	return -1

func find_playable_transcendence() -> Array[int]:
	var field = game_state.get_field(ai_player_id)
	var hand = game_state.get_hand(ai_player_id)
	var stone_mgr = game_state.get_stones(ai_player_id)
	
	for b_idx in range(field.size()):
		var beast: BeastInstance = field[b_idx]
		for h_idx in range(hand.size()):
			var card: CardData = hand[h_idx]
			if card.sub_type == "transcendent_dragon":
				var check = TranscendenceEngine.can_transcend(beast, card, stone_mgr)
				if check.valid:
					return [b_idx, h_idx]
	return []

func find_playable_ascension() -> Array[int]:
	var field = game_state.get_field(ai_player_id)
	var hand = game_state.get_hand(ai_player_id)
	var stone_mgr = game_state.get_stones(ai_player_id)
	
	for b_idx in range(field.size()):
		var beast: BeastInstance = field[b_idx]
		for h_idx in range(hand.size()):
			var card: CardData = hand[h_idx]
			if card.sub_type == "ascended_dragon":
				var check = AscensionEngine.can_ascend(beast, card, stone_mgr)
				if check.valid:
					return [b_idx, h_idx]
	return []

func find_playable_direct_summon() -> int:
	var hand = game_state.get_hand(ai_player_id)
	for i in range(hand.size()):
		var card: CardData = hand[i]
		if card.card_type == "beast" and card.evolution_stage == 1:
			if game_state.can_direct_summon_evolved_beast(ai_player_id, card).valid:
				return i
	return -1

