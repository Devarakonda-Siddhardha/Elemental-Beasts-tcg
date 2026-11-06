class_name StoneManager
extends RefCounted

signal stone_pile_changed(pile: Dictionary)
signal stone_discard_changed(discard: Dictionary)

# Stone pile storing count of each element
# e.g. {"fire": 2, "shadow": 1, ...}
var stone_pile: Dictionary = {}
var stone_discard: Dictionary = {}
var stones_placed_this_turn: int = 0

func _init() -> void:
	clear()

func clear() -> void:
	stone_pile.clear()
	stone_discard.clear()
	stones_placed_this_turn = 0
	for el in RulesConfig.CONFIRMED_ELEMENTS:
		stone_pile[el] = 0
		stone_discard[el] = 0
	for el in RulesConfig.PROVISIONAL_ELEMENTS:
		stone_pile[el] = 0
		stone_discard[el] = 0

func turn_refresh() -> void:
	stones_placed_this_turn = 0

func can_place_stone() -> bool:
	return stones_placed_this_turn < RulesConfig.STONE_PLACEMENTS_PER_TURN

func place_stone(element_name: String) -> bool:
	if not can_place_stone():
		return false
	var el = element_name.to_lower()
	if not stone_pile.has(el):
		stone_pile[el] = 0
	stone_pile[el] += 1
	stones_placed_this_turn += 1
	stone_pile_changed.emit(stone_pile)
	return true

func add_stone_direct(element_name: String, count: int = 1) -> void:
	var el = element_name.to_lower()
	if not stone_pile.has(el):
		stone_pile[el] = 0
	stone_pile[el] += count
	stone_pile_changed.emit(stone_pile)

func get_stone_count(element_name: String) -> int:
	var el = element_name.to_lower()
	return stone_pile.get(el, 0)

func get_total_stones() -> int:
	var total: int = 0
	for count in stone_pile.values():
		total += int(count)
	return total

func can_spend_stones(cost: Dictionary) -> bool:
	return has_stones(cost)

func has_stones(required: Dictionary) -> bool:
	# Check specific elements
	var total_any_needed = required.get("any_stone", 0)
	var available_any = 0
	
	for el in required.keys():
		if el == "any_stone":
			continue
		var needed = int(required[el])
		var available = int(stone_pile.get(el, 0))
		if available < needed:
			return false
			
	if total_any_needed > 0:
		# Count remaining stones not committed to specific requirements
		var uncommitted = 0
		for el in stone_pile.keys():
			var committed = int(required.get(el, 0))
			var count = int(stone_pile[el])
			if count > committed:
				uncommitted += (count - committed)
		if uncommitted < total_any_needed:
			return false
			
	return true

func spend_stones(cost: Dictionary) -> bool:
	if not has_stones(cost):
		return false
		
	# Spend specific stones first
	for el in cost.keys():
		if el == "any_stone":
			continue
		var needed = int(cost[el])
		stone_pile[el] -= needed
		stone_discard[el] = int(stone_discard.get(el, 0)) + needed
		
	# Spend any_stone if requested (pick from largest pile)
	var any_needed = int(cost.get("any_stone", 0))
	while any_needed > 0:
		var best_el = ""
		var max_val = 0
		for el in stone_pile.keys():
			var val = int(stone_pile[el])
			if val > max_val:
				max_val = val
				best_el = el
		if best_el == "" or max_val <= 0:
			break
		stone_pile[best_el] -= 1
		stone_discard[best_el] = int(stone_discard.get(best_el, 0)) + 1
		any_needed -= 1
		
	stone_pile_changed.emit(stone_pile)
	stone_discard_changed.emit(stone_discard)
	return true

func discard_stones(cost: Dictionary) -> bool:
	return spend_stones(cost)
