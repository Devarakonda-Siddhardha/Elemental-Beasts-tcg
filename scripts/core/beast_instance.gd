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

# Materials (for Fusion Dragons, holds the underlying base dragons)
var fusion_materials: Array[CardData] = []

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

func is_immune_to_spells() -> bool:
	if card_data.ability and card_data.ability.get("effect") == "spell_immunity":
		return true
	return false

func can_attack(current_turn: int) -> bool:
	if stun_turns > 0 or freeze_turns > 0:
		return false
	if RulesConfig.SUMMONING_SICKNESS and summoned_turn == current_turn:
		return false
	return attacks_performed < max_attacks_per_turn

func can_use_ability() -> bool:
	if stun_turns > 0:
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
	bonus_attack = 0
	max_attacks_per_turn = 1
	if stun_turns > 0:
		stun_turns -= 1
	if freeze_turns > 0:
		freeze_turns -= 1
