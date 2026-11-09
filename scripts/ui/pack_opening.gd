class_name PackOpening
extends Control

const PACK_FRONT_TEX = preload("res://assets/art/booster_pack.png")
const PACK_BACK_TEX = preload("res://assets/art/booster_pack_back.png")
const CARD_BACK_TEX = preload("res://assets/art/card_back.png")
const CARD_UI_PREFAB = preload("res://scenes/card_ui.tscn")

enum PackState {
	INSPECTING_PACK,
	TEARING_OPEN,
	CARDS_DEALT,
	ALL_REVEALED
}

var state: PackState = PackState.INSPECTING_PACK
var card_db: Dictionary = {}
var packs_opened_count: int = 0

# 3D-Style Y-axis rotation and 2.5D parallax tilt variables
var rot_y_deg: float = 0.0
var tilt_x_deg: float = 0.0
var base_pack_scale: float = 1.0
var is_dragging_pack: bool = false
var drag_accum_distance: float = 0.0
var hover_over_pack: bool = false
var hover_over_crimp: bool = false
var idle_float_time: float = 0.0

# Drawn cards for the current pack
var drawn_cards: Array[CardData] = []
var slot_containers: Array[Control] = []
var slot_revealed: Array[bool] = []
var slot_flipping: Array[bool] = []

# Node references
@onready var back_button: Button = $TopBarPanel/TopBar/BackButton
@onready var collection_button: Button = $TopBarPanel/TopBar/CollectionButton
@onready var set_toggle_button: Button = get_node_or_null("TopBarPanel/TopBar/SetToggleBtn")
@onready var top_title_label: Label = $TopBarPanel/TopBar/Title
@onready var packs_opened_label: Label = $TopBarPanel/TopBar/PacksOpenedLabel
@onready var instruction_banner: Label = $InstructionBanner
@onready var sub_status_label: Label = $SubStatusLabel

var current_set: String = "set_1" # "set_1" or "set_2"

@onready var pack_stage: Control = $PackStage
@onready var pack_shadow: ColorRect = $PackStage/PackShadow
@onready var pack_aura: ColorRect = $PackStage/PackAura
@onready var pack_sprite: TextureRect = $PackStage/PackSprite
@onready var foil_glint_overlay: ColorRect = $PackStage/PackSprite/FoilGlintOverlay
@onready var top_crimp_zone: Control = $PackStage/PackSprite/TopCrimpZone
@onready var tear_line_glow: ColorRect = $PackStage/PackSprite/TopCrimpZone/TearLineGlow
@onready var burst_particles: CPUParticles2D = $PackStage/BurstParticles

@onready var cards_reveal_stage: Control = $CardsRevealStage
@onready var cards_row: HBoxContainer = $CardsRevealStage/CardsRow

@onready var spin_button: Button = $BottomControls/SpinButton
@onready var open_pack_button: Button = $BottomControls/OpenPackButton
@onready var reveal_all_button: Button = $BottomControls/RevealAllButton
@onready var open_another_button: Button = $BottomControls/OpenAnotherButton
@onready var bottom_menu_button: Button = $BottomControls/BottomMenuButton

@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var card_inspect_modal: ColorRect = $CardInspectModal
@onready var inspect_card_holder: Control = $CardInspectModal/InspectCenter/InspectCardHolder
@onready var inspect_title: Label = $CardInspectModal/InspectCenter/InspectTitle
@onready var inspect_desc: Label = $CardInspectModal/InspectCenter/InspectDesc

