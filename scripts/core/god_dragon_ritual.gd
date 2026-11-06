class_name GodDragonRitual
extends RefCounted

const ALL_PRINCIPAL_ELEMENTS: Array[String] = [
	"fire",
	"lightning",
	"shadow",
	"wind",
	"ice",
	"mechanical"
]

static func get_beast_elements(beast: BeastInstance) -> Array[String]:
	var els: Array[String] = []
	if beast.card_data.fusion_materials.size() >= 2:
		for mat in beast.card_data.fusion_materials:
			var el = mat.replace("_dragon", "")
			if el in ALL_PRINCIPAL_ELEMENTS and not (el in els):
				els.append(el)
	elif "_" in beast.card_data.element:
		for el in beast.card_data.element.split("_"):
			if el in ALL_PRINCIPAL_ELEMENTS and not (el in els):
				els.append(el)
	return els

static func can_summon_god_dragon(
	hand_card: CardData, 
	field_beasts: Array, 
	stone_manager: StoneManager, 
	already_summoned: bool
) -> Dictionary:
	if already_summoned:
		return {"valid": false, "error": "God Dragon can only be summoned once per player per duel"}
		
	if not hand_card or hand_card.id != "god_dragon":
		return {"valid": false, "error": "Selected hand card is not God Dragon"}
		
	# Find all eligible Fusion or Ascended dragons on the field
	var eligible: Array[BeastInstance] = []
	for b in field_beasts:
		if b is BeastInstance and not b.is_dead():
			if b.card_data.sub_type == "fusion_dragon" or b.card_data.sub_type == "ascended_dragon":
				eligible.append(b)
				
	if eligible.size() < RulesConfig.GOD_DRAGON_REQUIRED_BEASTS:
		return {
			"valid": false, 
			"error": "God Dragon requires 3 Fusion/Ascended Dragons on field representing all 6 elements (have " + str(eligible.size()) + ")"
		}
		
	# Check for a combination of 3 dragons that represents all 6 elements exactly once
	var valid_triad: Array[BeastInstance] = []
	var n = eligible.size()
	var found = false
	
	for i in range(n):
		if found: break
		for j in range(i + 1, n):
			if found: break
			for k in range(j + 1, n):
				var b1 = eligible[i]
				var b2 = eligible[j]
				var b3 = eligible[k]
				var combined_els: Array[String] = []
				
				for el in get_beast_elements(b1):
					if not (el in combined_els): combined_els.append(el)
				for el in get_beast_elements(b2):
					if not (el in combined_els): combined_els.append(el)
				for el in get_beast_elements(b3):
					if not (el in combined_els): combined_els.append(el)
					
				if combined_els.size() == 6:
					var all_six = true
					for req_el in ALL_PRINCIPAL_ELEMENTS:
						if not (req_el in combined_els):
							all_six = false
							break
					if all_six:
						valid_triad = [b1, b2, b3]
						found = true
						break
						
	if not found:
		return {
			"valid": false, 
			"error": "Your on-field dragons do not collectively cover all 6 principal elements (Fire, Lightning, Shadow, Wind, Ice, Mechanical) exactly once"
		}
		
	# Check 1 stone of each of the 6 principal elements
	var req_stones: Dictionary = {}
	for el in ALL_PRINCIPAL_ELEMENTS:
		req_stones[el] = RulesConfig.GOD_DRAGON_STONE_EACH
		
	if not stone_manager.can_spend_stones(req_stones):
		var missing: Array[String] = []
		for el in ALL_PRINCIPAL_ELEMENTS:
			if stone_manager.get_stone_count(el) < 1:
				missing.append(el.capitalize())
		return {
			"valid": false, 
			"error": "Insufficient stones for God Dragon ritual. Missing: " + ", ".join(missing)
		}
		
	return {
		"valid": true, 
		"triad": valid_triad, 
		"req_stones": req_stones, 
		"error": ""
	}

static func execute_god_dragon_ritual(
	hand_card: CardData, 
	field_beasts: Array, 
	stone_manager: StoneManager, 
	already_summoned: bool, 
	controller_id: int, 
	current_turn: int
) -> Dictionary:
	var check = can_summon_god_dragon(hand_card, field_beasts, stone_manager, already_summoned)
	if not check.valid:
		return {"success": false, "error": check.error}
		
	# Spend 1 stone of each of the 6 elements
	stone_manager.spend_stones(check.req_stones)
	
	# Instantiate God Dragon
	var god_beast = BeastInstance.create(hand_card, controller_id, current_turn)
	
	# Consume the 3 dragons from field and store them as ritual materials
	var triad: Array[BeastInstance] = check.triad
	for b in triad:
		god_beast.fusion_materials.append(b.card_data)
		for mat in b.fusion_materials:
			god_beast.fusion_materials.append(mat)
		field_beasts.erase(b)
		
	field_beasts.append(god_beast)
	return {"success": true, "beast": god_beast, "details": "The Omni-Elemental God Dragon awakens!"}
