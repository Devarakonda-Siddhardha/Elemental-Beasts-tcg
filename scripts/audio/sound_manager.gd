class_name SoundManagerClass
extends Node

const SoundGen = preload("res://scripts/audio/procedural_sound_generator.gd")

var sound_cache: Dictionary = {}
var vo_cache: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
var vo_player: AudioStreamPlayer = null
const POOL_SIZE: int = 8
var current_player_index: int = 0

var is_muted: bool = false
var master_volume_db: float = 0.0

const SFX_NAMES: Array[String] = [
	"card_hover",
	"card_click",
	"card_play",
	"mana_spend",
	"mana_refresh",
	"stone_place",
	"stone_spend",
	"evolution",
	"fusion",
	"attack_slash",
	"damage_hit",
	"beast_defeat",
	"spell_cast",
	"status_applied",
	"turn_change",
	"victory",
	"defeat",
	"ui_click",
	"coin_flip",
	"deck_shuffle",
	"pack_rip"
]

const VO_NAMES: Array[String] = [
	"vo_welcome",
	"vo_coin_toss",
	"vo_heads_first",
	"vo_tails_second",
	"vo_your_turn",
	"vo_enemy_turn",
	"vo_evolution",
	"vo_fusion",
	"vo_transcendence",
	"vo_ascension",
	"vo_god_dragon",
	"vo_direct_attack",
	"vo_victory",
	"vo_defeat",
	"vo_pack_open"
]

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
	vo_player = AudioStreamPlayer.new()
	vo_player.bus = "Master"
	add_child(vo_player)

func _load_mp3_stream(res_path: String) -> AudioStream:
	if FileAccess.file_exists(res_path):
		var f := FileAccess.open(res_path, FileAccess.READ)
		if f:
			var bytes := f.get_buffer(f.get_length())
			f.close()
			if bytes.size() > 0:
				var mp3 := AudioStreamMP3.new()
				mp3.data = bytes
				return mp3
	if ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is AudioStream:
			return res
	return null

func _pregenerate_sounds() -> void:
	var fallbacks: Dictionary = {
		"card_hover": Callable(SoundGen, "generate_card_hover"),
		"card_click": Callable(SoundGen, "generate_card_click"),
		"card_play": Callable(SoundGen, "generate_card_play"),
		"mana_spend": Callable(SoundGen, "generate_mana_spend"),
		"mana_refresh": Callable(SoundGen, "generate_mana_refresh"),
		"stone_place": Callable(SoundGen, "generate_stone_place"),
		"stone_spend": Callable(SoundGen, "generate_stone_spend"),
		"evolution": Callable(SoundGen, "generate_evolution"),
		"fusion": Callable(SoundGen, "generate_fusion"),
		"attack_slash": Callable(SoundGen, "generate_attack_slash"),
		"damage_hit": Callable(SoundGen, "generate_damage_hit"),
		"beast_defeat": Callable(SoundGen, "generate_beast_defeat"),
		"spell_cast": Callable(SoundGen, "generate_spell_cast"),
		"status_applied": Callable(SoundGen, "generate_status_applied"),
		"turn_change": Callable(SoundGen, "generate_turn_change"),
		"victory": Callable(SoundGen, "generate_victory"),
		"defeat": Callable(SoundGen, "generate_defeat"),
		"ui_click": Callable(SoundGen, "generate_ui_click"),
		"coin_flip": Callable(SoundGen, "generate_stone_place"),
		"deck_shuffle": Callable(SoundGen, "generate_card_hover"),
		"pack_rip": Callable(SoundGen, "generate_fusion")
	}

	for sfx_name in SFX_NAMES:
		var path := "res://assets/audio/sfx/" + sfx_name + ".mp3"
		var stream := _load_mp3_stream(path)
		if stream != null:
			sound_cache[sfx_name] = stream
		elif fallbacks.has(sfx_name):
			sound_cache[sfx_name] = fallbacks[sfx_name].call()

	for vo_name in VO_NAMES:
		var vo_path := "res://assets/audio/vo/" + vo_name + ".mp3"
		var vo_stream := _load_mp3_stream(vo_path)
		if vo_stream != null:
			vo_cache[vo_name] = vo_stream

func play_sound(sound_name: String, volume_db_offset: float = 0.0, pitch_scale: float = 1.0) -> void:
	if is_muted or player_pool.is_empty():
		return
		
	if not sound_cache.has(sound_name):
		return
		
	var stream: AudioStream = sound_cache[sound_name]
	var player = player_pool[current_player_index]
	current_player_index = (current_player_index + 1) % POOL_SIZE
	
	player.stream = stream
	player.volume_db = master_volume_db + volume_db_offset
	player.pitch_scale = pitch_scale
	player.play()

func play_voice(vo_name: String, volume_db_offset: float = 2.5) -> void:
	if is_muted or vo_player == null:
		return
	var clean_name := vo_name.trim_suffix(".mp3")
	if not vo_cache.has(clean_name):
		return
	var stream: AudioStream = vo_cache[clean_name]
	vo_player.stop()
	vo_player.stream = stream
	vo_player.volume_db = master_volume_db + volume_db_offset
	vo_player.pitch_scale = 1.0
	vo_player.play()

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

func play_coin_flip() -> void:
	play_sound("coin_flip", 1.5, randf_range(0.97, 1.03))

func play_deck_shuffle() -> void:
	play_sound("deck_shuffle", 0.5, randf_range(0.97, 1.03))

func play_pack_rip() -> void:
	play_sound("pack_rip", 2.5, 1.0)