func _ready() -> void:
	randomize()
	card_db = CardData.load_database()

	back_button.pressed.connect(_on_back_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	if set_toggle_button:
		set_toggle_button.pressed.connect(_on_set_toggle_pressed)
	spin_button.pressed.connect(_on_spin_180_pressed)
	open_pack_button.pressed.connect(_on_open_pack_pressed)
	reveal_all_button.pressed.connect(_on_reveal_all_pressed)
	open_another_button.pressed.connect(_on_open_another_pressed)
	bottom_menu_button.pressed.connect(_on_back_pressed)

	_update_set_display()

func _on_set_toggle_pressed() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	current_set = "set_2" if current_set == "set_1" else "set_1"
	_update_set_display()
	_reset_to_new_pack()

func _update_set_display() -> void:
	if set_toggle_button:
		set_toggle_button.text = "❖ Set 1: Primal ▾" if current_set == "set_1" else "🌊 Set 2: Tides ▾"
	if top_title_label:
		top_title_label.text = "🎁 BOOSTER PACK ALTAR — SET 1: PRIMAL AWAKENING" if current_set == "set_1" else "🌊 BOOSTER PACK ALTAR — SET 2: TIDES & ANCIENT RELICS"
	if pack_aura:
		pack_aura.color = Color(0.95, 0.75, 0.2, 0.28) if current_set == "set_1" else Color(0.15, 0.65, 0.95, 0.32)

	pack_sprite.mouse_entered.connect(func(): hover_over_pack = true)
	pack_sprite.mouse_exited.connect(func():
		hover_over_pack = false
		tilt_x_deg = 0.0
	)
	pack_sprite.gui_input.connect(_on_pack_gui_input)

	top_crimp_zone.mouse_entered.connect(func():
		hover_over_crimp = true
		if state == PackState.INSPECTING_PACK:
			tear_line_glow.visible = true
	)
	top_crimp_zone.mouse_exited.connect(func():
		hover_over_crimp = false
		if state == PackState.INSPECTING_PACK:
			tear_line_glow.visible = false
	)
	top_crimp_zone.gui_input.connect(_on_crimp_gui_input)

	card_inspect_modal.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_ui_click()
			card_inspect_modal.visible = false
	)

	_reset_to_new_pack()

func _process(delta: float) -> void:
	idle_float_time += delta
	if state == PackState.INSPECTING_PACK:
		_update_pack_3d_visuals(delta)

func _input(event: InputEvent) -> void:
	if state != PackState.INSPECTING_PACK:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Allow dragging anywhere in the central stage area to rotate the pack
				if not _is_mouse_over_bottom_or_top_buttons(event.position):
					is_dragging_pack = true
					drag_accum_distance = 0.0
			else:
				is_dragging_pack = false

	elif event is InputEventMouseMotion:
		if is_dragging_pack:
			rot_y_deg = fposmod(rot_y_deg + event.relative.x * 0.85, 360.0)
			drag_accum_distance += absf(event.relative.x) + absf(event.relative.y)
			# Subtle vertical tilt during drag
			tilt_x_deg = clampf((event.position.y - size.y * 0.5) / 14.0, -18.0, 18.0)
		elif hover_over_pack:
			# 2.5D parallax tilt (±18°) when moving mouse over pack without dragging
			var local_pos = pack_sprite.get_local_mouse_position() - pack_sprite.pivot_offset
			var norm_x = clampf(local_pos.x / 130.0, -1.0, 1.0)
			var norm_y = clampf(local_pos.y / 257.5, -1.0, 1.0)
			tilt_x_deg = norm_x * 18.0 * (-0.35) + norm_y * 8.0

func _is_mouse_over_bottom_or_top_buttons(global_pos: Vector2) -> bool:
	if global_pos.y < 64.0 or global_pos.y > size.y - 84.0:
		return true
	return false

func _on_pack_gui_input(event: InputEvent) -> void:
	if state != PackState.INSPECTING_PACK:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			# Clicking or double-clicking the pack itself tears it open if user didn't drag > 8px
			if drag_accum_distance <= 8.0:
				_tear_open_pack()

func _on_crimp_gui_input(event: InputEvent) -> void:
	if state != PackState.INSPECTING_PACK:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tear_line_glow.visible = true
		else:
			if drag_accum_distance <= 12.0:
				_tear_open_pack()

