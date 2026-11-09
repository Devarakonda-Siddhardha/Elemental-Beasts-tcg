class_name BeastInstance
extends RefCounted

var instance_id: int = 0
var card_data: CardData
var controller_id: int = 0 # 0 = Player, 1 = Opponent / AI

# Dynamic combat attributes
var current_hp: int = 0
var max_hp: int = 0
var base_attack: int = 0
var bonus_attack: int = 0
var shield_hp: int = 0

# Turn states
var attacks_performed: int = 0
var max_attacks_per_turn: int = 1
var ability_used_this_turn: bool = false
var summoned_turn: int = 0

# Status durations (in turns remaining)
var stun_turns: int = 0
var freeze_turns: int = 0
var is_paralyzed: bool = false

# Materials (for Fusion Dragons, holds the underlying base dragons)
var fusion_materials: Array[CardData] = []

# Relics / Equipment cards attached to this beast
var attached_relics: Array[CardData] = []

static var _next_id: int = 1

static func create(p_card_data: CardData, p_controller: int, p_turn: int) -> BeastInstance:
	var b = BeastInstance.new()
	b.instance_id = _next_id
	_next_id += 1
	b.card_data = p_card_data
	b.controller_id = p_controller
	b.current_hp = p_card_data.hp
	b.max_hp = p_card_data.max_hp
	b.base_attack = p_card_data.attack
	b.summoned_turn = p_turn
	b.max_attacks_per_turn = 1
	return b

func get_attack() -> int:
	return maxi(0, base_attack + bonus_attack)

func get_total_attack() -> int:
	return get_attack()

func is_immune_to_spells() -> bool:
	if not card_data:
		return false
	if card_data.id == "shadow_dragon" or card_data.id == "transcendent_shadow_dragon":
		return true
	if card_data.ability:
		if card_data.ability.get("spell_immunity", false) == true or card_data.ability.get("effect") == "spell_immunity" or card_data.ability.get("effect") == "direct_pierce_spell_immunity":
			return true
	return false

func can_attack(current_turn: int) -> bool:
	if stun_turns > 0 or freeze_turns > 0 or is_paralyzed:
		return false
	if RulesConfig.SUMMONING_SICKNESS and summoned_turn == current_turn:
		return false
	return attacks_performed < max_attacks_per_turn

func can_use_ability() -> bool:
	if stun_turns > 0 or is_paralyzed:
		return false
	return not ability_used_this_turn

func take_damage(amount: int) -> int:
	var remaining = amount
	if shield_hp > 0:
		if shield_hp >= remaining:
			shield_hp -= remaining
			remaining = 0
		else:
			remaining -= shield_hp
			shield_hp = 0
			
	current_hp -= remaining
	return remaining

func heal(amount: int) -> int:
	var prev = current_hp
	current_hp = mini(max_hp, current_hp + amount)
	return current_hp - prev

func is_dead() -> bool:
	return current_hp <= 0

func turn_refresh() -> void:
	attacks_performed = 0
	ability_used_this_turn = false
	bonus_attack = get_relic_attack_bonus()
	max_attacks_per_turn = 1
	if stun_turns > 0:
		stun_turns -= 1
	if freeze_turns > 0:
		freeze_turns -= 1

func attach_relic(relic: CardData) -> void:
	if not relic:
		return
	attached_relics.append(relic)
	if relic.ability:
		var atk_b = int(relic.ability.get("atk_bonus", 0))
		bonus_attack += atk_b
		var sh_b = int(relic.ability.get("shield_hp", 0))
		shield_hp += sh_b
		var hp_b = int(relic.ability.get("hp_bonus", 0))
		if hp_b > 0:
			max_hp += hp_b
			current_hp += hp_b

func get_relic_attack_bonus() -> int:
	var total := 0
	for r in attached_relics:
		if r.ability:
			total += int(r.ability.get("atk_bonus", 0))
	return total

func has_keyword(kw: String) -> bool:
	var check_kw = kw.to_lower()
	if card_data:
		for k in card_data.keywords:
			if k.to_lower() == check_kw:
				return true
		if card_data.ability:
			if str(card_data.ability.get("keyword", "")).to_lower() == check_kw:
				return true
			if str(card_data.ability.get("effect", "")).to_lower() == check_kw:
				return true
			if card_data.ability.get(check_kw, false) == true:
				return true
	for relic in attached_relics:
		for k in relic.keywords:
			if k.to_lower() == check_kw:
				return true
		if relic.ability:
			if str(relic.ability.get("keyword", "")).to_lower() == check_kw:
				return true
			if str(relic.ability.get("effect", "")).to_lower() == check_kw:
				return true
			if relic.ability.get(check_kw, false) == true:
				return true
	return false

func apply_status(status_name: String, turns: int) -> void:
	if status_name == "freeze":
		freeze_turns = maxi(freeze_turns, turns)
	elif status_name == "stun":
		stun_turns = maxi(stun_turns, turns)

func is_frozen() -> bool:
	return freeze_turns > 0

func is_stunned() -> bool:
	return stun_turns > 0

func cleanse() -> void:
	freeze_turns = 0
	stun_turns = 0
	is_paralyzed = false

func check_paralysis_recovery() -> Dictionary:
	if not is_paralyzed:
		return {"was_paralyzed": false, "recovered": false, "coin": "none"}
	var is_heads = randf() < 0.5
	if is_heads:
		is_paralyzed = false
		return {"was_paralyzed": true, "recovered": true, "coin": "heads"}
	else:
		return {"was_paralyzed": true, "recovered": false, "coin": "tails"}
