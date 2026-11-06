class_name CardData
extends RefCounted

var id: String = ""
var name: String = ""
var card_type: String = "" # "beast", "spell", "stone", "support"
var sub_type: String = ""  # "base_dragon", "elemental_dragon", "fusion_dragon", "element_stone", etc.
var element: String = "neutral"
var mana_cost: int = 0
var stone_cost: Dictionary = {} # e.g. {"shadow": 2}
var hp: int = 0
var max_hp: int = 0
var attack: int = 0
var ability: Dictionary = {}
var evolution_stage: int = 0 # 0 = base, 1 = elemental, 2 = fusion, 3 = transcendent, 4 = ascended, 5 = god
var evolves_from: String = ""
var ascends_from: String = ""
var fusion_materials: Array[String] = []
var description: String = ""
var status: String = "CONFIRMED" # "CONFIRMED", "REMEMBERED", "PROVISIONAL"

static func from_dict(dict: Dictionary) -> CardData:
	var card = CardData.new()
	card.id = dict.get("id", "")
	card.name = dict.get("name", "")
	card.card_type = dict.get("card_type", "")
	card.sub_type = dict.get("sub_type", "")
	card.element = dict.get("element", "neutral")
	card.mana_cost = dict.get("mana_cost", 0)
	card.stone_cost = dict.get("stone_cost", {}).duplicate()
	card.hp = dict.get("hp", 0)
	card.max_hp = dict.get("max_hp", card.hp)
	card.attack = dict.get("attack", 0)
	card.ability = dict.get("ability", {}).duplicate(true)
	card.evolution_stage = dict.get("evolution_stage", 0)
	card.evolves_from = dict.get("evolves_from", "") if dict.get("evolves_from") != null else ""
	card.ascends_from = dict.get("ascends_from", "") if dict.get("ascends_from") != null else ""
	
	card.fusion_materials.clear()
	if dict.has("fusion_materials"):
		for mat in dict["fusion_materials"]:
			card.fusion_materials.append(str(mat))
			
	card.description = dict.get("description", "")
	card.status = dict.get("status", "PROVISIONAL")
	return card

static func load_database(file_path: String = "res://data/CARD_DATABASE.json") -> Dictionary:
	var database: Dictionary = {}
	if not FileAccess.file_exists(file_path):
		printerr("Card database file not found at: ", file_path)
		return database
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_err = json.parse(text)
	if parse_err != OK:
		printerr("Failed to parse card database JSON: ", json.get_error_message())
		return database
		
	var data = json.get_data()
	if data.has("cards") and data["cards"] is Array:
		for card_dict in data["cards"]:
			var card_obj = CardData.from_dict(card_dict)
			database[card_obj.id] = card_obj
			
	return database