func _update_pack_3d_visuals(_delta: float) -> void:
	# Render 3D Y-axis rotation cleanly in 2D using cos(deg_to_rad(rot_y_deg))
	var c = cos(deg_to_rad(rot_y_deg))
	var abs_c = maxf(absf(c), 0.04)

	# Gentle floating bob + parallax scale
	var hover_boost = 1.03 if hover_over_pack else 1.0
	base_pack_scale = hover_boost

	pack_sprite.scale.x = abs_c * base_pack_scale
	pack_sprite.scale.y = base_pack_scale
	pack_sprite.rotation_degrees = clampf(sin(deg_to_rad(rot_y_deg)) * 2.5 + tilt_x_deg * 0.22, -10.0, 10.0)

	# Vertical floating motion
	var bob_y = sin(idle_float_time * 2.4) * 6.0
	pack_sprite.position.y = (pack_stage.size.y * 0.5 - 257.5) + bob_y

	# Swap Front vs Backside texture based on sign of cos(rot_y_deg)
	if c >= 0.0:
		if pack_sprite.texture != PACK_FRONT_TEX:
			pack_sprite.texture = PACK_FRONT_TEX
	else:
		if pack_sprite.texture != PACK_BACK_TEX:
			pack_sprite.texture = PACK_BACK_TEX

	# Dynamic metallic foil sheen / brightness modulation based on angle
	var sheen = 0.88 + 0.22 * absf(sin(deg_to_rad(rot_y_deg * 2.0)))
	pack_sprite.modulate = Color(sheen, sheen, sheen, 1.0)

	# Extra specular glint highlight when passing 45° / 135° / 225° / 315°
	var glint_alpha = pow(absf(sin(deg_to_rad(rot_y_deg * 2.0))), 4.0) * 0.22
	foil_glint_overlay.color = Color(1.0, 0.96, 0.82, glint_alpha)

	# Sync shadow and aura width with pack rotation
	pack_shadow.scale.x = abs_c * base_pack_scale
	pack_shadow.scale.y = base_pack_scale
	pack_aura.scale.x = (abs_c + 0.08) * base_pack_scale
	pack_aura.scale.y = base_pack_scale

	# Update status text with live angle & side
	var rounded_deg = int(round(fposmod(rot_y_deg, 360.0)))
	var side_text = "FRONT FOIL" if c >= 0.0 else "BACKSIDE FOIL (6-ELEMENT CREST & CRIMP SEAM)"
	sub_status_label.text = "Viewing: %s (%d°)  •  5 Cards Inside (Guaranteed Elemental Dragon + Apex/Fusion Slot!)" % [side_text, rounded_deg]

	if c >= 0.0:
		spin_button.text = "🔄 Spin 180° (View Backside)"
	else:
		spin_button.text = "🔄 Spin 180° (View Front)"

func _on_spin_180_pressed() -> void:
	if state != PackState.INSPECTING_PACK:
		return
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_card_play()

	var target_deg = round(rot_y_deg / 180.0) * 180.0 + 180.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rot_y_deg", target_deg, 0.55)
	tween.tween_callback(func(): rot_y_deg = fposmod(rot_y_deg, 360.0))

func _on_open_pack_pressed() -> void:
	if state == PackState.INSPECTING_PACK:
		_tear_open_pack()

func _reset_to_new_pack() -> void:
	state = PackState.INSPECTING_PACK
	rot_y_deg = 0.0
	tilt_x_deg = 0.0
	base_pack_scale = 1.0
	is_dragging_pack = false
	drag_accum_distance = 0.0

	pack_stage.visible = true
	pack_stage.modulate = Color.WHITE
	pack_sprite.visible = true
	pack_sprite.scale = Vector2.ONE
	pack_sprite.modulate = Color.WHITE
	pack_sprite.texture = PACK_FRONT_TEX
	tear_line_glow.visible = false

	cards_reveal_stage.visible = false
	card_inspect_modal.visible = false
	flash_overlay.visible = false

	spin_button.visible = true
	open_pack_button.visible = true
	reveal_all_button.visible = false
	open_another_button.visible = false
	bottom_menu_button.visible = false

	instruction_banner.text = "↔ Drag Left / Right to Rotate Pack (Front & Back)  •  ⚡ Click or Tear Top of Pack to Open!"
	_update_pack_3d_visuals(0.0)

