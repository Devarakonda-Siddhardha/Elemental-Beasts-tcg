class_name MainMenu
extends Control

@onready var vs_ai_button: Button = $VBoxContainer/VsAIButton
@onready var pvp_button: Button = $VBoxContainer/PvPButton
@onready var deck_builder_button: Button = $VBoxContainer/DeckBuilderButton
@onready var collection_button: Button = $VBoxContainer/CollectionButton
@onready var test_suite_button: Button = $VBoxContainer/TestSuiteButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	vs_ai_button.pressed.connect(_on_vs_ai_pressed)
	pvp_button.pressed.connect(_on_pvp_pressed)
	deck_builder_button.pressed.connect(_on_deck_builder_pressed)
	collection_button.pressed.connect(_on_collection_pressed)
	test_suite_button.pressed.connect(_on_test_suite_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_vs_ai_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_pvp_pressed() -> void:
	var battle_scene = load("res://scenes/battle.tscn").instantiate()
	battle_scene.is_vs_ai = false
	get_tree().root.add_child(battle_scene)
	queue_free()

func _on_deck_builder_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/deck_builder.tscn")

func _on_collection_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/card_collection.tscn")

func _on_test_suite_pressed() -> void:
	# Run verification tests
	var test_runner = TestRunner.new()

func _on_quit_pressed() -> void:
	get_tree().quit()
