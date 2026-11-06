class_name CardUI
extends Control

signal card_clicked(card_ui: CardUI)
signal card_right_clicked(card_ui: CardUI)
signal card_hovered(card_ui: CardUI, is_hovered: bool)

@export var use_legacy_art: bool = false

var card_data: CardData
var is_selected: bool = false
var is_playable: bool = false
var is_attack_ready: bool = false
var current_hp: int = 0
var max_hp: int = 0
var current_attack: int = 0
var is_on_field: bool = false
var beast_instance_ref = null

# Node references
@onready var frame_rect: TextureRect = $FrameRect
@onready var art_rect: TextureRect = $ArtRect
@onready var element_icon: TextureRect = $ElementIcon
@onready var cost_label: Label = $CostBadge/CostLabel
@onready var cost_badge: Control = $CostBadge
@onready var cost_icon: TextureRect = $CostBadge/CostIcon
@onready var name_label: Label = $NameLabel
@onready var type_label: Label = $TypeLabel
@onready var ability_title_label: Label = $AbilityBox/AbilityTitle
@onready var ability_desc_label: Label = $AbilityBox/AbilityDesc
@onready var footer_label: Label = $FooterBadge/FooterLabel
@onready var attack_badge: Control = $AttackBadge
@onready var attack_label: Label = $AttackBadge/AttackLabel
@onready var hp_badge: Control = $HPBadge
@onready var hp_label: Label = $HPBadge/HPLabel
@onready var status_tag: Label = $StatusTag
@onready var selection_glow: Panel = $SelectionGlow
@onready var playable_glow: Panel = $PlayableGlow
@onready var attack_glow: Panel = $AttackGlow
@onready var status_overlay: ColorRect = $StatusOverlay
@onready var status_label: Label = $StatusOverlay/StatusText

func _ready() -> void:
	custom_minimum_size = Vector2(200, 278)
	size = Vector2(200, 278)
	pivot_offset = size / 2.0
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	if selection_glow: selection_glow.visible = false
	if playable_glow: playable_glow.visible = false
	if attack_glow: attack_glow.visible = false
	if status_overlay: status_overlay.visible = false
	
	if card_data:
		update_ui()

func setup(p_card_data: CardData, p_legacy_art: bool = false) -> void:
	card_data = p_card_data
	use_legacy_art = p_legacy_art
	current_hp = card_data.hp
	max_hp = card_data.max_hp
	current_attack = card_data.attack
	if is_inside_tree():
		update_ui()

func setup_from_beast(beast_inst) -> void:
	beast_instance_ref = beast_inst
	card_data = beast_inst.card_data
	current_hp = beast_inst.current_hp
	max_hp = beast_inst.max_hp
	current_attack = beast_inst.get_attack()
	is_on_field = true
	if is_inside_tree():
		update_ui()