func _tear_open_pack() -> void:
	if state != PackState.INSPECTING_PACK:
		return
	state = PackState.TEARING_OPEN

	spin_button.visible = false
	open_pack_button.visible = false
	tear_line_glow.visible = true

	instruction_banner.text = "⚡ PRIMAL AWAKENING UNLEASHED! ⚡"
	sub_status_label.text = "Unsealing elemental relics from the vault..."

	# Sound effects via SoundManager
	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		if sm.has_method("play_pack_rip"):
			sm.play_pack_rip()
		sm.play_fusion()
		sm.play_evolution()
		sm.play_card_play()

	# Draw the 5 booster cards now
	drawn_cards = _draw_booster_pack_cards()
	packs_opened_count += 1
	packs_opened_label.text = "Packs Opened: %d" % packs_opened_count

	# Emit golden/violet energy particles from top crimp
	burst_particles.position = Vector2(pack_stage.size.x * 0.5, 65.0)
	burst_particles.emitting = false
	burst_particles.restart()
	burst_particles.emitting = true

	# Spawn additional procedural energy sparks bursting outward
	_spawn_procedural_tear_burst()

	# Screen flash + Pack scale-up & flash white/gold & fade out
	flash_overlay.visible = true
	flash_overlay.color = Color(1.0, 0.94, 0.65, 0.0)

	var tween = create_tween()
	# Quick spin to front and energize
	tween.tween_property(pack_sprite, "scale", Vector2(1.22, 1.22), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pack_sprite, "modulate", Color(2.2, 2.0, 1.4, 1.0), 0.28)
	tween.parallel().tween_property(tear_line_glow, "scale", Vector2(1.4, 4.5), 0.28)
	tween.parallel().tween_property(flash_overlay, "color", Color(1.0, 0.95, 0.75, 0.65), 0.26)

	tween.tween_property(pack_stage, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.24)
	tween.parallel().tween_property(flash_overlay, "color", Color(1.0, 0.95, 0.75, 0.0), 0.32)

	tween.tween_callback(func():
		pack_stage.visible = false
		flash_overlay.visible = false
		_present_5_facedown_cards()
	)

