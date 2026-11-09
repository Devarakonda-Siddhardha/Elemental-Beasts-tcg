class_name AbilityResolver
extends RefCounted

static func can_activate_ability(beast: BeastInstance, stone_mgr: StoneManager, hand: Array = []) -> Dictionary:
	if not beast or not stone_mgr:
		return {"valid": false, "error": "Invalid arguments"}
		
	if not beast.can_use_ability():
		return {"valid": false, "error": "Beast cannot use ability (stunned, paralyzed, or already used this turn)"}
		
	var ability = beast.card_data.ability
	if ability.is_empty():
		return {"valid": false, "error": "Beast has no activated ability"}
		
	if ability.get("trigger", "") != "activated":
		return {"valid": false, "error": "Ability is not an activated ability"}
		
	var cost = ability.get("cost", {})
	if ability.get("effect") == "discard_stone_draw_two":
		var has_hand_stone = false
		for c in hand:
			if c is CardData and c.card_type == "stone":
				has_hand_stone = true
				break
		if not has_hand_stone and stone_mgr.get_total_stones() == 0:
			return {
				"valid": false,
				"error": "Requires 1 Element Stone in hand or Stone Pile to discard."
			}
		return {"valid": true, "error": ""}
		
	if not cost.is_empty() and not stone_mgr.has_stones(cost):
		return {
			"valid": false, 
			"error": "Insufficient Element Stones. Required: " + str(cost)
		}
		
	return {"valid": true, "error": ""}