func update_ui() -> void:
	if not card_data:
		return
		
	# 1. Select Template Frame by Element & Type
	var template_path = get_template_path(card_data.element, card_data.card_type, card_data.sub_type)
	if ResourceLoader.exists(template_path):
		frame_rect.texture = load(template_path)
		
	# 2. Card Name
	name_label.text = card_data.name
	
	# 3. Card Type / Subtype
	if card_data.sub_type == "fusion_dragon":
		type_label.text = "FUSION DRAGON"
	elif card_data.sub_type == "elemental_dragon":
		type_label.text = card_data.element.to_upper() + " DRAGON"
	elif card_data.sub_type == "base_dragon":
		type_label.text = "BASE DRAGON"
	elif card_data.card_type == "stone":
		type_label.text = "ELEMENT STONE"
	elif card_data.card_type == "support":
		type_label.text = "SUPPORT ITEM"
	elif card_data.card_type == "spell":
		type_label.text = "SPELL"
	else:
		type_label.text = card_data.card_type.to_upper()
		
	# 4. Element Icon (Top Right)
	var el_icon_path = "res://assets/icons/" + card_data.element.to_lower() + ".png"
	if ResourceLoader.exists(el_icon_path):
		element_icon.texture = load(el_icon_path)
		element_icon.visible = true
	else:
		element_icon.visible = false
		
	# 5. Cost Badge (Top Left)
	# Stones: 0 Mana, cost badge hidden or showing Stone Symbol
	# Little Dragon: 2 Mana
	# Evolution Dragons: shows evolution stone requirement (e.g. 2)
	if card_data.card_type == "beast" and card_data.evolution_stage == 1:
		# Evolution stone cost
		var count = 2
		for k in card_data.stone_cost:
			count = card_data.stone_cost[k]
			break
		cost_label.text = str(count)
		cost_badge.visible = true
		if cost_icon and element_icon.texture:
			cost_icon.texture = element_icon.texture
	elif card_data.mana_cost > 0:
		cost_label.text = str(card_data.mana_cost)
		cost_badge.visible = true
		var mana_icon_path = "res://assets/icons/mana.png"
		if cost_icon and ResourceLoader.exists(mana_icon_path):
			cost_icon.texture = load(mana_icon_path)
	elif card_data.card_type == "stone":
		cost_badge.visible = false
	else:
		cost_badge.visible = false
		
	# 6. Artwork
	load_card_artwork()
	
	# 7. Ability Details
	if card_data.ability and not card_data.ability.is_empty():
		ability_title_label.text = card_data.ability.get("name", "")
		ability_desc_label.text = card_data.ability.get("description", "")
	elif card_data.description != "":
		ability_title_label.text = "EFFECT"
		ability_desc_label.text = card_data.description
	else:
		ability_title_label.text = ""
		ability_desc_label.text = ""
		
	# 8. Combat Stats (Attack & HP)
	if card_data.card_type == "beast":
		attack_badge.visible = true
		hp_badge.visible = true
		attack_label.text = str(current_attack)
		hp_label.text = str(current_hp)
		# Color HP if damaged
		if current_hp < max_hp:
			hp_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			hp_label.modulate = Color.WHITE
	else:
		attack_badge.visible = false
		hp_badge.visible = false
		
	# 9. Footer Badge (Evolution or Fusion info)
	if card_data.sub_type == "fusion_dragon":
		footer_label.text = "FUSE: " + card_data.fusion_materials[0].replace("_", " ").to_upper() + " + " + card_data.fusion_materials[1].replace("_", " ").to_upper()
		$FooterBadge.visible = true
	elif card_data.evolution_stage == 1:
		footer_label.text = "EVOLVES FROM LITTLE DRAGON"
		$FooterBadge.visible = true
	else:
		$FooterBadge.visible = false
		
	# 10. Status Tag (Fidelity tier)
	if status_tag:
		status_tag.text = card_data.status
		match card_data.status:
			"CONFIRMED":
				status_tag.modulate = Color(0.3, 1.0, 0.4) # Green
			"REMEMBERED":
				status_tag.modulate = Color(1.0, 0.8, 0.2) # Gold
			_:
				status_tag.modulate = Color(0.4, 0.8, 1.0) # Cyan

func load_card_artwork() -> void:
	if use_legacy_art and card_data.id == "wind_dragon":
		var path = "res://assets/original_cards/Wind__Dragon.png"
		if ResourceLoader.exists(path):
			art_rect.texture = load(path)
			return
	elif use_legacy_art and card_data.id == "volcovolt_dragon":
		var path = "res://assets/original_cards/_VolcoVolt_Dragon.png"
		if ResourceLoader.exists(path):
			art_rect.texture = load(path)
			return
	elif use_legacy_art and card_data.id == "spark_wraith_dragon":
		var path = "res://assets/original_cards/Spark_Wraith_Dragon.png"
		if ResourceLoader.exists(path):
			art_rect.texture = load(path)
			return
	elif use_legacy_art and card_data.id == "techno_frost_dragon":
		var path = "res://assets/original_cards/Techno_Frost_Dragon.png"
		if ResourceLoader.exists(path):
			art_rect.texture = load(path)
			return
	elif use_legacy_art and card_data.id == "compass":
		var path = "res://assets/original_cards/Compass.png"
		if ResourceLoader.exists(path):
			art_rect.texture = load(path)
			return

	# Remastered or modern artwork
	var art_path = "res://assets/art/" + card_data.id + ".jpg"
	if ResourceLoader.exists(art_path):
		art_rect.texture = load(art_path)
		return
		
	# Element icon fallback
	var icon_path = "res://assets/icons/" + card_data.element.to_lower() + ".png"
	if ResourceLoader.exists(icon_path):
		art_rect.texture = load(icon_path)
	else:
		art_rect.texture = null

