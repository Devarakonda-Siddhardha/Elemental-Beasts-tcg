class_name RulesConfig
extends RefCounted

# ==============================================================================
# ELEMENTAL BEASTS TCG - CONFIGURABLE RULES CONFIGURATION
# Categorized into CONFIRMED, REMEMBERED, and PROVISIONAL rules.
# ==============================================================================

# [REMEMBERED] Mana rules
const STARTING_MANA: int = 5
const MANA_PER_TURN: int = 5
const MAX_NORMAL_MANA: int = 5
const LITTLE_DRAGON_MANA_COST: int = 2

# [CONFIRMED / REMEMBERED] Evolution & Apex Dragon rules
const DEFAULT_EVOLUTION_STONE_COST: int = 2
const TRANSCENDENCE_STONE_COST: int = 5
const ASCENSION_STONE_COST_EACH: int = 3
const GOD_DRAGON_REQUIRED_BEASTS: int = 3
const GOD_DRAGON_STONE_EACH: int = 1
const GOD_DRAGON_MAX_PER_DECK: int = 1

# [PROVISIONAL] Stone placement rules
const STONE_PLACEMENTS_PER_TURN: int = 1

# [PROVISIONAL] Match & Board rules
const STARTING_PLAYER_HP: int = 30
const STARTING_HAND_SIZE: int = 5
const MAX_HAND_SIZE: int = 7
const MAX_FIELD_BEASTS: int = 4
const STANDARD_DECK_SIZE: int = 40
const MAX_COPIES_PER_CARD: int = 4
const SUMMONING_SICKNESS: bool = true
const COMPASS_MANA_COST: int = 2

static func validate_deck(card_ids: Array) -> Dictionary:
	if card_ids.size() != STANDARD_DECK_SIZE:
		return {"valid": false, "error": "Deck must contain exactly " + str(STANDARD_DECK_SIZE) + " cards (currently " + str(card_ids.size()) + ")"}
		
	var counts: Dictionary = {}
	for cid in card_ids:
		counts[cid] = counts.get(cid, 0) + 1
		
	if counts.get("god_dragon", 0) > GOD_DRAGON_MAX_PER_DECK:
		return {"valid": false, "error": "God Dragon is limited to " + str(GOD_DRAGON_MAX_PER_DECK) + " copy per deck"}
		
	for cid in counts:
		if cid != "god_dragon" and not cid.ends_with("_stone") and counts[cid] > MAX_COPIES_PER_CARD:
			return {"valid": false, "error": cid + " exceeds max copy limit (" + str(MAX_COPIES_PER_CARD) + ")"}
			
	return {"valid": true, "error": ""}

# Status durations (in turns)
const DEFAULT_STUN_DURATION: int = 1
const DEFAULT_FREEZE_DURATION: int = 1

# Elements list
const CONFIRMED_ELEMENTS: Array[String] = [
	"fire",
	"lightning",
	"shadow",
	"wind",
	"ice",
	"mechanical"
]

const PROVISIONAL_ELEMENTS: Array[String] = [
	"water"
]