static func execute_beast_ability(
	beast: BeastInstance,
	stone_mgr: StoneManager,
	all_friendly_beasts: Array,
	all_enemy_beasts: Array,
	deck: Array,
	hand: Array,
	discard: Array,
	target_enemy_beasts: Array = []
) -> Dictionary:
	var check = can_activate_ability(beast, stone_mgr, hand)
	if not check.valid:
		return {"success": false, "error": check.error}
		
	var ability = beast.card_data.ability
	var cost = ability.get("cost", {})
	var effect_type = ability.get("effect", "")
	
	# Spend required stones
	if effect_type == "discard_stone_draw_two":
		var stone_discarded = false
		for i in range(hand.size() - 1, -1, -1):
			var c = hand[i]
			if c is CardData and c.card_type == "stone":
				hand.remove_at(i)
				discard.append(c)
				stone_discarded = true
				break
		if not stone_discarded:
			stone_mgr.spend_stones({"any_stone": 1})
	elif not cost.is_empty():
		if not stone_mgr.spend_stones(cost):
			return {"success": false, "error": "Failed to spend stones"}
			
	beast.ability_used_this_turn = true
	var result_info = {"success": true, "effect": effect_type, "details": ""}
	
	match effect_type:
		"inflict_paralysis":
			# Lightning Dragon: Paralysis
			var p_target: BeastInstance = null
			if target_enemy_beasts.size() > 0 and target_enemy_beasts[0] is BeastInstance:
				p_target = target_enemy_beasts[0]
			elif all_enemy_beasts.size() > 0 and all_enemy_beasts[0] is BeastInstance:
				p_target = all_enemy_beasts[0]
			if p_target:
				p_target.is_paralyzed = true
				result_info["details"] = "Paralysis inflicted on " + p_target.card_data.name + "! Must flip Heads at turn start to break free!"
			else:
				result_info["details"] = "Paralysis activated."

		"discard_stone_draw_two":
			# Mechanical Dragon: Overclock Draw
			var drawn = 0
			for _i in range(2):
				if deck.size() > 0:
					hand.append(deck.pop_front())
					drawn += 1
			result_info["details"] = "Discarded 1 Element Stone and drew " + str(drawn) + " cards!"

		"double_attack":
			# Wind Dragon: Gale Force
			beast.max_attacks_per_turn = 2
			result_info["details"] = beast.card_data.name + " gained Gale Force (can attack twice this turn)!"
			
		"volcanic_storm":
			# VolcoVolt Dragon: Volcanic Storm (Deal 8 damage to two different targets + Stun)
			var damage_dealt = 0
			var stunned_count = 0
			var targets_to_hit: Array = []
			
			if target_enemy_beasts.size() >= 2:
				targets_to_hit = [target_enemy_beasts[0], target_enemy_beasts[1]]
			elif target_enemy_beasts.size() == 1:
				targets_to_hit = [target_enemy_beasts[0]]
			else:
				# Auto-select up to 2 distinct enemy beasts
				for eb in all_enemy_beasts:
					if eb is BeastInstance and not eb.is_dead():
						targets_to_hit.append(eb)
						if targets_to_hit.size() >= 2:
							break
							
			for target in targets_to_hit:
				target.take_damage(8)
				target.stun_turns = maxi(target.stun_turns, RulesConfig.DEFAULT_STUN_DURATION)
				damage_dealt += 8
				stunned_count += 1
				
			result_info["details"] = "Volcanic Storm dealt 8 damage and stunned " + str(stunned_count) + " target(s)!"
			
		"frosting_draw":
			# Techno Frost Dragon: Frosting Draw (Freeze all opposing Beasts, draw 1 card per frozen beast)
			var frozen_count = 0
			for eb in all_enemy_beasts:
				if eb is BeastInstance and not eb.is_dead():
					eb.freeze_turns = maxi(eb.freeze_turns, RulesConfig.DEFAULT_FREEZE_DURATION)
					frozen_count += 1
					
			# Draw 1 card for each beast frozen
			var cards_drawn = 0
			for i in range(frozen_count):
				if deck.size() > 0:
					hand.append(deck.pop_front())
					cards_drawn += 1
					
			result_info["details"] = "Frosting Draw froze " + str(frozen_count) + " beast(s) and drew " + str(cards_drawn) + " card(s)!"
			
		"spell_recovery":
			# Spark Wraith Dragon: Recover up to 2 Spell cards from discard; Lightning Spells free-cast
			var recovered: Array = []
			var to_remove: Array = []
			for c in discard:
				if c is CardData and c.card_type == "spell":
					recovered.append(c)
					to_remove.append(c)
					if recovered.size() >= 2:
						break
						
			for c in to_remove:
				discard.erase(c)
				hand.append(c)
				# If lightning spell, temporarily set mana cost to 0 for this turn
				if c.element == "lightning":
					c.mana_cost = 0
					
			result_info["details"] = "Recovered " + str(recovered.size()) + " spell(s) from discard!"
			
		"phantom_gale":
			# Zephyr Shadow Dragon: attack twice this turn
			beast.max_attacks_per_turn = 2
			result_info["details"] = "Phantom Gale unleashed! Can attack twice this turn!"
			
		"ascended_void_tempest":
			# Ascended Zephyr Shadow Dragon: 10 damage split among all opposing beasts
			var alive: Array = []
			for eb in all_enemy_beasts:
				if eb is BeastInstance and not eb.is_dead():
					alive.append(eb)
			if alive.size() > 0:
				var dmg_each = maxi(1, int(10 / alive.size()))
				for eb in alive:
					eb.take_damage(dmg_each)
			result_info["details"] = "Void Tempest dealt 10 split damage across opposing forces!"
			
		"direct_damage":
			# Fire Dragon: Flame Burst (4 direct damage)
			if target_enemy_beasts.size() > 0 and target_enemy_beasts[0] is BeastInstance:
				target_enemy_beasts[0].take_damage(4)
				result_info["details"] = "Flame Burst dealt 4 damage to target beast!"
			else:
				result_info["details"] = "Flame Burst activated."
				
		"aoe_damage":
			# Lightning Dragon: Static Discharge (2 damage to all enemy beasts)
			var hits = 0
			for eb in all_enemy_beasts:
				if eb is BeastInstance and not eb.is_dead():
					eb.take_damage(2)
					hits += 1
			result_info["details"] = "Static Discharge dealt 2 damage to " + str(hits) + " enemy beast(s)!"
			
		"freeze_target":
			# Ice Dragon: Glacial Frost
			if target_enemy_beasts.size() > 0 and target_enemy_beasts[0] is BeastInstance:
				target_enemy_beasts[0].freeze_turns = maxi(target_enemy_beasts[0].freeze_turns, 1)
				result_info["details"] = "Glacial Frost froze target beast for 1 turn!"
				
		"buff_attack":
			# Mechanical Dragon: Overclock (+3 attack)
			beast.bonus_attack += 3
			result_info["details"] = "Overclock granted +3 Attack this turn!"
			
		"heal_target":
			# Water Dragon: Tidal Restoration
			beast.heal(5)
			result_info["details"] = "Tidal Restoration restored 5 HP!"
			
		"searing_cyclone":
			# Pyro Gale Dragon: 5 damage to all opposing Beasts + attack twice
			var hits = 0
			for eb in all_enemy_beasts:
				if eb is BeastInstance and not eb.is_dead():
					eb.take_damage(5)
					hits += 1
			beast.max_attacks_per_turn = 2
			result_info["details"] = "Searing Cyclone dealt 5 damage to " + str(hits) + " foe(s) and granted double attack!"
			
		"subzero_squall":
			# Blizzard Zephyr Dragon: Freeze up to 2 opposing Beasts + attack twice
			var frozen = 0
			for eb in all_enemy_beasts:
				if eb is BeastInstance and not eb.is_dead():
					eb.freeze_turns = maxi(eb.freeze_turns, RulesConfig.DEFAULT_FREEZE_DURATION)
					frozen += 1
					if frozen >= 2:
						break
			beast.max_attacks_per_turn = 2
			result_info["details"] = "Subzero Squall froze " + str(frozen) + " foe(s) and granted double attack!"
			
		"smelting_overdrive":
			# Molten Gear Dragon: Deal 6 damage to target/first enemy beast + gain +5 Shield HP
			beast.shield_hp += 5
			if target_enemy_beasts.size() > 0 and target_enemy_beasts[0] is BeastInstance:
				target_enemy_beasts[0].take_damage(6)
			elif all_enemy_beasts.size() > 0 and all_enemy_beasts[0] is BeastInstance:
				all_enemy_beasts[0].take_damage(6)
			result_info["details"] = "Smelting Overdrive dealt 6 damage and fortified +5 Shield HP!"
			
		"emp_railgun":
			# Cyber Volt Dragon: Deal 6 damage + Stun + gain +3 Attack
			beast.bonus_attack += 3
			var hit_target: BeastInstance = null
			if target_enemy_beasts.size() > 0 and target_enemy_beasts[0] is BeastInstance:
				hit_target = target_enemy_beasts[0]
			elif all_enemy_beasts.size() > 0 and all_enemy_beasts[0] is BeastInstance:
				hit_target = all_enemy_beasts[0]
			if hit_target:
				hit_target.take_damage(6)
				hit_target.stun_turns = maxi(hit_target.stun_turns, RulesConfig.DEFAULT_STUN_DURATION)
			result_info["details"] = "EMP Railgun dealt 6 damage, applied Stun, and boosted +3 Attack!"
			
		"umbral_permafrost":
			# Eclipse Frost Dragon: Freeze all opposing Beasts + heal friendly beast/player
			var frozen_all = 0
			for eb in all_enemy_beasts:
				if eb is BeastInstance and not eb.is_dead():
					eb.freeze_turns = maxi(eb.freeze_turns, RulesConfig.DEFAULT_FREEZE_DURATION)
					frozen_all += 1
			beast.heal(4)
			result_info["details"] = "Umbral Permafrost froze " + str(frozen_all) + " foe(s) and restored 4 HP!"

		"magma_eruption":
			# Magma Drake: Deal 3 damage to all opposing Beasts
			var m_hits = 0
			for eb in all_enemy_beasts:
				if eb is BeastInstance and not eb.is_dead():
					eb.take_damage(3)
					m_hits += 1
			result_info["details"] = "Magma Eruption scorched " + str(m_hits) + " enemy beast(s) for 3 damage!"

		"storm_dive":
			# Thunderbird Wyvern: Deal 3 damage and apply Stun (1 turn)
			var s_target: BeastInstance = null
			if target_enemy_beasts.size() > 0 and target_enemy_beasts[0] is BeastInstance:
				s_target = target_enemy_beasts[0]
			elif all_enemy_beasts.size() > 0 and all_enemy_beasts[0] is BeastInstance:
				s_target = all_enemy_beasts[0]
			if s_target:
				s_target.take_damage(3)
				s_target.stun_turns = maxi(s_target.stun_turns, RulesConfig.DEFAULT_STUN_DURATION)
			result_info["details"] = "Storm Dive dealt 3 damage and stunned target!"

		"whirlwind_draw":
			# Cyclone Serpent: Draw 1 card and gain +2 Attack
			beast.bonus_attack += 2
			if deck.size() > 0:
				hand.append(deck.pop_front())
			result_info["details"] = "Whirlwind Rush drew 1 card and boosted +2 Attack!"

		"subzero_bite":
			# Frostfang Wyrm: Deal 3 damage and Freeze target
			var f_target: BeastInstance = null
			if target_enemy_beasts.size() > 0 and target_enemy_beasts[0] is BeastInstance:
				f_target = target_enemy_beasts[0]
			elif all_enemy_beasts.size() > 0 and all_enemy_beasts[0] is BeastInstance:
				f_target = all_enemy_beasts[0]
			if f_target:
				f_target.take_damage(3)
				f_target.freeze_turns = maxi(f_target.freeze_turns, RulesConfig.DEFAULT_FREEZE_DURATION)
			result_info["details"] = "Subzero Bite dealt 3 damage and froze target!"

		"shadow_siphon":
			# Nightmare Stalker: Deal 3 damage and heal self 3 HP
			var n_target: BeastInstance = null
			if target_enemy_beasts.size() > 0 and target_enemy_beasts[0] is BeastInstance:
				n_target = target_enemy_beasts[0]
			elif all_enemy_beasts.size() > 0 and all_enemy_beasts[0] is BeastInstance:
				n_target = all_enemy_beasts[0]
			if n_target:
				n_target.take_damage(3)
			beast.heal(3)
			result_info["details"] = "Shadow Siphon drained 3 HP from target!"

		"aegis_fortress":
			# Aegis Automaton Dragon: Gain +5 Shield HP and +2 Attack
			beast.shield_hp += 5
			beast.bonus_attack += 2
			result_info["details"] = "Aegis Fortress granted +5 Shield HP and +2 Attack!"
			
		_:
			result_info["details"] = "Ability activated."
			
	return result_info

