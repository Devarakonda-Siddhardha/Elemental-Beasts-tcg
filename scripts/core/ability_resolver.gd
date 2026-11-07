class_name AbilityResolver
extends RefCounted

static func can_activate_ability(beast: BeastInstance, stone_mgr: StoneManager) -> Dictionary:
	if not beast or not stone_mgr:
		return {"valid": false, "error": "Invalid arguments"}
		
	if not beast.can_use_ability():
		return {"valid": false, "error": "Beast cannot use ability (stunned or already used this turn)"}
		
	var ability = beast.card_data.ability
	if ability.is_empty():
		return {"valid": false, "error": "Beast has no activated ability"}
		
	if ability.get("trigger", "") != "activated":
		return {"valid": false, "error": "Ability is not an activated ability"}
		
	var cost = ability.get("cost", {})
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
	var check = can_activate_ability(beast, stone_mgr)
	if not check.valid:
		return {"success": false, "error": check.error}
		
	var ability = beast.card_data.ability
	var cost = ability.get("cost", {})
	var effect_type = ability.get("effect", "")
	
	# Spend required stones
	if not cost.is_empty():
		if not stone_mgr.spend_stones(cost):
			return {"success": false, "error": "Failed to spend stones"}
			
	beast.ability_used_this_turn = true
	var result_info = {"success": true, "effect": effect_type, "details": ""}
	
	match effect_type:
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
