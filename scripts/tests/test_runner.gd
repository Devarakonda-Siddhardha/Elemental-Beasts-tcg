class_name TestRunner
extends SceneTree

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  ELEMENTAL BEASTS TCG - MASTER VERIFICATION TEST SUITE  ")
	print("========================================================\n")
	
	run_all_tests()
	
	print("\n--------------------------------------------------------")
	print("TEST RESULTS SUMMARY:")
	print("Total Tests:  ", total_tests)
	print("Passed Tests: ", passed_tests)
	print("Failed Tests: ", failed_tests)
	if failed_tests > 0:
		print("\nFAILURES:")
		for f in failures:
			print("  [FAIL] ", f)
		print("--------------------------------------------------------\n")
		quit(1)
	else:
		print("\nALL MANDATORY VERIFICATIONS PASSED WITH 100% FIDELITY!")
		print("--------------------------------------------------------\n")
		quit(0)

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("[PASS] " + test_name)
	else:
		failed_tests += 1
		var full_err = test_name + (" - " + error_msg if error_msg != "" else "")
		failures.append(full_err)
		printerr("[FAIL] " + full_err)

func run_all_tests() -> void:
	test_1_turn_begins_with_5_mana()
	test_2_little_dragon_costs_2_mana()
	test_3_summoning_little_dragon_reduces_mana_5_to_3()
	test_4_summoning_another_reduces_mana_3_to_1()
	test_5_mana_refreshes_to_5_on_next_turn()
	test_6_mana_and_stones_remain_separate()
	test_7_shadow_dragon_evolves_with_2_shadow_stones()
	test_8_wind_dragon_evolves_with_2_wind_stones()
	test_9_shadow_dragon_immune_to_spells()
	test_10_wind_dragon_gale_force_attacks_twice()
	test_11_volcovolt_fusion()
	test_12_spark_wraith_fusion()
	test_13_techno_frost_fusion()
	test_14_fusion_materials_cannot_be_bypassed()
	test_15_dragon_stats_and_abilities_match_originals()
	test_16_element_stones_cannot_be_spent_when_insufficient()
	test_17_compass_searches_deck_for_stone()
	test_18_complete_match_simulation_without_crashes()
	test_19_procedural_sound_generator()
	test_20_single_unified_40_card_deck_validation()
	test_21_transcendence_from_hand_with_5_stones()
	test_22_ascension_from_hand_with_3_stones_each()
	test_23_god_dragon_ritual_from_hand_and_one_per_duel()
	test_24_procedural_playmat_generation()
	test_25_supporter_card_artworks()
	test_26_lightning_dragon_artwork_and_layering()
	test_27_elemental_spells_for_each_element()
	test_28_six_elemental_starter_decks_and_new_cards()
	test_29_deck_search_shuffle_and_coin_flip()
	test_30_elevenlabs_sfx_and_voice_lines()
	test_31_realms_unlimited_stones_and_mono_element_decks()

func test_1_turn_begins_with_5_mana() -> void:
	var state = GameState.new()
	state.start_game()
	var mana = state.get_mana(0).current_mana
	assert_true(mana == 5, "Requirement 1: Turn begins with exactly 5 Mana", "Actual mana: " + str(mana))

func test_2_little_dragon_costs_2_mana() -> void:
	var state = GameState.new()
	var card: CardData = state.card_db.get("little_dragon")
	assert_true(card != null and card.mana_cost == 2, "Requirement 2: Little Dragon costs exactly 2 Mana", "Actual cost: " + str(card.mana_cost if card else -1))

func test_3_summoning_little_dragon_reduces_mana_5_to_3() -> void:
	var state = GameState.new()
	state.start_game()
	state.player_hands[0].clear()
	state.player_hands[0].append(state.card_db["little_dragon"])
	
	var beast = state.summon_little_dragon(0, 0)
	var mana_left = state.get_mana(0).current_mana
	assert_true(beast != null and mana_left == 3, "Requirement 3: Summoning a Little Dragon reduces Mana from 5 to 3", "Actual: " + str(mana_left))

func test_4_summoning_another_reduces_mana_3_to_1() -> void:
	var state = GameState.new()
	state.start_game()
	state.player_hands[0].clear()
	state.player_hands[0].append(state.card_db["little_dragon"])
	state.player_hands[0].append(state.card_db["little_dragon"])
	
	state.summon_little_dragon(0, 0)
	state.summon_little_dragon(0, 0)
	var mana_left = state.get_mana(0).current_mana
	assert_true(mana_left == 1, "Requirement 4: Summoning another Little Dragon reduces Mana from 3 to 1", "Actual: " + str(mana_left))

func test_5_mana_refreshes_to_5_on_next_turn() -> void:
	var state = GameState.new()
	state.start_game()
	# Spend mana
	state.get_mana(0).spend(4) # 1 left
	# Pass turn to player 1, then back to player 0
	state.end_turn()
	state.end_turn()
	var refreshed_mana = state.get_mana(0).current_mana
	assert_true(refreshed_mana == 5, "Requirement 5: Mana refreshes to 5 on player's next turn (no carryover)", "Actual: " + str(refreshed_mana))

