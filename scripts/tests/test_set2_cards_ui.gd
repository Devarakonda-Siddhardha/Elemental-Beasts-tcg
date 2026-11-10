extends SceneTree

func _init():
	print("--- Running test_set2_cards_ui ---")
	var CardDataScript = load("res://scripts/core/card_data.gd")
	var CardUIScene = load("res://scenes/card_ui.tscn")
	
	var set2_cards = [
		"dragon_claws", "aegis_plating", "wings_of_the_gale",
		"molten_counter", "zephyr_barrier", "static_ambush"
	]
	
	var file = FileAccess.open("res://data/CARD_DATABASE.json", FileAccess.READ)
	assert(file != null, "Failed to open CARD_DATABASE.json")
	var json = JSON.new()
	json.parse(file.get_as_text())
	var db = json.data["cards"]
	
	for cid in set2_cards:
		var cdata_dict = null
		for c in db:
			if c["id"] == cid:
				cdata_dict = c
				break
		assert(cdata_dict != null, "Card not found: " + cid)
		
		var card_ui = CardUIScene.instantiate()
		root.add_child(card_ui)
		var cdata = CardDataScript.from_dict(cdata_dict)
		card_ui.setup(cdata)
		
		print(cid, " (", cdata.card_type, ") -> template: ", card_ui.frame_rect.texture.resource_path)
		assert(card_ui.art_rect.texture != null, "Missing art for " + cid)
		print(cid, " -> art loaded: ", card_ui.art_rect.texture.resource_path)
		
		# Badges should be hidden for relics and rifts
		assert(card_ui.attack_badge.visible == false, "Attack badge should be hidden for " + cid)
		assert(card_ui.hp_badge.visible == false, "HP badge should be hidden for " + cid)
		
		card_ui.queue_free()
		
	print("--- ALL REMAINING SET 2 CARDS VERIFIED PERFECTLY! ---")
	quit(0)
