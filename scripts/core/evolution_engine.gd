class_name EvolutionEngine
extends RefCounted

static func get_effective_stone_cost(evo_card: CardData, active_realm: CardData = null) -> Dictionary:
	if not evo_card:
		return {}
	var cost: Dictionary = evo_card.stone_cost.duplicate()
	if active_realm != null and active_realm.card_type == "realm":
		var reduction: int = int(active_realm.ability.get("stone_reduction", 1))
		for el in cost.keys():
			var base_val: int = int(cost[el])
			if base_val > 1:
				cost[el] = maxi(1, base_val - reduction)
	return cost

static func can_evolve(beast: BeastInstance, evo_card: CardData, stone_mgr: StoneManager, active_realm: CardData = null) -> Dictionary:
	if not beast or not evo_card or not stone_mgr:
		return {"valid": false, "error": "Invalid arguments"}
		
	if evo_card.card_type != "beast" or evo_card.evolution_stage != 1:
		return {"valid": false, "error": "Card is not an elemental evolution"}
		
	if evo_card.evolves_from != "" and beast.card_data.id != evo_card.evolves_from:
		return {
			"valid": false, 
			"error": "Target beast " + beast.card_data.name + " cannot evolve into " + evo_card.name + " (requires " + evo_card.evolves_from + ")"
		}
		
	var eff_cost: Dictionary = get_effective_stone_cost(evo_card, active_realm)
	if not stone_mgr.has_stones(eff_cost):
		return {
			"valid": false, 
			"error": "Insufficient Element Stones to evolve into " + evo_card.name + ". Required: " + str(eff_cost)
		}
		
	return {"valid": true, "error": ""}

static func execute_evolution(beast: BeastInstance, evo_card: CardData, stone_mgr: StoneManager, active_realm: CardData = null) -> bool:
	var check = can_evolve(beast, evo_card, stone_mgr, active_realm)
	if not check.valid:
		printerr("Evolution failed: ", check.error)
		return false
		
	var eff_cost: Dictionary = get_effective_stone_cost(evo_card, active_realm)
	# Deduct stones
	if not stone_mgr.spend_stones(eff_cost):
		return false
		
	# Transform beast into evolved form
	beast.card_data = evo_card
	beast.max_hp = evo_card.max_hp
	beast.current_hp = evo_card.hp
	beast.base_attack = evo_card.attack
	beast.bonus_attack = 0
	# Status ailments cured on evolution
	beast.stun_turns = 0
	beast.freeze_turns = 0
	return true