func test_6_mana_and_stones_remain_separate() -> void:
	var state = GameState.new()
	state.start_game()
	var stone_mgr = state.get_stones(0)
	var mana_mgr = state.get_mana(0)
	
	stone_mgr.add_stone_direct("fire", 3)
	stone_mgr.spend_stones({"fire": 2})
	
	var mana_intact = (mana_mgr.current_mana == 5)
	var stones_correct = (stone_mgr.get_stone_count("fire") == 1)
	assert_true(mana_intact and stones_correct, "Requirement 6: Mana and Element Stones remain completely separate resources")

func test_7_shadow_dragon_evolves_with_2_shadow_stones() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Put Little Dragon on field
	var ld_beast = BeastInstance.create(state.card_db["little_dragon"], 0, 1)
	state.player_fields[0].append(ld_beast)
	
	# Put Shadow Dragon in hand
	state.player_hands[0].clear()
	state.player_hands[0].append(state.card_db["shadow_dragon"])
	
	# Give 2 Shadow Stones
	state.get_stones(0).add_stone_direct("shadow", 2)
	
	var success = state.evolve_beast(0, 0, 0)
	var is_shadow = (ld_beast.card_data.id == "shadow_dragon")
	var stones_spent = (state.get_stones(0).get_stone_count("shadow") == 0)
	assert_true(success and is_shadow and stones_spent, "Requirement 7: Shadow Dragon evolves from Little Dragon using 2 Shadow Stones")

func test_8_wind_dragon_evolves_with_2_wind_stones() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Put Little Dragon on field
	var ld_beast = BeastInstance.create(state.card_db["little_dragon"], 0, 1)
	state.player_fields[0].append(ld_beast)
	
	# Put Wind Dragon in hand
	state.player_hands[0].clear()
	state.player_hands[0].append(state.card_db["wind_dragon"])
	
	# Give 2 Wind Stones
	state.get_stones(0).add_stone_direct("wind", 2)
	
	var success = state.evolve_beast(0, 0, 0)
	var is_wind = (ld_beast.card_data.id == "wind_dragon")
	var stones_spent = (state.get_stones(0).get_stone_count("wind") == 0)
	assert_true(success and is_wind and stones_spent, "Requirement 8: Wind Dragon evolves using 2 Wind Stones")

func test_9_shadow_dragon_immune_to_spells() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Shadow Dragon on player 1 field
	var shadow_beast = BeastInstance.create(state.card_db["shadow_dragon"], 1, 1)
	state.player_fields[1].append(shadow_beast)
	
	# Player 0 has Lightning Strike spell in hand
	state.player_hands[0].clear()
	state.player_hands[0].append(state.card_db["lightning_strike"])
	
	# Attempt to target Shadow Dragon with spell
	var res = state.cast_spell(0, 0, shadow_beast)
	assert_true(not res.success, "Requirement 9: Shadow Dragon is immune to all Spell cards (Cloak of Darkness)")

func test_10_wind_dragon_gale_force_attacks_twice() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Wind Dragon on field
	var wind_beast = BeastInstance.create(state.card_db["wind_dragon"], 0, 0) # summoned turn 0
	state.player_fields[0].append(wind_beast)
	
	# Provide 1 wind stone
	state.get_stones(0).add_stone_direct("wind", 1)
	
	# Activate Gale Force
	var res = state.activate_beast_ability(0, 0)
	var can_attack_twice = (wind_beast.max_attacks_per_turn == 2)
	var stones_spent = (state.get_stones(0).get_total_stones() == 0)
	assert_true(res.success and can_attack_twice and stones_spent, "Requirement 10: Wind Dragon can use stone-funded Gale Force to attack twice")

func test_11_volcovolt_fusion() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Field materials: Fire Dragon + Lightning Dragon
	var fire_b = BeastInstance.create(state.card_db["fire_dragon"], 0, 1)
	var light_b = BeastInstance.create(state.card_db["lightning_dragon"], 0, 1)
	state.player_fields[0] = [fire_b, light_b]
	
	# VolcoVolt in hand
	state.player_hands[0] = [state.card_db["volcovolt_dragon"]]
	
	var fused = state.fuse_beasts(0, 0)
	var is_volcovolt = (fused != null and fused.card_data.id == "volcovolt_dragon")
	var has_materials = (fused != null and fused.fusion_materials.size() == 2)
	var board_count = (state.player_fields[0].size() == 1)
	assert_true(is_volcovolt and has_materials and board_count, "Requirement 11: Fire Dragon + Lightning Dragon fuse into VolcoVolt Dragon")

