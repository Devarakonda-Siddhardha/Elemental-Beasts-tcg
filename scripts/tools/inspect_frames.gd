extends SceneTree

func _init() -> void:
	print("Starting submodal inspection...")
	var root = get_root()
	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var mm_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var mm: Control = mm_scene.instantiate()
	vp.add_child(mm)
	
	# 1. Main menu
	for i in range(5):
		await process_frame
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_main_menu.png")
	
	# 2. Open Play Submodal
	mm._show_sub_modal(mm.play_sub_modal)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_play_submodal.png")
		print("Saved frame_play_submodal.png")
	
	# 3. Open Collection Submodal
	mm._hide_sub_modal(mm.play_sub_modal)
	mm._show_sub_modal(mm.collection_sub_modal)
	for i in range(5):
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://frame_collection_submodal.png")
		print("Saved frame_collection_submodal.png")

	mm.queue_free()
	quit()
