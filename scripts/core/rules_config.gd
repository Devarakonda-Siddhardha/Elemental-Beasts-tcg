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

# [CONFIRMED / REMEMBERED] Evolution rules
const DEFAULT_EVOLUTION_STONE_COST: int = 2

# [PROVISIONAL] Stone placement rules
const STONE_PLACEMENTS_PER_TURN: int = 1

# [PROVISIONAL] Match & Board rules
const STARTING_PLAYER_HP: int = 30
const STARTING_HAND_SIZE: int = 5
const MAX_HAND_SIZE: int = 7
const MAX_FIELD_BEASTS: int = 4
const STANDARD_DECK_SIZE: int = 30
const SUMMONING_SICKNESS: bool = true
const COMPASS_MANA_COST: int = 2

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
