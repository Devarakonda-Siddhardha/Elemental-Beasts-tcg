class_name CardCollection
extends Control

var card_db: Dictionary = {}
var card_ui_prefab = preload("res://scenes/card_ui.tscn")
var current_filter: String = "all"
var use_legacy: bool = false

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var open_packs_button: Button = $TopBar/OpenPacksButton
@onready var filter_option: OptionButton = $TopBar/FilterOption
@onready var legacy_toggle: CheckButton = $TopBar/LegacyToggle
@onready var back_button: Button = $TopBar/BackButton

@onready var preview_panel: Panel = $PreviewPanel
@onready var preview_card_container: Control = $PreviewPanel/CardHolder
@onready var preview_name: Label = $PreviewPanel/InfoBox/Name
@onready var preview_type: Label = $PreviewPanel/InfoBox/Type
@onready var preview_stats: Label = $PreviewPanel/InfoBox/Stats
@onready var preview_ability: RichTextLabel = $PreviewPanel/InfoBox/AbilityText
@onready var preview_fidelity: Label = $PreviewPanel/InfoBox/Fidelity

func _ready() -> void:
	card_db = CardData.load_database()
	
	back_button.pressed.connect(_on_back_pressed)
	if open_packs_button:
		open_packs_button.pressed.connect(_on_open_packs_pressed)
	legacy_toggle.toggled.connect(_on_legacy_toggled)
	filter_option.item_selected.connect(_on_filter_selected)
	
	setup_filter_options()
	populate_cards()

func setup_filter_options() -> void:
	filter_option.clear()
	filter_option.add_item("All Cards")
	filter_option.add_item("Confirmed 2024 Originals")
	filter_option.add_item("Fusion Dragons")
	filter_option.add_item("Elemental Dragons")
	filter_option.add_item("Spell & Support Cards")
	filter_option.add_item("Element Stones")

func populate_cards() -> void:
	for child in grid_container.get_children():
		child.queue_free()
		
	var cards_list = card_db.values()
	var first_card: CardData = null
	
	for card in cards_list:
		if not matches_filter(card):
			continue
			
		if not first_card:
			first_card = card
			
		var card_ui: CardUI = card_ui_prefab.instantiate()
		grid_container.add_child(card_ui)
		card_ui.setup(card, use_legacy)
		card_ui.card_clicked.connect(func(c): show_card_preview(c.card_data))
		
	if first_card:
		show_card_preview(first_card)

func matches_filter(card: CardData) -> bool:
	match current_filter:
		"Confirmed 2024 Originals":
			return card.status == "CONFIRMED"
		"Fusion Dragons":
			return card.sub_type == "fusion_dragon"
		"Elemental Dragons":
			return card.sub_type == "elemental_dragon" or card.sub_type == "base_dragon"
		"Spell & Support Cards":
			return card.card_type == "spell" or card.card_type == "support"
		"Element Stones":
			return card.card_type == "stone"
		_:
			return true

func show_card_preview(card: CardData) -> void:
	for child in preview_card_container.get_children():
		child.queue_free()
		
	var big_card: CardUI = card_ui_prefab.instantiate()
	preview_card_container.add_child(big_card)
	big_card.setup(card, use_legacy)
	big_card.scale = Vector2(1.25, 1.25)
	
	preview_name.text = card.name
	preview_type.text = card.card_type.to_upper() + " • " + card.sub_type.replace("_", " ").to_upper() + " • " + card.element.to_upper()
	
	if card.card_type == "beast":
		preview_stats.text = "HP: " + str(card.hp) + " | ATTACK: " + str(card.attack)
	elif card.card_type == "stone":
		preview_stats.text = "RESOURCE CARD: " + card.element.to_upper() + " STONE"
	else:
		preview_stats.text = "COST: " + str(card.mana_cost) + " MANA"
		
	var ability_text = ""
	if card.ability and not card.ability.is_empty():
		ability_text += "[b][color=#ffd166]" + card.ability.get("name", "") + "[/color][/b]\n"
		ability_text += card.ability.get("description", "")
	elif card.description != "":
		ability_text += card.description
	preview_ability.text = ability_text
	
	preview_fidelity.text = "HISTORICAL FIDELITY: " + card.status
	match card.status:
		"CONFIRMED":
			preview_fidelity.modulate = Color(0.3, 1.0, 0.4)
		"REMEMBERED":
			preview_fidelity.modulate = Color(1.0, 0.8, 0.2)
		_:
			preview_fidelity.modulate = Color(0.4, 0.8, 1.0)

func _on_filter_selected(idx: int) -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	current_filter = filter_option.get_item_text(idx)
	populate_cards()

func _on_legacy_toggled(toggled: bool) -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	use_legacy = toggled
	populate_cards()

func _on_open_packs_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/pack_opening.tscn")

func _on_back_pressed() -> void:
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_ui_click()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