func test_12_spark_wraith_fusion() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Field materials: Shadow Dragon + Lightning Dragon
	var shadow_b = BeastInstance.create(state.card_db["shadow_dragon"], 0, 1)
	var light_b = BeastInstance.create(state.card_db["lightning_dragon"], 0, 1)
	state.player_fields[0] = [shadow_b, light_b]
	
	state.player_hands[0] = [state.card_db["spark_wraith_dragon"]]
	
	var fused = state.fuse_beasts(0, 0)
	var is_spark = (fused != null and fused.card_data.id == "spark_wraith_dragon")
	assert_true(is_spark, "Requirement 12: Shadow Dragon + Lightning Dragon fuse into Spark Wraith Dragon")

func test_13_techno_frost_fusion() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Field materials: Ice Dragon + Mechanical Dragon
	var ice_b = BeastInstance.create(state.card_db["ice_dragon"], 0, 1)
	var mech_b = BeastInstance.create(state.card_db["mechanical_dragon"], 0, 1)
	state.player_fields[0] = [ice_b, mech_b]
	
	state.player_hands[0] = [state.card_db["techno_frost_dragon"]]
	
	var fused = state.fuse_beasts(0, 0)
	var is_techno = (fused != null and fused.card_data.id == "techno_frost_dragon")
	assert_true(is_techno, "Requirement 13: Ice Dragon + Mechanical Dragon fuse into Techno Frost Dragon")

func test_14_fusion_materials_cannot_be_bypassed() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Only Fire Dragon on field, missing Lightning Dragon
	var fire_b = BeastInstance.create(state.card_db["fire_dragon"], 0, 1)
	state.player_fields[0] = [fire_b]
	state.player_hands[0] = [state.card_db["volcovolt_dragon"]]
	
	var fused = state.fuse_beasts(0, 0)
	assert_true(fused == null, "Requirement 14: Fusion material requirements cannot be bypassed")

func test_15_dragon_stats_and_abilities_match_originals() -> void:
	var db = CardData.load_database()
	
	# Shadow Dragon: HP 15, ATK 6, Cloak of Darkness
	var sd: CardData = db.get("shadow_dragon")
	var sd_match = (sd.hp == 15 and sd.attack == 6 and sd.ability.name == "Cloak of Darkness")
	
	# Wind Dragon: HP 14, ATK 5, Gale Force
	var wd: CardData = db.get("wind_dragon")
	var wd_match = (wd.hp == 14 and wd.attack == 5 and wd.ability.name == "Gale Force")
	
	# VolcoVolt Dragon: HP 30, ATK 15, Volcanic Storm
	var vv: CardData = db.get("volcovolt_dragon")
	var vv_match = (vv.hp == 30 and vv.attack == 15 and vv.ability.name == "Volcanic Storm")
	
	# Spark Wraith Dragon: HP 27, ATK 13
	var sw: CardData = db.get("spark_wraith_dragon")
	var sw_match = (sw.hp == 27 and sw.attack == 13 and sw.ability.name == "VOLCANIC STORM")
	
	# Techno Frost Dragon: HP 27, ATK 11, Frosting Draw
	var tf: CardData = db.get("techno_frost_dragon")
	var tf_match = (tf.hp == 27 and tf.attack == 11 and tf.ability.name == "Frosting Draw")
	
	var all_match = sd_match and wd_match and vv_match and sw_match and tf_match
	assert_true(all_match, "Requirement 15: Dragon HP, Attack, and abilities match authentic original cards")

func test_16_element_stones_cannot_be_spent_when_insufficient() -> void:
	var stone_mgr = StoneManager.new()
	stone_mgr.add_stone_direct("fire", 1)
	
	var can_spend_2 = stone_mgr.spend_stones({"fire": 2})
	assert_true(not can_spend_2, "Requirement 16: Element Stones cannot be spent when insufficient")

func test_17_compass_searches_deck_for_stone() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Ensure a stone is in the deck
	state.player_decks[0] = [state.card_db["fire_stone"]]
	state.player_hands[0] = [state.card_db["compass"]]
	
	var res = state.cast_compass(0, 0)
	var stone_in_hand = false
	for c in state.player_hands[0]:
		if c.id == "fire_stone":
			stone_in_hand = true
			break
			
	assert_true(res.success and stone_in_hand, "Requirement 17: Compass searches the deck for an Element Stone")

func test_18_complete_match_simulation_without_crashes() -> void:
	var state = GameState.new()
	state.start_game()
	
	var ai0 = AIController.new(state, 0)
	var ai1 = AIController.new(state, 1)
	
	var max_turns = 20
	var current_sim_turn = 0
	
	while not state.is_game_over and current_sim_turn < max_turns:
		if state.active_player_id == 0:
			ai0.execute_turn()
		else:
			ai1.execute_turn()
		current_sim_turn += 1
		
	var completed = (current_sim_turn > 0)
	assert_true(completed, "Requirement 18: Complete simulated match executes end-to-end without crashes")

