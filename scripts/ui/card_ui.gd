class_name CardUI
extends Control

signal card_clicked(card_ui: CardUI)
signal card_right_clicked(card_ui: CardUI)
signal card_hovered(card_ui: CardUI, is_hovered: bool)

@export var use_legacy_art: bool = false
@export var is_compact: bool = false

var card_data: CardData
var is_selected: bool = false
var is_playable: bool = false
var is_attack_ready: bool = false
var current_hp: int = 0
var max_hp: int = 0
var current_attack: int = 0
var is_on_field: bool = false
var beast_instance_ref = null
var base_scale: Vector2 = Vector2.ONE
var hover_zoom: bool = true

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
	if base_scale == Vector2.ONE:
		pivot_offset = size / 2.0
	else:
		pivot_offset = Vector2.ZERO
		scale = base_scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	if selection_glow: selection_glow.visible = false
	if playable_glow: playable_glow.visible = false
	if attack_glow: attack_glow.visible = false
	if status_overlay: status_overlay.visible = false
	
	if card_data:
		update_ui()

func set_compact(compact: bool) -> void:
	is_compact = compact
	update_ui()

func _ensure_node_references() -> void:
	if not frame_rect and has_node("FrameRect"): frame_rect = $FrameRect
	if not art_rect and has_node("ArtRect"): art_rect = $ArtRect
	if not element_icon and has_node("ElementIcon"): element_icon = $ElementIcon
	if not cost_label and has_node("CostBadge/CostLabel"): cost_label = $CostBadge/CostLabel
	if not cost_badge and has_node("CostBadge"): cost_badge = $CostBadge
	if not cost_icon and has_node("CostBadge/CostIcon"): cost_icon = $CostBadge/CostIcon
	if not name_label and has_node("NameLabel"): name_label = $NameLabel
	if not type_label and has_node("TypeLabel"): type_label = $TypeLabel
	if not ability_title_label and has_node("AbilityBox/AbilityTitle"): ability_title_label = $AbilityBox/AbilityTitle
	if not ability_desc_label and has_node("AbilityBox/AbilityDesc"): ability_desc_label = $AbilityBox/AbilityDesc
	if not footer_label and has_node("FooterBadge/FooterLabel"): footer_label = $FooterBadge/FooterLabel
	if not attack_badge and has_node("AttackBadge"): attack_badge = $AttackBadge
	if not attack_label and has_node("AttackBadge/AttackLabel"): attack_label = $AttackBadge/AttackLabel
	if not hp_badge and has_node("HPBadge"): hp_badge = $HPBadge
	if not hp_label and has_node("HPBadge/HPLabel"): hp_label = $HPBadge/HPLabel
	if not status_tag and has_node("StatusTag"): status_tag = $StatusTag
	if not selection_glow and has_node("SelectionGlow"): selection_glow = $SelectionGlow
	if not playable_glow and has_node("PlayableGlow"): playable_glow = $PlayableGlow
	if not attack_glow and has_node("AttackGlow"): attack_glow = $AttackGlow
	if not status_overlay and has_node("StatusOverlay"): status_overlay = $StatusOverlay

func setup(p_card_data: CardData, p_legacy_art: bool = false) -> void:
	card_data = p_card_data
	use_legacy_art = p_legacy_art
	current_hp = card_data.hp
	max_hp = card_data.max_hp
	current_attack = card_data.attack
	update_ui()

func setup_from_beast(beast_inst) -> void:
	beast_instance_ref = beast_inst
	card_data = beast_inst.card_data
	current_hp = beast_inst.current_hp
	max_hp = beast_inst.max_hp
	current_attack = beast_inst.get_attack()
	is_on_field = true
	update_ui()

func _get_element_symbol(el: String) -> String:
	var clean_el = el.to_lower().replace("_dragon", "").strip_edges()
	match clean_el:
		"fire": return "☀"
		"lightning": return "⚡"
		"wind": return "❖"
		"ice": return "❄"
		"shadow": return "☾"
		"mechanical": return "⚙"
		"water": return "◈"
		"neutral": return "✦"
		_:
			if "_" in clean_el:
				var parts = clean_el.split("_")
				if parts.size() >= 2:
					return _get_element_symbol(parts[0]) + _get_element_symbol(parts[1])
			return "✦"

