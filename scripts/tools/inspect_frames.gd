extends SceneTree

func _init() -> void:
	print("Starting comprehensive frame-by-frame inspection...")
	var root = get_root()
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	# 1. MainMenu
	print("Capturing Main Menu...")
	var mm_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var mm: Control = mm_scene.instantiate()
	vp.add_child(mm)
	for i in range(5):
		await process_frame
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_main_menu.png")
		print("Saved frame_main_menu.png")
	mm.queue_free()
	for i in range(2):
		await process_frame

	# 2. Battle Mat (Direct Playfield with Cards)
	print("Capturing Battle Mat...")
	var battle_scene: PackedScene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	battle.skip_coin_flip_overlay = true
	vp.add_child(battle)
	for i in range(5):
		await process_frame
	
	# Simulate summoning a beast to player field to inspect card rendering in-battle
	if battle.has_method("refresh_full_ui"):
		battle.refresh_full_ui()
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_battle.png")
		print("Saved frame_battle.png")
	battle.queue_free()
	for i in range(2):
		await process_frame

	# 3. Pack Opening
	print("Capturing Pack Opening...")
	var pack_scene: PackedScene = load("res://scenes/pack_opening.tscn")
	var pack = pack_scene.instantiate()
	vp.add_child(pack)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_pack_opening.png")
		print("Saved frame_pack_opening.png")
	pack.queue_free()
	for i in range(2):
		await process_frame

	# 4. Deck Builder
	print("Capturing Deck Builder...")
	var db_scene: PackedScene = load("res://scenes/deck_builder.tscn")
	var db = db_scene.instantiate()
	vp.add_child(db)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_deck_builder.png")
		print("Saved frame_deck_builder.png")
	db.queue_free()
	for i in range(2):
		await process_frame

	print("Frame capture complete!")
	quit()