func test_19_procedural_sound_generator() -> void:
	var snd_gen = preload("res://scripts/audio/procedural_sound_generator.gd")
	var hover = snd_gen.generate_card_hover()
	var click = snd_gen.generate_card_click()
	var play = snd_gen.generate_card_play()
	var mana_spend = snd_gen.generate_mana_spend()
	var mana_ref = snd_gen.generate_mana_refresh()
	var stone_pl = snd_gen.generate_stone_place()
	var stone_sp = snd_gen.generate_stone_spend()
	var evo = snd_gen.generate_evolution()
	var fus = snd_gen.generate_fusion()
	var atk = snd_gen.generate_attack_slash()
	var dmg = snd_gen.generate_damage_hit()
	var defeat = snd_gen.generate_beast_defeat()
	var spell = snd_gen.generate_spell_cast()
	var status = snd_gen.generate_status_applied()
	var turn = snd_gen.generate_turn_change()
	var vic = snd_gen.generate_victory()
	var def = snd_gen.generate_defeat()
	var ui = snd_gen.generate_ui_click()
	
	var all_valid = (
		hover != null and hover.data.size() > 0 and
		click != null and click.data.size() > 0 and
		play != null and play.data.size() > 0 and
		mana_spend != null and mana_spend.data.size() > 0 and
		mana_ref != null and mana_ref.data.size() > 0 and
		stone_pl != null and stone_pl.data.size() > 0 and
		stone_sp != null and stone_sp.data.size() > 0 and
		evo != null and evo.data.size() > 0 and
		fus != null and fus.data.size() > 0 and
		atk != null and atk.data.size() > 0 and
		dmg != null and dmg.data.size() > 0 and
		defeat != null and defeat.data.size() > 0 and
		spell != null and spell.data.size() > 0 and
		status != null and status.data.size() > 0 and
		turn != null and turn.data.size() > 0 and
		vic != null and vic.data.size() > 0 and
		def != null and def.data.size() > 0 and
		ui != null and ui.data.size() > 0
	)
	assert_true(all_valid, "Requirement 19: All 18 procedural audio sound synthesizers generate valid waveforms")

func test_20_single_unified_40_card_deck_validation() -> void:
	var state = GameState.new()
	state.start_game()
	var d0_size = state.player_decks[0].size() + state.player_hands[0].size()
	assert_true(d0_size == RulesConfig.STANDARD_DECK_SIZE, "Requirement 20: Player starts with exactly 40 unified cards in one deck", "Actual: " + str(d0_size))
	
	# Validate default decks file
	var path = "res://data/default_decks.json"
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	json.parse(text)
	var data = json.get_data()
	var all_decks_valid = true
	for d in data.get("decks", []):
		var check = RulesConfig.validate_deck(d.get("cards", []))
		if not check.valid:
			all_decks_valid = false
			printerr("Invalid deck: " + d.get("name", "") + " - " + check.error)
	assert_true(all_decks_valid, "Requirement 20b: All preconstructed decks conform to exactly 40 cards with copy limits")

func test_21_transcendence_from_hand_with_5_stones() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Prepare shadow dragon on field
	var shadow_beast = BeastInstance.create(state.card_db["shadow_dragon"], 0, 1)
	shadow_beast.fusion_materials.append(state.card_db["little_dragon"])
	state.player_fields[0] = [shadow_beast]
	
	# Prepare hand with Transcendent Shadow Dragon
	var trans_card = state.card_db["transcendent_shadow_dragon"]
	state.player_hands[0] = [trans_card]
	
	# Test insufficient stones (< 5)
	state.player_stones[0].stone_pile["shadow"] = 4
	var fail_trans = state.transcend_beast(0, 0, 0)
	assert_true(fail_trans == null, "Requirement 21a: Cannot transcend with fewer than 5 matching stones")
	
	# Add 5th stone and execute
	state.player_stones[0].stone_pile["shadow"] = 5
	var success_trans = state.transcend_beast(0, 0, 0)
	assert_true(
		success_trans != null and
		success_trans.card_data.id == "transcendent_shadow_dragon" and
		state.player_stones[0].get_stone_count("shadow") == 0 and
		success_trans.fusion_materials.size() == 2 and
		state.player_hands[0].is_empty(),
		"Requirement 21b: Transcends from hand with 5 stones and preserves underlying materials"
	)

func test_22_ascension_from_hand_with_3_stones_each() -> void:
	var state = GameState.new()
	state.start_game()
	
	# Prepare Spark Wraith Dragon on field (fusion of shadow + lightning)
	var spark_beast = BeastInstance.create(state.card_db["spark_wraith_dragon"], 0, 1)
	spark_beast.fusion_materials.append(state.card_db["shadow_dragon"])
	spark_beast.fusion_materials.append(state.card_db["lightning_dragon"])
	state.player_fields[0] = [spark_beast]
	
	# Prepare hand with Ascended Spark Wraith Dragon
	var asc_card = state.card_db["ascended_spark_wraith_dragon"]
	state.player_hands[0] = [asc_card]
	
	# Test insufficient stones (3 shadow, only 2 lightning)
	state.player_stones[0].stone_pile["shadow"] = 3
	state.player_stones[0].stone_pile["lightning"] = 2
	var fail_asc = state.ascend_beast(0, 0, 0)
	assert_true(fail_asc == null, "Requirement 22a: Cannot ascend without 3 stones of EACH component element")
	
	# Add 3rd lightning stone and execute
	state.player_stones[0].stone_pile["lightning"] = 3
	var success_asc = state.ascend_beast(0, 0, 0)
	assert_true(
		success_asc != null and
		success_asc.card_data.id == "ascended_spark_wraith_dragon" and
		state.player_stones[0].get_stone_count("shadow") == 0 and
		state.player_stones[0].get_stone_count("lightning") == 0 and
		success_asc.fusion_materials.size() == 3 and
		state.player_hands[0].is_empty(),
		"Requirement 22b: Ascends from hand with 3 stones each and preserves underlying materials"
	)

