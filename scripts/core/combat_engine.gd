class_name CombatEngine
extends RefCounted

static func can_attack_beast(attacker: BeastInstance, defender: BeastInstance, current_turn: int, enemy_field_beasts: Array = []) -> Dictionary:
	if not attacker or not defender:
		return {"valid": false, "error": "Invalid combat participants"}
		
	if not attacker.can_attack(current_turn):
		if RulesConfig.SUMMONING_SICKNESS and attacker.summoned_turn == current_turn:
			return {"valid": false, "error": attacker.card_data.name + " has summoning sickness and cannot attack this turn"}
		if attacker.stun_turns > 0:
			return {"valid": false, "error": attacker.card_data.name + " is stunned"}
		if attacker.freeze_turns > 0:
			return {"valid": false, "error": attacker.card_data.name + " is frozen"}
		return {"valid": false, "error": attacker.card_data.name + " has already attacked maximum times this turn"}
		
	if attacker.controller_id == defender.controller_id:
		return {"valid": false, "error": "Cannot attack friendly beast"}
		
	if defender.is_dead():
		return {"valid": false, "error": "Target beast is already defeated"}

	# Taunt / Sentinel check: if defender lacks taunt but another active enemy beast has taunt, must attack taunt
	if not defender.has_keyword("taunt") and not defender.has_keyword("sentinel"):
		for b in enemy_field_beasts:
			if b is BeastInstance and not b.is_dead() and (b.has_keyword("taunt") or b.has_keyword("sentinel")):
				return {"valid": false, "error": "Must target a Beast with Taunt / Sentinel"}
		
	return {"valid": true, "error": ""}

static func can_attack_player_direct(attacker: BeastInstance, enemy_field_beasts: Array, current_turn: int) -> Dictionary:
	if not attacker:
		return {"valid": false, "error": "Invalid attacker"}
		
	if not attacker.can_attack(current_turn):
		if RulesConfig.SUMMONING_SICKNESS and attacker.summoned_turn == current_turn:
			return {"valid": false, "error": attacker.card_data.name + " has summoning sickness"}
		return {"valid": false, "error": attacker.card_data.name + " cannot attack this turn"}
		
	# Direct attack only allowed if opposing player controls no beasts
	var active_defenders = 0
	for b in enemy_field_beasts:
		if b is BeastInstance and not b.is_dead():
			active_defenders += 1
			
	if active_defenders > 0:
		return {
			"valid": false, 
			"error": "Cannot attack player directly while opposing player controls " + str(active_defenders) + " beast(s)"
		}
		
	return {"valid": true, "error": ""}

static func execute_beast_combat(attacker: BeastInstance, defender: BeastInstance, current_turn: int, game_state = null, enemy_field_beasts: Array = []) -> Dictionary:
	var check = can_attack_beast(attacker, defender, current_turn, enemy_field_beasts)
	if not check.valid:
		return {"success": false, "error": check.error}
		
	attacker.attacks_performed += 1
	var attacker_dmg = attacker.get_attack()
	var defender_dmg = defender.get_attack()
	var defender_hp_before = defender.current_hp + defender.shield_hp

	var attacker_has_first_strike = attacker.has_keyword("first_strike")
	var defender_has_first_strike = defender.has_keyword("first_strike")

	var dealt_to_defender = 0
	var dealt_to_attacker = 0

	if attacker_has_first_strike and not defender_has_first_strike:
		dealt_to_defender = defender.take_damage(attacker_dmg)
		if not defender.is_dead():
			dealt_to_attacker = attacker.take_damage(defender_dmg)
	elif defender_has_first_strike and not attacker_has_first_strike:
		dealt_to_attacker = attacker.take_damage(defender_dmg)
		if not attacker.is_dead():
			dealt_to_defender = defender.take_damage(attacker_dmg)
	else:
		dealt_to_defender = defender.take_damage(attacker_dmg)
		dealt_to_attacker = attacker.take_damage(defender_dmg)
	
	var defender_died = defender.is_dead()
	var attacker_died = attacker.is_dead()

	# Lifesteal: heal attacker controller if attacker has lifesteal
	var lifesteal_healed = 0
	if attacker.has_keyword("lifesteal") and dealt_to_defender > 0:
		lifesteal_healed = 2
		if attacker.card_data and attacker.card_data.ability:
			lifesteal_healed = int(attacker.card_data.ability.get("amount", 2))
		if game_state and game_state.has_method("heal_player"):
			game_state.heal_player(attacker.controller_id, lifesteal_healed)

	# Trample / Pierce: excess damage pierces to opposing player
	var trample_damage = 0
	if (attacker.has_keyword("trample") or attacker.has_keyword("pierce")) and defender_died:
		trample_damage = maxi(0, attacker_dmg - defender_hp_before)
		if game_state and game_state.has_method("deal_player_damage") and trample_damage > 0:
			game_state.deal_player_damage(defender.controller_id, trample_damage)
	
	return {
		"success": true,
		"attacker_damage_dealt": dealt_to_defender,
		"counter_damage_dealt": dealt_to_attacker,
		"defender_died": defender_died,
		"attacker_died": attacker_died,
		"lifesteal_healed": lifesteal_healed,
		"trample_damage": trample_damage,
		"details": attacker.card_data.name + " (" + str(attacker_dmg) + " ATK) attacked " + defender.card_data.name + " (" + str(defender_dmg) + " ATK)"
	}

static func execute_direct_attack(attacker: BeastInstance, defender_player_id: int, game_state, current_turn: int) -> Dictionary:
	var enemy_field = game_state.get_field(defender_player_id)
	var check = can_attack_player_direct(attacker, enemy_field, current_turn)
	if not check.valid:
		return {"success": false, "error": check.error}
		
	attacker.attacks_performed += 1
	var dmg = attacker.get_attack()
	game_state.deal_player_damage(defender_player_id, dmg)

	var lifesteal_healed = 0
	if attacker.has_keyword("lifesteal") and dmg > 0:
		lifesteal_healed = 2
		if attacker.card_data and attacker.card_data.ability:
			lifesteal_healed = int(attacker.card_data.ability.get("amount", 2))
		if game_state and game_state.has_method("heal_player"):
			game_state.heal_player(attacker.controller_id, lifesteal_healed)
	
	return {
		"success": true,
		"damage_dealt": dmg,
		"lifesteal_healed": lifesteal_healed,
		"details": attacker.card_data.name + " struck Player " + str(defender_player_id + 1) + " directly for " + str(dmg) + " damage!"
	}