func get_template_path(element_name: String, ctype: String, subtype: String) -> String:
	# 1. Fusion Dragons (15 unique dual-element templates)
	if subtype == "fusion_dragon":
		if card_data and card_data.fusion_materials.size() >= 2:
			var m1 = card_data.fusion_materials[0].replace("_dragon", "")
			var m2 = card_data.fusion_materials[1].replace("_dragon", "")
			var p1 = "res://assets/templates/fusion_" + m1 + "_" + m2 + ".png"
			var p2 = "res://assets/templates/fusion_" + m2 + "_" + m1 + ".png"
			if ResourceLoader.exists(p1): return p1
			if ResourceLoader.exists(p2): return p2
		if ResourceLoader.exists("res://assets/templates/template_fusion.jpg"):
			return "res://assets/templates/template_fusion.jpg"

	# 2. Element Stone Cards (Full-art carved elemental monoliths)
	if ctype == "stone":
		var stone_path = "res://assets/templates/stone_" + element_name.to_lower() + ".png"
		if ResourceLoader.exists(stone_path):
			return stone_path
		if ResourceLoader.exists("res://assets/templates/template_stone.jpg"):
			return "res://assets/templates/template_stone.jpg"

	# 3. Spell Cards (Elemental spell storm templates)
	if ctype == "spell":
		var spell_path = "res://assets/templates/spell_" + element_name.to_lower() + ".png"
		if ResourceLoader.exists(spell_path):
			return spell_path
		if ResourceLoader.exists("res://assets/templates/template_support.png"):
			return "res://assets/templates/template_support.png"

	# 4. Support / Item Cards (Compass celestial mountain & star crest)
	if ctype == "support":
		if ResourceLoader.exists("res://assets/templates/template_support.png"):
			return "res://assets/templates/template_support.png"

	# 5. Little Dragon / Base Dragons (Dragon crest & swords/shield)
	if subtype == "base_dragon" or (card_data and card_data.id == "little_dragon"):
		if ResourceLoader.exists("res://assets/templates/template_little_dragon.png"):
			return "res://assets/templates/template_little_dragon.png"

	# 6. Elemental Dragons (Elemental dragon combat frames)
	var el_template = "res://assets/templates/template_" + element_name.to_lower() + ".png"
	if ResourceLoader.exists(el_template):
		return el_template

	return "res://assets/templates/template_wind.png"

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_glow:
		selection_glow.visible = selected

func set_playable(playable: bool) -> void:
	is_playable = playable
	if playable_glow:
		playable_glow.visible = playable

func set_attack_ready(ready_to_attack: bool) -> void:
	is_attack_ready = ready_to_attack
	if attack_glow:
		attack_glow.visible = ready_to_attack

func set_status_display(status_name: String, turns: int) -> void:
	if turns > 0:
		status_overlay.visible = true
		status_label.text = status_name.to_upper() + " (" + str(turns) + ")"
		if status_name == "freeze":
			status_overlay.color = Color(0.2, 0.6, 1.0, 0.45)
		elif status_name == "stun":
			status_overlay.color = Color(1.0, 0.8, 0.2, 0.45)
	else:
		status_overlay.visible = false

func _on_mouse_entered() -> void:
	card_hovered.emit(self, true)
	if not is_on_field:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12)
		z_index = 10

func _on_mouse_exited() -> void:
	card_hovered.emit(self, false)
	if not is_on_field:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
		z_index = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(self)
