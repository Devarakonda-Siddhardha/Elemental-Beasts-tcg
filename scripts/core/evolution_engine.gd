class_name EvolutionEngine
extends RefCounted

static func can_evolve(beast: BeastInstance, evo_card: CardData, stone_mgr: StoneManager) -> Dictionary:
	if not beast or not evo_card or not stone_mgr:
		return {"valid": false, "error": "Invalid arguments"}
		
	if evo_card.card_type != "beast" or evo_card.evolution_stage != 1:
		return {"valid": false, "error": "Card is not an elemental evolution"}
		
	if evo_card.evolves_from != "" and beast.card_data.id != evo_card.evolves_from:
		return {
			"valid": false, 
			"error": "Target beast " + beast.card_data.name + " cannot evolve into " + evo_card.name + " (requires " + evo_card.evolves_from + ")"
		}
		
	if not stone_mgr.has_stones(evo_card.stone_cost):
		return {
			"valid": false, 
			"error": "Insufficient Element Stones to evolve into " + evo_card.name + ". Required: " + str(evo_card.stone_cost)
		}
		
	return {"valid": true, "error": ""}

static func execute_evolution(beast: BeastInstance, evo_card: CardData, stone_mgr: StoneManager) -> bool:
	var check = can_evolve(beast, evo_card, stone_mgr)
	if not check.valid:
		printerr("Evolution failed: ", check.error)
		return false
		
	# Deduct stones
	if not stone_mgr.spend_stones(evo_card.stone_cost):
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
