class_name AscensionEngine
extends RefCounted

static func can_ascend(field_beast: BeastInstance, hand_card: CardData, stone_manager: StoneManager) -> Dictionary:
	if not field_beast:
		return {"valid": false, "error": "No battlefield dragon selected for Ascension"}
		
	if not hand_card or hand_card.sub_type != "ascended_dragon":
		return {"valid": false, "error": "Selected hand card is not an Ascended Dragon"}
		
	# Must be a Fusion Dragon on the battlefield
	if field_beast.card_data.sub_type != "fusion_dragon":
		return {"valid": false, "error": "Ascension requires a Fusion Dragon on the battlefield"}
		
	# Component materials check
	if hand_card.ascends_from != "" and hand_card.ascends_from != field_beast.card_data.id:
		return {"valid": false, "error": hand_card.name + " must ascend from " + hand_card.ascends_from.replace("_", " ").capitalize()}
		
	# Determine the 2 component elements from the fusion dragon
	var elements: Array[String] = []
	if field_beast.card_data.fusion_materials.size() >= 2:
		for mat_id in field_beast.card_data.fusion_materials:
			elements.append(mat_id.replace("_dragon", ""))
	elif "_" in field_beast.card_data.element:
		var split_els = field_beast.card_data.element.split("_")
		elements.append(split_els[0])
		elements.append(split_els[1])
		
	if elements.size() < 2:
		return {"valid": false, "error": "Could not verify component elements of the fusion dragon"}
		
	# Check 3 stones of EACH component element
	var req_stones: Dictionary = {}
	req_stones[elements[0]] = RulesConfig.ASCENSION_STONE_COST_EACH
	req_stones[elements[1]] = RulesConfig.ASCENSION_STONE_COST_EACH
	
	if not stone_manager.can_spend_stones(req_stones):
		var have0 = stone_manager.get_stone_count(elements[0])
		var have1 = stone_manager.get_stone_count(elements[1])
		return {
			"valid": false, 
			"error": "Insufficient stones: requires 3 " + elements[0].capitalize() + " & 3 " + elements[1].capitalize() + " Stones (have " + str(have0) + " & " + str(have1) + ")"
		}
		
	return {"valid": true, "elements": elements, "req_stones": req_stones, "error": ""}

static func execute_ascension(field_beast: BeastInstance, hand_card: CardData, stone_manager: StoneManager, current_turn: int) -> BeastInstance:
	var check = can_ascend(field_beast, hand_card, stone_manager)
	if not check.valid:
		return null
		
	# Spend 3 stones of each component element
	stone_manager.spend_stones(check.req_stones)
	
	# Create Ascended beast instance
	var ascended_beast = BeastInstance.create(hand_card, field_beast.controller_id, current_turn)
	
	# Preserve materials underneath: original fusion dragon + all its underlying materials
	ascended_beast.fusion_materials.append(field_beast.card_data)
	for mat in field_beast.fusion_materials:
		ascended_beast.fusion_materials.append(mat)
		
	return ascended_beast
