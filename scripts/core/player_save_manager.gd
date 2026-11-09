class_name PlayerSaveManager
extends RefCounted

const SAVE_PATH: String = "user://player_save.json"

static func get_default_data() -> Dictionary:
	return {
		"player_name": "Player",
		"level": 1,
		"xp": 0,
		"gold": 500,
		"gems": 50,
		"wins": 0,
		"losses": 0,
		"packs_opened": 0,
		"bosses_defeated": []
	}

static func load_save() -> Dictionary:
	var data = get_default_data()
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(text) == OK and json.get_data() is Dictionary:
				var loaded = json.get_data()
				for k in loaded.keys():
					data[k] = loaded[k]
	return data

static func save_data(data: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func add_xp(amount: int) -> Dictionary:
	var d = load_save()
	d["xp"] = int(d.get("xp", 0)) + amount
	var cur_lvl = int(d.get("level", 1))
	var req_xp = cur_lvl * 100
	var leveled_up = false
	while d["xp"] >= req_xp:
		d["xp"] -= req_xp
		cur_lvl += 1
		req_xp = cur_lvl * 100
		leveled_up = true
		d["gold"] = int(d.get("gold", 0)) + 100
		d["gems"] = int(d.get("gems", 0)) + 15
	d["level"] = cur_lvl
	save_data(d)
	return {"level": cur_lvl, "xp": d["xp"], "leveled_up": leveled_up}

static func record_match(won: bool, gold_reward: int = 50, xp_reward: int = 50) -> Dictionary:
	var d = load_save()
	if won:
		d["wins"] = int(d.get("wins", 0)) + 1
		d["gold"] = int(d.get("gold", 0)) + gold_reward
	else:
		d["losses"] = int(d.get("losses", 0)) + 1
		d["gold"] = int(d.get("gold", 0)) + int(gold_reward * 0.3)
	save_data(d)
	var xp_res = add_xp(xp_reward if won else int(xp_reward * 0.4))
	return {"won": won, "level": xp_res["level"], "xp": xp_res["xp"]}

static func record_boss_defeat(boss_id: String) -> void:
	var d = load_save()
	var bosses: Array = d.get("bosses_defeated", [])
	if not bosses.has(boss_id):
		bosses.append(boss_id)
		d["bosses_defeated"] = bosses
		d["gold"] = int(d.get("gold", 0)) + 250
		d["gems"] = int(d.get("gems", 0)) + 50
		save_data(d)
		add_xp(200)

static func get_display_profile() -> String:
	var d = load_save()
	return "%s / Lv. %d" % [d.get("player_name", "Player"), d.get("level", 1)]
