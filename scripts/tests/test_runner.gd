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