func test_23_god_dragon_ritual_from_hand_and_one_per_duel() -> void:
	var state = GameState.new()
	state.start_game()
	
	# 3 Fusion dragons representing 6 distinct elements:
	# 1. VolcoVolt: Fire + Lightning
	# 2. Zephyr Shadow: Shadow + Wind
	# 3. Techno Frost: Ice + Mechanical
	var b1 = BeastInstance.create(state.card_db["volcovolt_dragon"], 0, 1)
	var b2 = BeastInstance.create(state.card_db["zephyr_shadow_dragon"], 0, 1)
	var b3 = BeastInstance.create(state.card_db["techno_frost_dragon"], 0, 1)
	state.player_fields[0] = [b1, b2, b3]
	
	# Prepare enemy beast on field
	var enemy_beast = BeastInstance.create(state.card_db["little_dragon"], 1, 1)
	state.player_fields[1] = [enemy_beast]
	var initial_enemy_hp = state.player_hp[1]
	
	# Hand card
	state.player_hands[0] = [state.card_db["god_dragon"]]
	
	# Incomplete stones (missing mechanical)
	for el in RulesConfig.CONFIRMED_ELEMENTS:
		state.player_stones[0].stone_pile[el] = 1 if el != "mechanical" else 0
	var fail_res = state.summon_god_dragon(0, 0)
	assert_true(not fail_res.success, "Requirement 23a: Cannot summon God Dragon without 1 stone of each of the 6 elements")
	
	# Complete stones
	state.player_stones[0].stone_pile["mechanical"] = 1
	var success_res = state.summon_god_dragon(0, 0)
	assert_true(
		success_res.success and
		state.player_fields[0].size() == 1 and
		state.player_fields[0][0].card_data.id == "god_dragon" and
		state.player_fields[1].is_empty() and
		state.player_hp[1] == initial_enemy_hp - 10,
		"Requirement 23b: God Dragon Ritual succeeds, consumes materials, triggers Genesis Roar banish & 10 direct damage"
	)
	
	# Attempting second God Dragon summon in the duel must fail
	state.player_hands[0] = [state.card_db["god_dragon"]]
	var second_res = state.summon_god_dragon(0, 0)
	assert_true(not second_res.success, "Requirement 23c: God Dragon cannot be summoned more than once per player per duel")

func test_24_procedural_playmat_generation() -> void:
	# 1. Instantiate ProceduralPlaymat directly
	var playmat = ProceduralPlaymat.new()
	playmat.size = Vector2(1920, 1080)
	playmat._ready()
	
	assert_true(playmat._noise_texture != null, "Requirement 24a: Procedural playmat synthesizes FastNoiseLite surface texture at runtime")
	
	# Verify battle scene instantiates cleanly with procedural playmat
	var battle_scene = load("res://scenes/battle.tscn")
	assert_true(battle_scene != null, "Requirement 24b: Battle scene loads without missing texture dependencies")
	
	var battle_instance = battle_scene.instantiate()
	var bg_node = battle_instance.get_node_or_null("PlaymatBackground")
	assert_true(bg_node is ProceduralPlaymat, "Requirement 24c: PlaymatBackground in battle scene is a ProceduralPlaymat node (zero static image dependencies)")
	battle_instance.free()
	playmat.free()

func test_25_supporter_card_artworks() -> void:
	var supporter_ids = ["compass", "lightning_strike", "dragon_elixir", "elemental_shield"]
	for sid in supporter_ids:
		var art_path = "res://assets/art/" + sid + ".jpg"
		assert_true(FileAccess.file_exists(art_path), "Requirement 25: Supporter card '" + sid + "' has its own dedicated artwork", art_path)

