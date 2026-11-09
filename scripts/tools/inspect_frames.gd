extends SceneTree

func _init() -> void:
	print("Starting UI visual verification...")
	var root = get_root()
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var mm_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var mm: Control = mm_scene.instantiate()
	vp.add_child(mm)
	
	# 1. Main menu with Player Profile
	for i in range(5):
		await process_frame
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_main_menu.png")
		print("Saved frame_main_menu.png")
	
	# 2. Open Play Submodal (Quick Match, Boss Gauntlet, etc.)
	mm._show_sub_modal(mm.play_sub_modal)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_play_submodal.png")
		print("Saved frame_play_submodal.png")
	
	# 3. Open Boss Gauntlet Selector
	mm._show_boss_gauntlet_selector()
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_boss_gauntlet.png")
		print("Saved frame_boss_gauntlet.png")
	
	# 4. Open Starter Deck Selector (showing Water Starter Deck)
	mm._hide_sub_modal(mm.play_sub_modal)
	mm._show_starter_deck_selector(true)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_starter_decks.png")
		print("Saved frame_starter_decks.png")

	mm.queue_free()

	# 5. Pack Opening Scene with Set 1 / Set 2 Toggle
	var po_scene: PackedScene = load("res://scenes/pack_opening.tscn")
	var po: Control = po_scene.instantiate()
	vp.add_child(po)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_pack_opening.png")
		print("Saved frame_pack_opening.png")
	po.queue_free()

	# 6. Deck Builder Scene with Water Filter & Custom Profiles
	var db_scene: PackedScene = load("res://scenes/deck_builder.tscn")
	var db_ctrl: Control = db_scene.instantiate()
	vp.add_child(db_ctrl)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_deck_builder.png")
		print("Saved frame_deck_builder.png")
	db_ctrl.queue_free()

	# 7. Card Collection with Codex Tracker & Set Dropdown
	var cc_scene: PackedScene = load("res://scenes/card_collection.tscn")
	var cc: Control = cc_scene.instantiate()
	vp.add_child(cc)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_card_collection.png")
		print("Saved frame_card_collection.png")
	cc.queue_free()

	print("UI visual verification capture complete!")
	quit()

