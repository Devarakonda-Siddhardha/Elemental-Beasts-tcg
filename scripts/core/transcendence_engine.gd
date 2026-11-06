class_name TranscendenceEngine
extends RefCounted

static func can_transcend(field_beast: BeastInstance, hand_card: CardData, stone_manager: StoneManager) -> Dictionary:
	if not field_beast:
		return {"valid": false, "error": "No battlefield dragon selected for Transcendence"}
		
	if not hand_card or hand_card.sub_type != "transcendent_dragon":
		return {"valid": false, "error": "Selected hand card is not a Transcendent Dragon"}
		
	# Must be a pure Elemental Dragon on the field
	if field_beast.card_data.sub_type != "elemental_dragon":
		return {"valid": false, "error": "Transcendence requires an evolved pure Elemental Dragon on the battlefield"}
		
	# Must match the element
	if hand_card.element != field_beast.card_data.element:
		return {"valid": false, "error": "Element mismatch: " + hand_card.name + " requires a " + hand_card.element.capitalize() + " Dragon"}
		
	# Requires 5 matching stones
	var req_stones = {hand_card.element: RulesConfig.TRANSCENDENCE_STONE_COST}
	if not stone_manager.can_spend_stones(req_stones):
		var avail = stone_manager.get_stone_count(hand_card.element)
		return {"valid": false, "error": "Insufficient stones: requires 5 " + hand_card.element.capitalize() + " Stones (you have " + str(avail) + ")"}
		
	return {"valid": true, "error": ""}

static func execute_transcendence(field_beast: BeastInstance, hand_card: CardData, stone_manager: StoneManager, current_turn: int) -> BeastInstance:
	var check = can_transcend(field_beast, hand_card, stone_manager)
	if not check.valid:
		return null
		
	# Spend 5 stones
	stone_manager.spend_stones({hand_card.element: RulesConfig.TRANSCENDENCE_STONE_COST})
	
	# Create Transcendent beast instance
	var transcendent_beast = BeastInstance.create(hand_card, field_beast.controller_id, current_turn)
	
	# Preserve materials underneath: original elemental dragon + all its underlying materials
	transcendent_beast.fusion_materials.append(field_beast.card_data)
	for mat in field_beast.fusion_materials:
		transcendent_beast.fusion_materials.append(mat)
		
	return transcendent_beast
