class_name SoundManagerClass
extends Node

const SoundGen = preload("res://scripts/audio/procedural_sound_generator.gd")

var sound_cache: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8
var current_player_index: int = 0

var is_muted: bool = false
var master_volume_db: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_pregenerate_sounds()

func _setup_audio_players() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		player_pool.append(player)

func _pregenerate_sounds() -> void:
	sound_cache["card_hover"] = SoundGen.generate_card_hover()
	sound_cache["card_click"] = SoundGen.generate_card_click()
	sound_cache["card_play"] = SoundGen.generate_card_play()
	sound_cache["mana_spend"] = SoundGen.generate_mana_spend()
	sound_cache["mana_refresh"] = SoundGen.generate_mana_refresh()
	sound_cache["stone_place"] = SoundGen.generate_stone_place()
	sound_cache["stone_spend"] = SoundGen.generate_stone_spend()
	sound_cache["evolution"] = SoundGen.generate_evolution()
	sound_cache["fusion"] = SoundGen.generate_fusion()
	sound_cache["attack_slash"] = SoundGen.generate_attack_slash()
	sound_cache["damage_hit"] = SoundGen.generate_damage_hit()
	sound_cache["beast_defeat"] = SoundGen.generate_beast_defeat()
	sound_cache["spell_cast"] = SoundGen.generate_spell_cast()
	sound_cache["status_applied"] = SoundGen.generate_status_applied()
	sound_cache["turn_change"] = SoundGen.generate_turn_change()
	sound_cache["victory"] = SoundGen.generate_victory()
	sound_cache["defeat"] = SoundGen.generate_defeat()
	sound_cache["ui_click"] = SoundGen.generate_ui_click()

func play_sound(sound_name: String, volume_db_offset: float = 0.0, pitch_scale: float = 1.0) -> void:
	if is_muted or player_pool.is_empty():
		return
		
	if not sound_cache.has(sound_name):
		return
		
	var stream: AudioStreamWAV = sound_cache[sound_name]
	var player = player_pool[current_player_index]
	current_player_index = (current_player_index + 1) % POOL_SIZE
	
	player.stream = stream
	player.volume_db = master_volume_db + volume_db_offset
	player.pitch_scale = pitch_scale
	player.play()

# Convenience Sound API
func play_card_hover() -> void:
	play_sound("card_hover", -4.0, randf_range(0.95, 1.05))

func play_card_click() -> void:
	play_sound("card_click", -2.0, randf_range(0.98, 1.02))

func play_card_play() -> void:
	play_sound("card_play", 1.0, randf_range(0.95, 1.05))

func play_stone_place() -> void:
	play_sound("stone_place", 0.0, randf_range(0.96, 1.04))

func play_stone_spend() -> void:
	play_sound("stone_spend", -1.0, randf_range(0.95, 1.05))

func play_mana_spend() -> void:
	play_sound("mana_spend", 0.0, randf_range(0.98, 1.02))

func play_mana_refresh() -> void:
	play_sound("mana_refresh", 1.0, 1.0)

func play_evolution() -> void:
	play_sound("evolution", 2.0, 1.0)

func play_fusion() -> void:
	play_sound("fusion", 3.0, 1.0)

func play_attack() -> void:
	play_sound("attack_slash", 1.0, randf_range(0.94, 1.06))

func play_damage() -> void:
	play_sound("damage_hit", 2.0, randf_range(0.95, 1.05))

func play_beast_defeat() -> void:
	play_sound("beast_defeat", 0.0, randf_range(0.95, 1.02))

func play_spell() -> void:
	play_sound("spell_cast", 1.0, randf_range(0.97, 1.03))

func play_status() -> void:
	play_sound("status_applied", 0.0, randf_range(0.95, 1.05))

func play_turn_change() -> void:
	play_sound("turn_change", 1.0, 1.0)

func play_victory() -> void:
	play_sound("victory", 3.0, 1.0)

func play_defeat() -> void:
	play_sound("defeat", 2.0, 1.0)

func play_ui_click() -> void:
	play_sound("ui_click", -2.0, randf_range(0.98, 1.02))
