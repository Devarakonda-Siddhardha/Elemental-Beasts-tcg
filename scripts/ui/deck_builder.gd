class_name DeckBuilder
extends Control

var card_db: Dictionary = {}
var decks_data: Dictionary = {}
var current_deck_cards: Array[String] = []
var card_ui_prefab = preload("res://scenes/card_ui.tscn")

@onready var deck_option: OptionButton = $TopBar/DeckOption
@onready var back_button: Button = $TopBar/BackButton
@onready var save_button: Button = $TopBar/SaveButton
@onready var deck_count_label: Label = $TopBar/CountLabel
@onready var deck_container: HBoxContainer = $DeckScroll/DeckContainer
@onready var catalog_container: GridContainer = $CatalogScroll/CatalogContainer

func _ready() -> void:
	card_db = CardData.load_database()
	load_decks_file()
	
	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	deck_option.item_selected.connect(_on_deck_selected)
	
	setup_deck_options()
	populate_catalog()
	load_selected_deck(0)

func load_decks_file() -> void:
	var path = "res://data/default_decks.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var text = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(text) == OK:
			decks_data = json.get_data()

func setup_deck_options() -> void:
	deck_option.clear()
	if decks_data.has("decks"):
		for d in decks_data["decks"]:
			deck_option.add_item(d.get("name", "Custom Deck"))

func _on_deck_selected(idx: int) -> void:
	load_selected_deck(idx)

func load_selected_deck(idx: int) -> void:
	current_deck_cards.clear()
	if decks_data.has("decks") and idx < decks_data["decks"].size():
		var d = decks_data["decks"][idx]
		for cid in d.get("cards", []):
			current_deck_cards.append(str(cid))
	refresh_deck_view()

func refresh_deck_view() -> void:
	for child in deck_container.get_children():
		child.queue_free()
		
	deck_count_label.text = "DECK: " + str(current_deck_cards.size()) + " CARDS"
	
	for i in range(current_deck_cards.size()):
		var cid = current_deck_cards[i]
		if card_db.has(cid):
			var card_ui: CardUI = card_ui_prefab.instantiate()
			deck_container.add_child(card_ui)
			card_ui.setup(card_db[cid])
			var rem_idx = i
			card_ui.card_clicked.connect(func(c): remove_card_from_deck(rem_idx))

func populate_catalog() -> void:
	for child in catalog_container.get_children():
		child.queue_free()
		
	for card in card_db.values():
		var card_ui: CardUI = card_ui_prefab.instantiate()
		catalog_container.add_child(card_ui)
		card_ui.setup(card)
		card_ui.card_clicked.connect(func(c): add_card_to_deck(c.card_data.id))

func add_card_to_deck(cid: String) -> void:
	if current_deck_cards.size() < 40:
		current_deck_cards.append(cid)
		refresh_deck_view()

func remove_card_from_deck(idx: int) -> void:
	if idx >= 0 and idx < current_deck_cards.size():
		current_deck_cards.remove_at(idx)
		refresh_deck_view()

func _on_save_pressed() -> void:
	deck_count_label.text = "SAVED! (" + str(current_deck_cards.size()) + " cards)"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