static func execute_compass(deck: Array, hand: Array, chosen_stone: CardData = null) -> Dictionary:
	# Compass effect: Search your deck for an Element Stone and add it to your hand, then shuffle deck.
	var found_stone: CardData = null
	if chosen_stone and deck.has(chosen_stone) and chosen_stone.card_type == "stone":
		found_stone = chosen_stone
	else:
		for c in deck:
			if c is CardData and c.card_type == "stone":
				found_stone = c
				break
			
	if found_stone:
		deck.erase(found_stone)
		deck.shuffle()
		hand.append(found_stone)
		return {
			"success": true, 
			"card": found_stone,
			"details": "Searched deck, added " + found_stone.name + " to hand, and shuffled deck."
		}
	else:
		return {
			"success": false, 
			"card": null,
			"details": "No Element Stone found in deck."
		}

static func execute_draconic_tome(deck: Array, hand: Array, chosen_dragon: CardData = null) -> Dictionary:
	# Draconic Tome effect: Search your deck for any Dragon Beast card, add to hand, then shuffle deck.
	var found_dragon: CardData = null
	if chosen_dragon and deck.has(chosen_dragon) and chosen_dragon.card_type == "beast":
		found_dragon = chosen_dragon
	else:
		for c in deck:
			if c is CardData and c.card_type == "beast":
				found_dragon = c
				break
				
	if found_dragon:
		deck.erase(found_dragon)
		deck.shuffle()
		hand.append(found_dragon)
		return {
			"success": true,
			"card": found_dragon,
			"details": "Searched deck, added " + found_dragon.name + " to hand, and shuffled deck."
		}
	else:
		return {
			"success": false,
			"card": null,
			"details": "No Dragon Beast card found in deck."
		}