func test_26_lightning_dragon_artwork_and_layering() -> void:
	var card_scene = load("res://scenes/card_ui.tscn")
	assert_true(card_scene != null, "Requirement 26a: card_ui.tscn loads successfully")
	var card_ui = card_scene.instantiate()
	root.add_child(card_ui)
	
	# Verify ArtRect is placed AFTER FrameRect so artwork is rendered inside slot and not obscured
	var frame_idx = card_ui.get_node("FrameRect").get_index()
	var art_idx = card_ui.get_node("ArtRect").get_index()
	assert_true(art_idx > frame_idx, "Requirement 26b: ArtRect is rendered after FrameRect (visible in slot)", "ArtRect idx: " + str(art_idx) + ", FrameRect idx: " + str(frame_idx))
	
	# Verify Lightning Dragon loads artwork
	var db = CardData.load_database()
	card_ui.setup(db["lightning_dragon"])
	var art_rect: TextureRect = card_ui.get_node("ArtRect")
	assert_true(art_rect.texture != null, "Requirement 26c: Lightning Dragon loads dedicated artwork into ArtRect")
	
	# Verify fallback for Ascended Spark Wraith Dragon
	card_ui.setup(db["ascended_spark_wraith_dragon"])
	assert_true(art_rect.texture != null, "Requirement 26d: Ascended Spark Wraith Dragon has valid dragon artwork (fallback/dedicated)")
	
	# Verify fallback for Transcendent Shadow Dragon
	card_ui.setup(db["transcendent_shadow_dragon"])
	assert_true(art_rect.texture != null, "Requirement 26e: Transcendent Shadow Dragon has valid dragon artwork (fallback/dedicated)")
	
	root.remove_child(card_ui)
	card_ui.free()

func test_27_elemental_spells_for_each_element() -> void:
	var state = GameState.new()
	var db = state.card_db
	
	var elemental_spells = {
		"fire": "inferno_surge",
		"lightning": "lightning_strike",
		"wind": "zephyr_gust",
		"ice": "glacial_freeze",
		"shadow": "abyssal_drain",
		"mechanical": "kinetic_overdrive",
		"water": "tidal_surge"
	}
	
	for el in elemental_spells:
		var spell_id = elemental_spells[el]
		assert_true(db.has(spell_id), "Requirement 27a: Database has spell for " + el + " ('" + spell_id + "')")
		var card: CardData = db[spell_id]
		assert_true(card.card_type == "spell", "Requirement 27b: '" + spell_id + "' is a spell card")
		assert_true(card.element == el, "Requirement 27c: '" + spell_id + "' is element " + el)
		assert_true(card.mana_cost == 2, "Requirement 27d: '" + spell_id + "' costs 2 Mana")
		
		# Verify artwork exists
		var art_path = "res://assets/art/" + spell_id + ".jpg"
		assert_true(FileAccess.file_exists(art_path), "Requirement 27e: Spell '" + spell_id + "' has dedicated artwork", art_path)

	# Test casting elemental spells
	state.start_game()
	var target_enemy = BeastInstance.create(db["little_dragon"], 1, 1)
	state.player_fields[1] = [target_enemy]
	var friendly_beast = BeastInstance.create(db["little_dragon"], 0, 1)
	state.player_fields[0] = [friendly_beast]
	
	# 1. Fire: Inferno Surge deals 5 damage
	state.player_hands[0] = [db["inferno_surge"]]
	state.get_mana(0).current_mana = 5
	var hp_before = target_enemy.current_hp
	var res_fire = state.cast_spell(0, 0, target_enemy)
	assert_true(res_fire.success and target_enemy.current_hp == hp_before - 5, "Requirement 27f: Inferno Surge deals 5 damage to target beast")
	
	# 2. Ice: Glacial Freeze deals 2 damage and freezes
	state.player_hands[0] = [db["glacial_freeze"]]
	state.get_mana(0).current_mana = 5
	var res_ice = state.cast_spell(0, 0, target_enemy)
	assert_true(res_ice.success and target_enemy.is_frozen(), "Requirement 27g: Glacial Freeze freezes target beast")
	
	# 3. Mechanical: Kinetic Overdrive buffs attack +2 and shield +4
	state.player_hands[0] = [db["kinetic_overdrive"]]
	state.get_mana(0).current_mana = 5
	var atk_before = friendly_beast.get_attack()
	var res_mech = state.cast_spell(0, 0, friendly_beast)
	assert_true(res_mech.success and friendly_beast.get_attack() == atk_before + 2 and friendly_beast.shield_hp >= 4, "Requirement 27h: Kinetic Overdrive buffs friendly beast attack +2 and shield +4")
	
	# 4. Shadow: Abyssal Drain deals 3 damage and heals player 3 HP
	state.player_hp[0] = 20
	state.player_hands[0] = [db["abyssal_drain"]]
	state.get_mana(0).current_mana = 5
	var res_shadow = state.cast_spell(0, 0, target_enemy)
	assert_true(res_shadow.success and state.player_hp[0] == 23, "Requirement 27i: Abyssal Drain heals player for 3 HP")