func _get_symbolic_effect_text() -> String:
	if not card_data:
		return ""
	if card_data.card_type == "stone":
		return "+1  " + _get_element_symbol(card_data.element) + "  " + card_data.element.capitalize() + " Stone"

	match card_data.id:
		"inferno_surge": return "⚔ 5 to Beast  |  ⚔ 4 to Player"
		"lightning_strike": return "⚔ 4 Direct Damage"
		"zephyr_gust": return "⚔ 3 Damage  •  ❖ +1 Card"
		"glacial_freeze": return "⚔ 2 Damage  •  ❄ Freeze (1T)"
		"abyssal_drain": return "⚔ 3 Damage  •  ♥ +3 Life"
		"kinetic_overdrive": return "⚔ +2 ATK  •  ❖ +4 Shield"
		"tidal_surge": return "✨ Cleanse  •  ♥ +6 HP"
		"compass": return "✦ Search Deck ➔ +1 ◈ Stone"
		"draconic_tome": return "✦ Search Deck ➔ +1 ❖ Dragon"
		"ancient_insight": return "✦ Draw 2 Cards (+2 ❖)"
		"draconic_calling": return "◈ -1 Hand ➔ Search 2× ❖ Dragons"
		"soul_rebirth": return "✦ Discard Pile ➔ +1 ❖ Dragon"
		"elemental_convergence": return "✦ Search Deck ➔ +2 ◈ Stones"
		"dragon_elixir": return "♥ +5 HP to Beast"
		"elemental_shield": return "❖ +4 Shield HP"
		"dragon_hoard": return "✦ Draw 3 Cards, Discard 1"
		"elemental_alchemy": return "◈ -1 Stone ➔ Search +2 ◈ Stones"
		"draconic_resurgence": return "✦ Recycle 2 Dragons ➔ +1 Card"
		"call_to_arms": return "✦ Search Deck ➔ +1 Evolved Dragon"
		"elemental_transmutation": return "⚔ +2 ATK  •  ❖ +4 Shield"
		"solar_flare": return "⚔ 4 Target  •  ⚔ 2 Other Foes"
		"static_prison": return "⚡ Paralysis (Flip Heads to Free)"
		"frost_armor": return "❖ +6 Shield  •  ❄ Freezes Attacker"
		"gale_barrier": return "🌪️ Return Friendly ➔ Cleanse & Heal"
		"shadow_pact": return "☾ Sac Friendly ➔ +3 Cards, +2 💧"
		"little_dragon": return "Evolve into any Elemental Dragon (2× ◈)"
		"shadow_dragon": return "☾ Spell Immune"
		"wind_dragon": return "🌪️ On Evolve: Return 1 Beast to Hand"
		"fire_dragon": return "🔥 On Evolve: +3 ATK that turn"
		"lightning_dragon": return "⚡◈ -1 ➔ ⚡ Paralysis (Coin Flip)"
		"ice_dragon": return "❄ On Evolve: Freeze 1 Enemy (1T)"
		"mechanical_dragon": return "⚙ Discard 1 Stone ➔ +2 Cards  •  ☾ Spell Immune"
		"water_dragon": return "◈ -1 ➔ ♥ +5 HP"
		"volcovolt_dragon": return "☀⚡◈ -1 each ➔ ⚔ 8 (×2) + ⚡ Stun"
		"spark_wraith_dragon": return "☾⚡◈ -1 each ➔ ❖ Recover 2 Spells"
		"techno_frost_dragon": return "❄⚙◈ -1 each ➔ ❄ Freeze All + Draw"
		"zephyr_shadow_dragon": return "☾❖◈ -1 each ➔ ⚔×2 Direct Strike"
		"pyro_gale_dragon": return "☀❖◈ -1 each ➔ ⚔ 5 AoE + ⚔×2"
		"blizzard_zephyr_dragon": return "❄❖◈ -1 each ➔ ❄ Freeze 2 + ⚔×2"
		"molten_gear_dragon": return "☀⚙◈ -1 each ➔ ⚔ 6 + ❖ +5 Shield"
		"cyber_volt_dragon": return "⚡⚙◈ -1 each ➔ ⚔ 6 + ⚡ Stun +3 ATK"
		"eclipse_frost_dragon": return "☾❄◈ -1 each ➔ ❄ Freeze All + ♥ +4"
		"transcendent_shadow_dragon": return "☾ Spell Immune  •  ⚔ Direct Pierce"
		"transcendent_fire_dragon": return "☀◈ -2 ➔ ⚔ 6 to All Foes"
		"transcendent_wind_dragon": return "❖◈ -1 ➔ ⚔×3 this turn"
		"transcendent_lightning_dragon": return "⚔ Hits apply ⚡ Stun (1T)"
		"transcendent_ice_dragon": return "❄ Freeze (1T) attackers on hit"
		"transcendent_mechanical_dragon": return "❖ -3 Damage Taken"
		"ascended_volcovolt_dragon": return "☀⚡◈ -2 each ➔ ⚔ 12 (×2) + ⚡ Stun"
		"ascended_spark_wraith_dragon": return "☾⚡◈ -2 each ➔ ❖ Recover All Spells"
		"ascended_techno_frost_dragon": return "❄⚙◈ -2 each ➔ ❄ Freeze All + Draw 2"
		"ascended_zephyr_shadow_dragon": return "☾❖◈ -2 each ➔ ⚔ 10 Split + Direct"
		"god_dragon": return "✦ Banish All Foes  •  ⚔ 10 Direct"

	var raw_desc = ""
	if card_data.ability and not card_data.ability.is_empty():
		raw_desc = card_data.ability.get("description", "")
	if raw_desc == "" and card_data.description != "":
		raw_desc = card_data.description

	var text = raw_desc
	text = text.replace("Immune to all Spell cards.", "☾ Spell Immune")
	text = text.replace("Immune to all Spell cards", "☾ Spell Immune")
	text = text.replace("Discard 1 ", "◈ -1 ➔ ")
	text = text.replace("Spend 1 ", "◈ -1 ➔ ")
	text = text.replace("attack twice", "⚔×2")
	text = text.replace("Applies Stun", "⚡ Stun (1T)")
	text = text.replace("apply Stun", "⚡ Stun (1T)")
	text = text.replace("Freeze", "❄ Freeze (1T)")
	text = text.replace("damage", "⚔")
	text = text.replace("HP", "♥")
	return text

