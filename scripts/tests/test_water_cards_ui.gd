extends SceneTree

func _init():
	print("--- Running test_water_cards_ui ---")
	var CardDataScript = load("res://scripts/core/card_data.gd")
	var CardUIScript = load("res://scripts/ui/card_ui.gd")
	var CardUIScene = load("res://scenes/card_ui.tscn")
	
	var water_card_ids = [
		"water_stone", "water_dragon", "tidal_serpent", "transcendent_water_dragon",
		"abyssal_trench", "torrential_blast", "tidal_blessing", "ocean_amulet"
	]
	
	# Load cards from json
	var file = FileAccess.open("res://data/CARD_DATABASE.json", FileAccess.READ)
	assert(file != null, "Failed to open CARD_DATABASE.json")
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	assert(err == OK, "Failed to parse json")
	var db = json.data["cards"]
	
	var expected_templates = {
		"water_stone": "res://assets/templates/stone_water.png",
		"water_dragon": "res://assets/templates/template_water.png",
		"tidal_serpent": "res://assets/templates/template_water.png",
		"transcendent_water_dragon": "res://assets/templates/template_water.png",
		"abyssal_trench": "res://assets/templates/realm_water.png",
		"torrential_blast": "res://assets/templates/spell_water.png",
		"tidal_blessing": "res://assets/templates/template_support.png",
		"ocean_amulet": "res://assets/templates/template_support.png"
	}
	
	for cid in water_card_ids:
		var cdata_dict = null
		for c in db:
			if c["id"] == cid:
				cdata_dict = c
				break
		assert(cdata_dict != null, "Card not found in DB: " + cid)
		
		var card_ui = CardUIScene.instantiate()
		root.add_child(card_ui)
		var cdata = CardDataScript.from_dict(cdata_dict)
		card_ui.setup(cdata)
		
		# 1. Verify template path
		var expected_tpl = expected_templates[cid]
		var tpl_path = card_ui.get_template_path(cdata.element, cdata.card_type, cdata.sub_type, cdata.fusion_materials)
		print(cid, " -> template: ", tpl_path)
		assert(tpl_path == expected_tpl, "Wrong template for " + cid + ": got " + tpl_path + " expected " + expected_tpl)
		
		# 2. Verify artwork exists and loads
		if cdata.card_type == "stone":
			assert(card_ui.art_rect.texture == null, "Stone should not overlay art")
		else:
			assert(card_ui.art_rect.texture != null, "Art texture missing for " + cid)
			print(cid, " -> art texture loaded: ", card_ui.art_rect.texture.resource_path)
		
		# 3. Verify stats badge visibility
		if cdata.card_type == "beast":
			assert(card_ui.attack_badge.visible == true, "Beast attack badge should be visible for " + cid)
			assert(card_ui.hp_badge.visible == true, "Beast hp badge should be visible for " + cid)
		else:
			assert(card_ui.attack_badge.visible == false, "Non-beast attack badge should be hidden for " + cid)
			assert(card_ui.hp_badge.visible == false, "Non-beast hp badge should be hidden for " + cid)
			
		card_ui.queue_free()
		
	print("--- ALL 8 WATER CARDS VERIFIED PERFECTLY! ---")
	quit(0)