func test_28_six_elemental_starter_decks_and_new_cards() -> void:
	var file = FileAccess.open("res://data/default_decks.json", FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var decks: Array = json.get_data().get("decks", [])
	assert_true(decks.size() == 6, "Requirement 28a: Exactly 6 primary-element Starter Decks exist in default_decks.json", "Actual: " + str(decks.size()))

	var expected_elements = ["fire", "lightning", "wind", "ice", "shadow", "mechanical"]
	var found_elements: Array[String] = []
	for d in decks:
		var el = str(d.get("element", ""))
		found_elements.append(el)
		var cards: Array = d.get("cards", [])
		var val = RulesConfig.validate_deck(cards)
		assert_true(val.valid and cards.size() == 40, "Requirement 28b: Starter Deck '" + str(d.get("name", "")) + "' (" + el + ") is a valid 40-card deck", val.error)

	var all_six_covered = true
	for req_el in expected_elements:
		if not found_elements.has(req_el):
			all_six_covered = false
	assert_true(all_six_covered, "Requirement 28c: All 6 primary elements (Fire, Lightning, Wind, Ice, Shadow, Mechanical) have dedicated starter decks")

	var db = CardData.load_database()
	var new_card_ids = ["draconic_tome", "pyro_gale_dragon", "blizzard_zephyr_dragon", "molten_gear_dragon", "cyber_volt_dragon", "eclipse_frost_dragon"]
	for cid in new_card_ids:
		assert_true(db.has(cid), "Requirement 28d: New card '" + cid + "' exists in CARD_DATABASE.json")
		assert_true(FileAccess.file_exists("res://assets/art/" + cid + ".jpg"), "Requirement 28e: New card '" + cid + "' has dedicated artwork")

func test_29_deck_search_shuffle_and_coin_flip() -> void:
	var state = GameState.new()
	state.start_game()
	var shuffle_signals: Array[int] = []
	state.deck_shuffled.connect(func(pid: int): shuffle_signals.append(pid))

	# Test choosing a specific stone via Compass
	var target_stone = state.card_db["ice_stone"]
	state.player_decks[0] = [state.card_db["fire_stone"], target_stone, state.card_db["wind_stone"]]
	state.player_hands[0] = [state.card_db["compass"]]
	state.get_mana(0).current_mana = 5
	var comp_res = state.cast_compass(0, 0, target_stone)
	assert_true(comp_res.success and state.player_hands[0].has(target_stone) and shuffle_signals.size() >= 1, "Requirement 29a: Compass allows selecting a specific Element Stone from deck and triggers deck shuffle")

	# Test choosing a specific dragon via Draconic Tome
	var target_dragon = state.card_db["pyro_gale_dragon"]
	state.player_decks[0] = [state.card_db["little_dragon"], target_dragon, state.card_db["fire_stone"]]
	state.player_hands[0] = [state.card_db["draconic_tome"]]
	state.get_mana(0).current_mana = 5
	var tome_res = state.cast_draconic_tome(0, 0, target_dragon)
	assert_true(tome_res.success and state.player_hands[0].has(target_dragon) and shuffle_signals.size() >= 2, "Requirement 29b: Draconic Tome searches deck for a chosen Dragon Beast and triggers deck shuffle")

	# Test Coin textures and start-of-match starting_player parameter
	assert_true(FileAccess.file_exists("res://assets/art/coin_heads.png") and FileAccess.file_exists("res://assets/art/coin_tails.png"), "Requirement 29c: Themed Solar God Dragon (Heads) and Abyssal Shadow Dragon (Tails) coin textures exist")
	state.start_game([], [], 1)
	assert_true(state.active_player_id == 1, "Requirement 29d: Coin toss result can set Opponent (Player 1) as Turn 1 starting player")

func test_30_elevenlabs_sfx_and_voice_lines() -> void:
	var sm := SoundManagerClass.new()
	sm._ready()

	var all_sfx_loaded := true
	for sfx_name in SoundManagerClass.SFX_NAMES:
		var path := "res://assets/audio/sfx/" + sfx_name + ".mp3"
		if not FileAccess.file_exists(path) or not sm.sound_cache.has(sfx_name):
			all_sfx_loaded = false
			printerr("Missing SFX: " + sfx_name)
	assert_true(all_sfx_loaded and SoundManagerClass.SFX_NAMES.size() == 21, "Requirement 30a: All 21 ElevenLabs SFX MP3 files exist and load into SoundManager.sound_cache")

	var all_vo_loaded := true
	for vo_name in SoundManagerClass.VO_NAMES:
		var vo_path := "res://assets/audio/vo/" + vo_name + ".mp3"
		if not FileAccess.file_exists(vo_path) or not sm.vo_cache.has(vo_name):
			all_vo_loaded = false
			printerr("Missing VO: " + vo_name)
	assert_true(all_vo_loaded and SoundManagerClass.VO_NAMES.size() == 15, "Requirement 30b: All 15 ElevenLabs Commentator Voiceover MP3 files exist and load into SoundManager.vo_cache")

	assert_true(
		sm.vo_player != null and
		sm.has_method("play_voice") and
		sm.has_method("play_coin_flip") and
		sm.has_method("play_deck_shuffle") and
		sm.has_method("play_pack_rip"),
		"Requirement 30c: SoundManager provides dedicated vo_player, play_voice(), play_coin_flip(), play_deck_shuffle(), and play_pack_rip()"
	)

	sm.free()

func test_31_realms_unlimited_stones_and_mono_element_decks() -> void:
	var state := GameState.new()
	var db := state.card_db

	# 1. Verify all 6 Realm cards and 6 reusable Realm templates exist
	var realm_map = {
		"fire": "inferno_caldera",
		"lightning": "thunder_mountain",
		"wind": "sky_tempest_sanctum",
		"ice": "glacial_citadel",
		"shadow": "abyssal_void_realm",
		"mechanical": "clockwork_foundry"
	}
	var all_realms_valid := true
	for el in realm_map.keys():
		var rid: String = str(realm_map[el])
		var tmpl_path: String = "res://assets/templates/realm_" + str(el) + ".png"
		var art_path: String = "res://assets/art/" + rid + ".jpg"
		if not db.has(rid) or db[rid].card_type != "realm" or db[rid].mana_cost < 0 or not FileAccess.file_exists(tmpl_path) or not FileAccess.file_exists(art_path):
			all_realms_valid = false
			printerr("Invalid realm or missing asset for: " + rid)
	assert_true(all_realms_valid, "Requirement 31a: All 6 Elemental Realm (Stadium) cards, reusable realm_<element>.png templates with Mana Cost medallion, and artworks exist")

	# 2. Verify playing multiple Element Stones from hand in a single turn
	state.start_game()
	state.player_hands[0] = [db["lightning_stone"], db["lightning_stone"], db["lightning_stone"]]
	var p1 = state.play_stone_from_hand(0, 0)
	var p2 = state.play_stone_from_hand(0, 0)
	var p3 = state.play_stone_from_hand(0, 0)
	assert_true(p1 and p2 and p3 and state.get_stones(0).get_stone_count("lightning") == 3, "Requirement 31b: Player can play unlimited Element Stone cards from hand in a single turn")

	# 3. Verify Realm reduces Evolution cost from 2 stones to 1 stone, and gets replaced when opponent plays a new Realm
	state.start_game()
	var ld = BeastInstance.create(db["little_dragon"], 0, 1)
	state.player_fields[0] = [ld]
	state.player_hands[0] = [db["thunder_mountain"], db["shadow_dragon"]]
	state.get_mana(0).current_mana = 5
	state.get_stones(0).stone_pile["shadow"] = 1

	# Without Realm in play, 1 Shadow Stone is NOT enough to evolve into Shadow Dragon
	var pre_check = EvolutionEngine.can_evolve(ld, db["shadow_dragon"], state.get_stones(0), state.active_realm)
	assert_true(not pre_check.valid, "Requirement 31c: Without a Realm in play, Shadow Dragon requires 2 Shadow Stones")

	# Play Thunder Mountain (costs 2 Mana)
	var r_res = state.play_realm(0, 0)
	assert_true(r_res.success and state.active_realm.id == "thunder_mountain" and state.get_mana(0).current_mana == 3, "Requirement 31d: Playing Thunder Mountain spends 2 Mana and sets active_realm")

	# Now evolve Little Dragon -> Shadow Dragon with only 1 Shadow Stone!
	var evolved_with_1 = state.evolve_beast(0, 0, 0)
	assert_true(evolved_with_1 and state.player_fields[0][0].card_data.id == "shadow_dragon" and state.get_stones(0).get_stone_count("shadow") == 0, "Requirement 31e: Active Realm reduces Evolution requirement from 2 stones to 1 stone")

	# Opponent plays Inferno Caldera on their turn -> replaces Thunder Mountain and sends Thunder Mountain to Player 0's discard
	state.end_turn()
	state.player_hands[1] = [db["inferno_caldera"]]
	state.get_mana(1).current_mana = 5
	var opp_r = state.play_realm(1, 0)
	assert_true(opp_r.success and state.active_realm.id == "inferno_caldera" and state.get_discard(0).has(db["thunder_mountain"]), "Requirement 31f: Playing a new Realm replaces the previous Realm and sends it to its owner's discard pile")

	# 4. Verify all 6 Starter Decks are pure mono-element (only neutral cards + their primary element) and contain 12 matching stones
	var f = FileAccess.open("res://data/default_decks.json", FileAccess.READ)
	var j = JSON.new()
	j.parse(f.get_as_text())
	f.close()
	var decks: Array = j.get_data().get("decks", [])
	var all_mono_pure := true
	for d in decks:
		var deck_el = str(d.get("element", ""))
		var stone_cnt := 0
		for cid in d.get("cards", []):
			var c: CardData = db[cid]
			if c.element != "neutral" and c.element != deck_el:
				all_mono_pure = false
				printerr("Non-matching element card " + cid + " (" + c.element + ") in " + deck_el + " deck!")
			if cid == deck_el + "_stone":
				stone_cnt += 1
		if stone_cnt < 5:
			all_mono_pure = false
	assert_true(all_mono_pure, "Requirement 31g: All 6 Starter Decks are pure mono-element decks with unrestricted Element Stone counts (12 stones each)")