func update_ui() -> void:
	if not card_data:
		return
	_ensure_node_references()
		
	# 1. Select Template Frame by Element & Type
	var template_path = get_template_path(card_data.element, card_data.card_type, card_data.sub_type, card_data.fusion_materials)
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
	
	# 7. Ability Details (Symbol-driven shorthand)
	var symbolic_desc = _get_symbolic_effect_text()
	if card_data.card_type == "stone":
		ability_title_label.text = ""
		ability_desc_label.text = symbolic_desc
	elif card_data.ability and not card_data.ability.is_empty():
		ability_title_label.text = card_data.ability.get("name", "")
		ability_desc_label.text = symbolic_desc
	elif card_data.description != "":
		ability_title_label.text = "EFFECT"
		ability_desc_label.text = symbolic_desc
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
		
	# 9. Footer Badge (Symbolic Evolution / Transcendence / Fusion / Ascension / God info)
	if card_data.id == "god_dragon":
		footer_label.text = "✦ ☀⚡❖❄☾⚙"
		$FooterBadge.visible = true
		_set_rect($FooterBadge, 45, 233, 155, 251)
	elif card_data.sub_type == "ascended_dragon" and card_data.fusion_materials.size() >= 2:
		var m1 = card_data.fusion_materials[0]
		var m2 = card_data.fusion_materials[1]
		footer_label.text = "✦ 3×" + _get_element_symbol(m1) + " + 3×" + _get_element_symbol(m2)
		$FooterBadge.visible = true
		_set_rect($FooterBadge, 45, 233, 155, 251)
	elif card_data.sub_type == "fusion_dragon" and card_data.fusion_materials.size() >= 2:
		var m1 = card_data.fusion_materials[0]
		var m2 = card_data.fusion_materials[1]
		footer_label.text = "❖ " + _get_element_symbol(m1) + " + " + _get_element_symbol(m2)
		$FooterBadge.visible = true
		_set_rect($FooterBadge, 55, 233, 145, 251)
	elif card_data.sub_type == "transcendent_dragon":
		footer_label.text = "★ 5× " + _get_element_symbol(card_data.element)
		$FooterBadge.visible = true
		_set_rect($FooterBadge, 55, 233, 145, 251)
	elif card_data.evolution_stage == 1:
		footer_label.text = "✦ ➔ 2× " + _get_element_symbol(card_data.element)
		$FooterBadge.visible = true
		_set_rect($FooterBadge, 55, 233, 145, 251)
	else:
		$FooterBadge.visible = false
		
	_apply_frame_layout()

	# 10. Status Tag (Hidden during gameplay to keep top dragon crest clean)
	if status_tag:
		status_tag.visible = false
		status_tag.text = card_data.status
		match card_data.status:
			"CONFIRMED":
				status_tag.modulate = Color(0.3, 1.0, 0.4) # Green
			"REMEMBERED":
				status_tag.modulate = Color(1.0, 0.8, 0.2) # Gold
			_:
				status_tag.modulate = Color(0.4, 0.8, 1.0) # Cyan