func _spawn_procedural_tear_burst() -> void:
	var colors = [
		Color(1.0, 0.88, 0.3, 1.0),
		Color(0.75, 0.4, 1.0, 1.0),
		Color(0.35, 0.85, 1.0, 1.0),
		Color(1.0, 0.55, 0.2, 1.0)
	]
	var center = pack_stage.size * 0.5 + Vector2(0, -165)
	for i in range(28):
		var spark = ColorRect.new()
		var sz = randf_range(6.0, 14.0)
		spark.size = Vector2(sz, sz)
		spark.pivot_offset = spark.size * 0.5
		spark.position = center - spark.pivot_offset
		spark.color = colors[i % colors.size()]
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pack_stage.add_child(spark)

		var angle = randf_range(0.0, TAU)
		var dist = randf_range(90.0, 290.0)
		var target_pos = spark.position + Vector2(cos(angle), sin(angle)) * dist
		var stween = create_tween().set_parallel(true)
		stween.tween_property(spark, "position", target_pos, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stween.tween_property(spark, "rotation_degrees", randf_range(-240.0, 240.0), 0.52)
		stween.tween_property(spark, "modulate:a", 0.0, 0.52)
		stween.chain().tween_callback(spark.queue_free)

func _draw_booster_pack_cards() -> Array[CardData]:
	var all_cards = card_db.values()

	var slot_1_2_pool: Array[CardData] = [] # Element Stones or Base/Support/Relic cards
	var slot_3_pool: Array[CardData] = []   # Elemental Spell, Support, or Rift card
	var slot_4_pool: Array[CardData] = []   # Elemental Dragon or Beast (stage 1)
	var slot_5_pool: Array[CardData] = []   # Rare/Apex: Fusion, Transcendent, Ascended, or god_dragon

	for c: CardData in all_cards:
		var in_set = false
		if current_set == "set_1":
			in_set = (c.set_id == "set_1" or c.set_id == "set_1_and_2" or (c.set_id == "" and c.element != "water"))
		else:
			in_set = (c.set_id == "set_2" or c.set_id == "set_1_and_2" or c.element == "water" or c.card_type in ["relic", "rift"])
		if not in_set:
			continue

		if c.card_type in ["stone", "relic"] or c.sub_type == "base_dragon" or c.card_type == "support":
			slot_1_2_pool.append(c)
		if c.card_type in ["spell", "rift", "realm", "support"]:
			slot_3_pool.append(c)
		if c.card_type == "beast" and c.evolution_stage == 1:
			slot_4_pool.append(c)
		if c.sub_type in ["fusion_dragon", "transcendent_dragon", "ascended_dragon", "god_dragon"] or c.id == "god_dragon" or c.evolution_stage >= 2:
			slot_5_pool.append(c)

	# Fallbacks if a pool is sparse in this set
	if slot_1_2_pool.is_empty():
		for c in all_cards:
			if c.card_type == "stone": slot_1_2_pool.append(c)
	if slot_3_pool.is_empty():
		for c in all_cards:
			if c.card_type == "spell": slot_3_pool.append(c)
	if slot_4_pool.is_empty():
		for c in all_cards:
			if c.card_type == "beast" and c.evolution_stage == 1: slot_4_pool.append(c)
	if slot_5_pool.is_empty():
		for c in all_cards:
			if c.evolution_stage >= 2: slot_5_pool.append(c)

	var pack: Array[CardData] = []

	# Cards 1-2: Element Stones or Base/Support cards (avoid exact duplicate if possible)
	slot_1_2_pool.shuffle()
	if slot_1_2_pool.size() >= 2:
		pack.append(slot_1_2_pool[0])
		pack.append(slot_1_2_pool[1])
	elif not slot_1_2_pool.is_empty():
		pack.append(slot_1_2_pool[0])
		pack.append(slot_1_2_pool[0])

	# Card 3: Elemental Spell, Rift, or Support card
	slot_3_pool.shuffle()
	if not slot_3_pool.is_empty():
		pack.append(slot_3_pool[0])

	# Card 4: Elemental Dragon (evolution_stage == 1)
	slot_4_pool.shuffle()
	if not slot_4_pool.is_empty():
		pack.append(slot_4_pool[0])

	# Card 5 (Rare/Apex Slot!): Fusion Dragon, Transcendent Dragon, Ascended Dragon, or god_dragon!
	slot_5_pool.shuffle()
	if not slot_5_pool.is_empty():
		pack.append(slot_5_pool[0])

	return pack

func _get_slot_rarity_info(slot_idx: int, card: CardData) -> Dictionary:
	if slot_idx == 4 or card.evolution_stage >= 2:
		if card.id == "god_dragon" or card.sub_type == "god_dragon":
			return {
				"label": "👑 MYTHIC GOD RELIC",
				"color": Color(1.0, 0.85, 0.2, 1.0),
				"glow": Color(1.0, 0.82, 0.15, 0.95)
			}
		elif card.sub_type == "ascended_dragon":
			return {
				"label": "🌟 ASCENDED APEX",
				"color": Color(0.92, 0.55, 1.0, 1.0),
				"glow": Color(0.85, 0.35, 1.0, 0.95)
			}
		elif card.sub_type == "transcendent_dragon":
			return {
				"label": "⭐ TRANSCENDENT RARE",
				"color": Color(1.0, 0.84, 0.32, 1.0),
				"glow": Color(1.0, 0.78, 0.22, 0.9)
			}
		else:
			return {
				"label": "🔥 FUSION ULTRA RARE",
				"color": Color(0.95, 0.65, 1.0, 1.0),
				"glow": Color(0.88, 0.45, 1.0, 0.9)
			}
	elif slot_idx == 3 or card.evolution_stage == 1:
		return {
			"label": "🐉 ELEMENTAL DRAGON",
			"color": Color(0.35, 0.85, 1.0, 1.0),
			"glow": Color(0.25, 0.75, 1.0, 0.85)
		}
	elif slot_idx == 2 or card.card_type == "spell":
		return {
			"label": "⚡ ELEMENTAL SPELL",
			"color": Color(0.4, 0.95, 0.55, 1.0),
			"glow": Color(0.3, 0.88, 0.45, 0.75)
		}
	else:
		return {
			"label": "💎 CORE / STONE",
			"color": Color(0.78, 0.84, 0.95, 1.0),
			"glow": Color(0.55, 0.68, 0.88, 0.65)
		}

func _present_5_facedown_cards() -> void:
	state = PackState.CARDS_DEALT
	cards_reveal_stage.visible = true

	for child in cards_row.get_children():
		child.queue_free()

	slot_containers.clear()
	slot_revealed.clear()
	slot_flipping.clear()

	instruction_banner.text = "✨ Click Any Face-Down Card to Flip & Reveal  •  Or Click 'Reveal All Cards' Below!"
	sub_status_label.text = "Watch for the glowing Gold/Violet border on Slot 5 (Guaranteed Apex / Fusion Dragon)!"

	reveal_all_button.visible = true
	open_another_button.visible = false
	bottom_menu_button.visible = false

	for i in range(drawn_cards.size()):
		var card: CardData = drawn_cards[i]
		var rarity = _get_slot_rarity_info(i, card)

		var slot_vbox = VBoxContainer.new()
		slot_vbox.custom_minimum_size = Vector2(210, 345)
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_vbox.add_theme_constant_override("separation", 10)
		cards_row.add_child(slot_vbox)

		# Rarity tag above card
		var rarity_lbl = Label.new()
		rarity_lbl.name = "RarityLabel"
		rarity_lbl.text = rarity["label"]
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.add_theme_font_size_override("font_size", 12)
		rarity_lbl.add_theme_color_override("font_color", rarity["color"])
		rarity_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
		rarity_lbl.add_theme_constant_override("shadow_offset_x", 1)
		rarity_lbl.add_theme_constant_override("shadow_offset_y", 1)
		slot_vbox.add_child(rarity_lbl)

		# Fixed 200x278 card stage container so scaling (0.85) stays centered
		var card_stage = Control.new()
		card_stage.name = "CardStage"
		card_stage.custom_minimum_size = Vector2(200, 278)
		card_stage.size = Vector2(200, 278)
		card_stage.pivot_offset = Vector2(100, 139)
		card_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot_vbox.add_child(card_stage)

		# Flip root inside card_stage that tweens scale.x from 0.85 -> 0.0 -> 0.85
		var flip_root = Control.new()
		flip_root.name = "FlipRoot"
		flip_root.custom_minimum_size = Vector2(200, 278)
		flip_root.size = Vector2(200, 278)
		flip_root.pivot_offset = Vector2(100, 139)
		flip_root.scale = Vector2(0.85, 0.85)
		flip_root.mouse_filter = Control.MOUSE_FILTER_PASS
		card_stage.add_child(flip_root)

		# Rarity glow panel around face-down card
		var glow_panel = Panel.new()
		glow_panel.name = "RarityGlow"
		glow_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow_panel.offset_left = -7.0
		glow_panel.offset_top = -7.0
		glow_panel.offset_right = 7.0
		glow_panel.offset_bottom = 7.0
		glow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style = StyleBoxFlat.new()
		style.bg_color = Color(rarity["glow"].r * 0.15, rarity["glow"].g * 0.15, rarity["glow"].b * 0.15, 0.35)
		var border_w = 5 if i == 4 else (4 if i == 3 else 3)
		style.border_width_left = border_w
		style.border_width_top = border_w
		style.border_width_right = border_w
		style.border_width_bottom = border_w
		style.border_color = rarity["glow"]
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.shadow_color = rarity["glow"]
		style.shadow_size = 14 if i == 4 else 8
		glow_panel.add_theme_stylebox_override("panel", style)
		flip_root.add_child(glow_panel)

		# Face-down Card Back TextureRect
		var back_rect = TextureRect.new()
		back_rect.name = "CardBackRect"
		back_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		back_rect.texture = CARD_BACK_TEX
		back_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		back_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		flip_root.add_child(back_rect)

		# Connect hover & click on face-down card
		var slot_index = i
		back_rect.mouse_entered.connect(func():
			if not slot_revealed[slot_index] and not slot_flipping[slot_index]:
				if has_node("/root/SoundManager"):
					get_node("/root/SoundManager").play_card_hover()
				var htween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				htween.tween_property(flip_root, "scale", Vector2(0.92, 0.92), 0.12)
		)
		back_rect.mouse_exited.connect(func():
			if not slot_revealed[slot_index] and not slot_flipping[slot_index]:
				var htween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				htween.tween_property(flip_root, "scale", Vector2(0.85, 0.85), 0.12)
		)
		back_rect.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_flip_card_slot(slot_index)
		)

		# Bottom caption under card
		var status_lbl = Label.new()
		status_lbl.name = "SlotCaption"
		status_lbl.text = "Click to Flip"
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 12)
		status_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 0.9))
		slot_vbox.add_child(status_lbl)

		slot_containers.append(slot_vbox)
		slot_revealed.append(false)
		slot_flipping.append(false)

		# Entrance deal animation for each face-down card
		slot_vbox.modulate.a = 0.0
		flip_root.scale = Vector2(0.4, 0.4)
		var dtween = create_tween()
		dtween.tween_interval(i * 0.08)
		dtween.tween_callback(func():
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_card_play()
		)
		dtween.tween_property(slot_vbox, "modulate:a", 1.0, 0.22)
		dtween.parallel().tween_property(flip_root, "scale", Vector2(0.85, 0.85), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _flip_card_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= drawn_cards.size():
		return
	if slot_revealed[slot_idx] or slot_flipping[slot_idx]:
		return

	slot_flipping[slot_idx] = true
	var card: CardData = drawn_cards[slot_idx]
	var slot_vbox: Control = slot_containers[slot_idx]
	var flip_root: Control = slot_vbox.get_node("CardStage/FlipRoot")
	var back_rect: TextureRect = flip_root.get_node("CardBackRect")
	var caption_lbl: Label = slot_vbox.get_node("SlotCaption")

	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		sm.play_card_play()

	# 3D horizontal flip tween: scale.x from 0.85 to 0.0 with card_back.png,
	# swaps to full CardUI instance, and tweens scale.x from 0.0 to 0.85!
	var tween = create_tween()
	tween.tween_property(flip_root, "scale", Vector2(0.0, 0.90), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		back_rect.visible = false

		var card_ui: CardUI = CARD_UI_PREFAB.instantiate()
		card_ui.name = "RevealedCardUI"
		card_ui.hover_zoom = false
		flip_root.add_child(card_ui)
		card_ui.setup(card, false)
		card_ui.position = Vector2.ZERO
		card_ui.card_clicked.connect(func(_c): _show_card_inspect_modal(card))

		# Play rarity-appropriate sound on reveal
		if has_node("/root/SoundManager"):
			var sm = get_node("/root/SoundManager")
			if slot_idx == 4 or card.evolution_stage >= 2:
				sm.play_fusion()
				sm.play_victory()
			elif slot_idx == 3 or card.evolution_stage == 1:
				sm.play_evolution()
			elif card.card_type == "spell":
				sm.play_spell()
			else:
				sm.play_stone_place()

		caption_lbl.text = card.name
		caption_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	)
	tween.tween_property(flip_root, "scale", Vector2(0.85, 0.85), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		slot_revealed[slot_idx] = true
		slot_flipping[slot_idx] = false
		_check_all_cards_revealed()
	)

func _on_reveal_all_pressed() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()

	var delay_step = 0
	for i in range(drawn_cards.size()):
		if not slot_revealed[i] and not slot_flipping[i]:
			var idx = i
			var d = delay_step * 0.14
			delay_step += 1
			var t = create_tween()
			t.tween_interval(d)
			t.tween_callback(func(): _flip_card_slot(idx))

func _check_all_cards_revealed() -> void:
	for rev in slot_revealed:
		if not rev:
			return

	state = PackState.ALL_REVEALED
	reveal_all_button.visible = false
	open_another_button.visible = true
	bottom_menu_button.visible = true

	var apex_card = drawn_cards[drawn_cards.size() - 1]
	instruction_banner.text = "🎉 PACK COMPLETE! Pulled: %s! (Click any card to inspect closely)" % apex_card.name
	sub_status_label.text = "Open another Primal Awakening Booster Pack or return to the Main Menu / Card Archive."

func _show_card_inspect_modal(card: CardData) -> void:
	for child in inspect_card_holder.get_children():
		child.queue_free()

	var big_card: CardUI = CARD_UI_PREFAB.instantiate()
	big_card.hover_zoom = false
	inspect_card_holder.add_child(big_card)
	big_card.setup(card, false)
	big_card.scale = Vector2(1.45, 1.45)
	big_card.position = Vector2(50, 65)

	inspect_title.text = card.name + "  (" + card.sub_type.replace("_", " ").to_upper() + ")"
	var desc_str = ""
	if card.ability and not card.ability.is_empty():
		desc_str = card.ability.get("name", "") + ": " + card.ability.get("description", "")
	elif card.description != "":
		desc_str = card.description
	inspect_desc.text = desc_str + "\n\n(Click anywhere to close)"
	card_inspect_modal.visible = true

func _on_open_another_pressed() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	_reset_to_new_pack()

func _on_collection_pressed() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/card_collection.tscn")

func _on_back_pressed() -> void:
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
