class_name FusionEngine
extends RefCounted

static func can_fuse(field_beasts: Array, fusion_card: CardData) -> Dictionary:
	if not fusion_card or fusion_card.sub_type != "fusion_dragon":
		return {"valid": false, "error": "Card is not a Fusion Dragon"}
		
	if fusion_card.fusion_materials.size() < 2:
		return {"valid": false, "error": "Fusion card missing material requirements"}
		
	var mat1_id = fusion_card.fusion_materials[0]
	var mat2_id = fusion_card.fusion_materials[1]
	
	var mat1_inst: BeastInstance = null
	var mat2_inst: BeastInstance = null
	
	# Find first material
	for b in field_beasts:
		if b is BeastInstance and b.card_data.id == mat1_id:
			mat1_inst = b
			break
			
	if not mat1_inst:
		return {
			"valid": false, 
			"error": "Missing required fusion material on battlefield: " + mat1_id
		}
		
	# Find second material (must be different instance even if same id)
	for b in field_beasts:
		if b is BeastInstance and b.card_data.id == mat2_id and b != mat1_inst:
			mat2_inst = b
			break
			
	if not mat2_inst:
		return {
			"valid": false, 
			"error": "Missing required fusion material on battlefield: " + mat2_id
		}
		
	return {
		"valid": true,
		"material_1": mat1_inst,
		"material_2": mat2_inst,
		"error": ""
	}

static func execute_fusion(
	field_beasts: Array, 
	fusion_card: CardData, 
	controller_id: int, 
	current_turn: int
) -> BeastInstance:
	var check = can_fuse(field_beasts, fusion_card)
	if not check.valid:
		printerr("Fusion failed: ", check.error)
		return null
		
	var mat1: BeastInstance = check.material_1
	var mat2: BeastInstance = check.material_2
	
	# Remove materials from field
	field_beasts.erase(mat1)
	field_beasts.erase(mat2)
	
	# Create fused dragon
	var fused_beast = BeastInstance.create(fusion_card, controller_id, current_turn)
	fused_beast.fusion_materials.append(mat1.card_data)
	fused_beast.fusion_materials.append(mat2.card_data)
	
	field_beasts.append(fused_beast)
	return fused_beast