func _set_rect(c: Control, l: float, t: float, r: float, b: float) -> void:
	if c:
		c.offset_left = l; c.offset_top = t; c.offset_right = r; c.offset_bottom = b

## Aligns text to the plaques baked into each frame family so nothing overlaps.
func _apply_frame_layout() -> void:
	var dark_ink = Color(0.14, 0.09, 0.05, 1.0)
	var dark_shadow = Color(1.0, 0.95, 0.85, 0.45)
	var light_ink = Color(0.96, 0.95, 0.92, 1.0)
	var light_shadow = Color(0.0, 0.0, 0.0, 0.95)
	var gold_title = Color(1.0, 0.88, 0.38, 1.0)
	var dark_title = Color(0.32, 0.16, 0.04, 1.0)

	if is_compact:
		type_label.visible = false
		ability_title_label.visible = false
		ability_desc_label.visible = false
		if has_node("AbilityBox"):
			$AbilityBox.visible = false
		if has_node("FooterBadge"):
			$FooterBadge.visible = false
		if status_tag:
			status_tag.visible = false

		if card_data.card_type == "stone":
			name_label.visible = false
			element_icon.visible = false
			cost_badge.visible = false
		else:
			name_label.visible = true
			_set_rect(name_label, 44, 14, 156, 36)
			if card_data.name.length() <= 14:
				name_label.add_theme_font_size_override("font_size", 12)
			else:
				name_label.add_theme_font_size_override("font_size", 11)
			name_label.add_theme_color_override("font_color", light_ink)
			name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
			name_label.add_theme_constant_override("shadow_outline_size", 4)
			var pill_style = StyleBoxFlat.new()
			pill_style.bg_color = Color(0.05, 0.05, 0.08, 0.68)
			pill_style.corner_radius_top_left = 6
			pill_style.corner_radius_top_right = 6
			pill_style.corner_radius_bottom_left = 6
			pill_style.corner_radius_bottom_right = 6
			name_label.add_theme_stylebox_override("normal", pill_style)

			_set_rect(art_rect, 22, 48, 178, 218)

		if card_data.card_type == "beast":
			attack_label.add_theme_font_size_override("font_size", 18)
			attack_label.add_theme_constant_override("shadow_outline_size", 4)
			hp_label.add_theme_font_size_override("font_size", 18)
			hp_label.add_theme_constant_override("shadow_outline_size", 4)
		return

	# Non-compact (full card inspector / collection / deck builder) mode
	if has_node("AbilityBox"):
		$AbilityBox.visible = true
	name_label.visible = true
	name_label.remove_theme_stylebox_override("normal")
	name_label.add_theme_constant_override("shadow_outline_size", 2)
	type_label.visible = true
	ability_title_label.visible = ability_title_label.text != ""
	ability_desc_label.visible = true
	ability_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ability_desc_label.add_theme_font_size_override("font_size", 10)
	footer_label.add_theme_font_size_override("font_size", 10)

	if card_data.card_type == "beast":
		attack_label.add_theme_font_size_override("font_size", 14)
		attack_label.add_theme_constant_override("shadow_outline_size", 2)
		hp_label.add_theme_font_size_override("font_size", 14)
		hp_label.add_theme_constant_override("shadow_outline_size", 2)

	# Default font sizing for name
	if card_data.name.length() <= 13:
		name_label.add_theme_font_size_override("font_size", 11)
	elif card_data.name.length() <= 17:
		name_label.add_theme_font_size_override("font_size", 9)
	else:
		name_label.add_theme_font_size_override("font_size", 8)

	if card_data.card_type == "stone":
		# Stone templates have full-art monoliths & baked top banner ("FIRE ELEMENT STONE")
		name_label.visible = false
		type_label.visible = false
		ability_title_label.visible = false
		element_icon.visible = false
		cost_badge.visible = false
		ability_desc_label.add_theme_color_override("font_color", dark_ink)
		ability_desc_label.add_theme_color_override("font_shadow_color", dark_shadow)
		_set_rect($AbilityBox, 26, 188, 174, 238)
	elif card_data.card_type == "spell":
		# Spell templates have top banner ("SPELL") and light parchment bottom box
		type_label.visible = false
		element_icon.visible = true
		_set_rect(name_label, 34, 41, 166, 56)
		_set_rect(art_rect, 24, 56, 176, 144)
		ability_title_label.visible = false
		ability_desc_label.add_theme_color_override("font_color", dark_ink)
		ability_desc_label.add_theme_color_override("font_shadow_color", dark_shadow)
		_set_rect($AbilityBox, 26, 160, 174, 232)
	elif card_data.card_type == "support":
		# Support templates have top banner ("Supporter"), middle ribbon, and parchment bottom box
		type_label.visible = false
		element_icon.visible = false
		_set_rect(name_label, 38, 143, 162, 160)
		_set_rect(art_rect, 24, 52, 176, 138)
		ability_title_label.visible = false
		ability_desc_label.add_theme_color_override("font_color", dark_ink)
		ability_desc_label.add_theme_color_override("font_shadow_color", dark_shadow)
		_set_rect($AbilityBox, 26, 170, 174, 234)
	elif card_data.sub_type == "base_dragon" or card_data.element == "neutral":
		# Base Dragon (Little Dragon) has arch sky, middle parchment ribbon, bottom parchment box
		_set_rect(name_label, 42, 34, 158, 50)
		_set_rect(art_rect, 24, 50, 176, 137)
		_set_rect(type_label, 42, 144, 158, 159)
		type_label.add_theme_color_override("font_color", dark_title)
		type_label.add_theme_color_override("font_shadow_color", dark_shadow)
		ability_title_label.add_theme_color_override("font_color", dark_title)
		ability_title_label.add_theme_color_override("font_shadow_color", dark_shadow)
		ability_desc_label.add_theme_color_override("font_color", dark_ink)
		ability_desc_label.add_theme_color_override("font_shadow_color", dark_shadow)
		_set_rect($AbilityBox, 26, 168, 174, 226)
	elif card_data.sub_type == "fusion_dragon" or card_data.sub_type == "ascended_dragon":
		# Half-and-half primary element fusion frames share the exact combat frame geometry
		element_icon.visible = false
		_set_rect(name_label, 52, 41, 148, 56)
		_set_rect(art_rect, 24, 56, 176, 137)
		_set_rect(type_label, 46, 140, 154, 155)
		type_label.add_theme_color_override("font_color", gold_title)
		type_label.add_theme_color_override("font_shadow_color", light_shadow)
		ability_title_label.add_theme_color_override("font_color", gold_title)
		ability_title_label.add_theme_color_override("font_shadow_color", light_shadow)
		ability_desc_label.add_theme_color_override("font_color", light_ink)
		ability_desc_label.add_theme_color_override("font_shadow_color", light_shadow)
		_set_rect($AbilityBox, 26, 159, 174, 224)
	else:
		# Elemental, Transcendent, and God Dragon dark combat frames
		_set_rect(name_label, 52, 41, 148, 56)
		_set_rect(art_rect, 24, 56, 176, 137)
		_set_rect(type_label, 46, 140, 154, 155)
		type_label.add_theme_color_override("font_color", gold_title)
		type_label.add_theme_color_override("font_shadow_color", light_shadow)
		ability_title_label.add_theme_color_override("font_color", gold_title)
		ability_title_label.add_theme_color_override("font_shadow_color", light_shadow)
		ability_desc_label.add_theme_color_override("font_color", light_ink)
		ability_desc_label.add_theme_color_override("font_shadow_color", light_shadow)
		_set_rect($AbilityBox, 26, 159, 174, 224)

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

	# For Stone cards, template is full carved art - no separate illustration overlay
	if card_data.card_type == "stone":
		art_rect.texture = null
		return

	# Remastered or modern artwork (.jpg or .png)
	var art_path_jpg = "res://assets/art/" + card_data.id + ".jpg"
	var art_path_png = "res://assets/art/" + card_data.id + ".png"
	if ResourceLoader.exists(art_path_jpg):
		art_rect.texture = load(art_path_jpg)
		return
	elif ResourceLoader.exists(art_path_png):
		art_rect.texture = load(art_path_png)
		return

	# Ascended dragon fallback to base fusion dragon art
	if card_data.sub_type == "ascended_dragon" and not card_data.ascends_from.is_empty():
		var base_art_jpg = "res://assets/art/" + card_data.ascends_from + ".jpg"
		var base_art_png = "res://assets/art/" + card_data.ascends_from + ".png"
		if ResourceLoader.exists(base_art_jpg):
			art_rect.texture = load(base_art_jpg)
			return
		elif ResourceLoader.exists(base_art_png):
			art_rect.texture = load(base_art_png)
			return

	# Transcendent dragon fallback to base elemental dragon art
	if card_data.sub_type == "transcendent_dragon" and not card_data.evolves_from.is_empty():
		var base_art_jpg = "res://assets/art/" + card_data.evolves_from + ".jpg"
		var base_art_png = "res://assets/art/" + card_data.evolves_from + ".png"
		if ResourceLoader.exists(base_art_jpg):
			art_rect.texture = load(base_art_jpg)
			return
		elif ResourceLoader.exists(base_art_png):
			art_rect.texture = load(base_art_png)
			return

	# Element icon fallback
	var icon_path = "res://assets/icons/" + card_data.element.to_lower() + ".png"
	if ResourceLoader.exists(icon_path):
		art_rect.texture = load(icon_path)
	else:
		art_rect.texture = null