static func execute_draconic_calling(deck: Array, hand: Array, chosen_dragons: Array = []) -> Dictionary:
	# Draconic Calling effect: Search deck for up to 2 Dragon Beast cards, add to hand, then shuffle deck.
	var found: Array = []
	for req in chosen_dragons:
		if req is CardData and req.card_type == "beast" and deck.has(req):
			deck.erase(req)
			hand.append(req)
			found.append(req)
			if found.size() >= 2:
				break

	if found.size() < 2:
		var remaining_scan: Array = deck.duplicate()
		for c in remaining_scan:
			if c is CardData and c.card_type == "beast":
				deck.erase(c)
				hand.append(c)
				found.append(c)
				if found.size() >= 2:
					break

	if found.size() > 0:
		deck.shuffle()
		var names: Array[String] = []
		for fc in found:
			names.append(fc.name)
		return {
			"success": true,
			"cards": found,
			"details": "Searched deck, added " + ", ".join(names) + " to hand, and shuffled deck."
		}
	else:
		return {
			"success": false,
			"cards": [],
			"details": "No Dragon Beast cards found in deck."
		}

static func execute_soul_rebirth(discard: Array, hand: Array, chosen_dragon: CardData = null) -> Dictionary:
	# Soul Rebirth effect: Put 1 Dragon Beast card from your discard pile into your hand.
	var found_dragon: CardData = null
	if chosen_dragon and discard.has(chosen_dragon) and chosen_dragon.card_type == "beast":
		found_dragon = chosen_dragon
	else:
		for i in range(discard.size() - 1, -1, -1):
			var c = discard[i]
			if c is CardData and c.card_type == "beast":
				found_dragon = c
				break

	if found_dragon:
		discard.erase(found_dragon)
		hand.append(found_dragon)
		return {
			"success": true,
			"card": found_dragon,
			"details": "Recovered " + found_dragon.name + " from discard pile to hand!"
		}
	else:
		return {
			"success": false,
			"card": null,
			"details": "No Dragon Beast card found in discard pile."
		}

static func execute_elemental_convergence(deck: Array, hand: Array, chosen_stones: Array = []) -> Dictionary:
	# Elemental Convergence effect: Search deck for up to 2 Element Stone cards, add to hand, then shuffle deck.
	var found: Array = []
	for req in chosen_stones:
		if req is CardData and req.card_type == "stone" and deck.has(req):
			deck.erase(req)
			hand.append(req)
			found.append(req)
			if found.size() >= 2:
				break

	if found.size() < 2:
		var remaining_scan: Array = deck.duplicate()
		for c in remaining_scan:
			if c is CardData and c.card_type == "stone":
				deck.erase(c)
				hand.append(c)
				found.append(c)
				if found.size() >= 2:
					break

	if found.size() > 0:
		deck.shuffle()
		var names: Array[String] = []
		for fc in found:
			names.append(fc.name)
		return {
			"success": true,
			"cards": found,
			"details": "Searched deck, added " + ", ".join(names) + " to hand, and shuffled deck."
		}
	else:
		return {
			"success": false,
			"cards": [],
			"details": "No Element Stone cards found in deck."
		}

