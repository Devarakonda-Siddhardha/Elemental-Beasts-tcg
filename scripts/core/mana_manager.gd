class_name ManaManager
extends RefCounted

signal mana_changed(current: int, max_val: int)

var current_mana: int = RulesConfig.STARTING_MANA
var max_mana: int = RulesConfig.MAX_NORMAL_MANA

func turn_refresh() -> void:
	# Rule: Replenished to 5 each turn. Unspent Mana does not carry over.
	current_mana = RulesConfig.MANA_PER_TURN
	max_mana = RulesConfig.MAX_NORMAL_MANA
	mana_changed.emit(current_mana, max_mana)

func can_spend(amount: int) -> bool:
	return amount >= 0 and current_mana >= amount

func spend(amount: int) -> bool:
	if can_spend(amount):
		current_mana -= amount
		mana_changed.emit(current_mana, max_mana)
		return true
	return false

func add(amount: int) -> void:
	current_mana += amount
	mana_changed.emit(current_mana, max_mana)

func add_mana(amount: int) -> void:
	add(amount)

func reset() -> void:
	current_mana = RulesConfig.STARTING_MANA
	max_mana = RulesConfig.MAX_NORMAL_MANA
	mana_changed.emit(current_mana, max_mana)