static func get_template_path(element_name: String, ctype: String, subtype: String, fusion_materials: Array[String] = []) -> String:
	# 1. Fusion & Ascended Dragons (15 unique dual-element templates)
	if subtype == "fusion_dragon" or subtype == "ascended_dragon":
		if fusion_materials.size() >= 2:
			var m1 = fusion_materials[0].replace("_dragon", "")
			var m2 = fusion_materials[1].replace("_dragon", "")
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

	# 3. Realm / Location Cards (Elemental Stadium templates with Mana Cost medallion)
	if ctype == "realm":
		var realm_path = "res://assets/templates/realm_" + element_name.to_lower() + ".png"
		if ResourceLoader.exists(realm_path):
			return realm_path
		var fallback_el = "res://assets/templates/template_" + element_name.to_lower() + ".png"
		if ResourceLoader.exists(fallback_el):
			return fallback_el

	# 4. Spell Cards (Elemental spell storm templates)
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
	if subtype == "base_dragon" or element_name == "neutral":
		if ResourceLoader.exists("res://assets/templates/template_little_dragon.png"):
			return "res://assets/templates/template_little_dragon.png"

	# 6. Elemental Dragons & Transcendent Dragons (Elemental dragon combat frames)
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
	if status_name == "paralysis" or status_name == "paralyzed":
		status_overlay.visible = true
		status_label.text = "⚡ PARALYSIS"
		status_overlay.color = Color(0.9, 0.75, 0.1, 0.5)
	elif turns > 0:
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
	if Engine.has_singleton("SoundManager") or has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_card_hover()
	if not is_on_field and hover_zoom:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", base_scale * 1.12, 0.12)
		z_index = 10

func _on_mouse_exited() -> void:
	card_hovered.emit(self, false)
	if not is_on_field and hover_zoom:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", base_scale, 0.12)
		z_index = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_card_click()
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			card_right_clicked.emit(self)
