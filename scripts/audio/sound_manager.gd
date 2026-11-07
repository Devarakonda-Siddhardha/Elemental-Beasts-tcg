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
var sfx_muted: bool = false
var vo_muted: bool = false
var sfx_volume_db: float = 0.0
var vo_volume_db: float = 0.0

const SETTINGS_PATH: String = "user://audio_settings.cfg"

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
	load_audio_settings()
	_setup_audio_players()
	_pregenerate_sounds()

func load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sfx_muted = bool(cfg.get_value("audio", "sfx_muted", false))
		vo_muted = bool(cfg.get_value("audio", "vo_muted", false))
		sfx_volume_db = float(cfg.get_value("audio", "sfx_volume_db", 0.0))
		vo_volume_db = float(cfg.get_value("audio", "vo_volume_db", 0.0))

func save_audio_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_muted", sfx_muted)
	cfg.set_value("audio", "vo_muted", vo_muted)
	cfg.set_value("audio", "sfx_volume_db", sfx_volume_db)
	cfg.set_value("audio", "vo_volume_db", vo_volume_db)
	cfg.save(SETTINGS_PATH)

func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	if sfx_muted:
		for p in player_pool:
			if p and p.playing:
				p.stop()
	save_audio_settings()

func set_vo_muted(muted: bool) -> void:
	vo_muted = muted
	if vo_muted and vo_player and vo_player.playing:
		vo_player.stop()
	save_audio_settings()

func set_sfx_volume_percent(pct: float) -> void:
	var clamped := clampf(pct, 0.0, 100.0)
	if clamped <= 0.5:
		sfx_volume_db = -40.0
	else:
		sfx_volume_db = linear_to_db(clamped / 100.0)
	save_audio_settings()

func set_vo_volume_percent(pct: float) -> void:
	var clamped := clampf(pct, 0.0, 100.0)
	if clamped <= 0.5:
		vo_volume_db = -40.0
	else:
		vo_volume_db = linear_to_db(clamped / 100.0)
	if vo_player and vo_player.playing:
		vo_player.volume_db = master_volume_db + vo_volume_db + 2.5
	save_audio_settings()

func get_sfx_volume_percent() -> float:
	if sfx_volume_db <= -39.0:
		return 0.0
	return clampf(round(db_to_linear(sfx_volume_db) * 100.0), 0.0, 100.0)

func get_vo_volume_percent() -> float:
	if vo_volume_db <= -39.0:
		return 0.0
	return clampf(round(db_to_linear(vo_volume_db) * 100.0), 0.0, 100.0)

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
	if is_muted or sfx_muted or sfx_volume_db <= -39.0 or player_pool.is_empty():
		return
		
	if not sound_cache.has(sound_name):
		return
		
	var stream: AudioStream = sound_cache[sound_name]
	var player = player_pool[current_player_index]
	current_player_index = (current_player_index + 1) % POOL_SIZE
	
	player.stream = stream
	player.volume_db = master_volume_db + sfx_volume_db + volume_db_offset
	player.pitch_scale = pitch_scale
	player.play()

func play_voice(vo_name: String, volume_db_offset: float = 2.5) -> void:
	if is_muted or vo_muted or vo_volume_db <= -39.0 or vo_player == null:
		return
	var clean_name := vo_name.trim_suffix(".mp3")
	if not vo_cache.has(clean_name):
		return
	var stream: AudioStream = vo_cache[clean_name]
	vo_player.stop()
	vo_player.stream = stream
	vo_player.volume_db = master_volume_db + vo_volume_db + volume_db_offset
	vo_player.pitch_scale = 1.0
	vo_player.play()

func show_audio_settings_modal(parent_node: Node) -> Control:
	if not parent_node:
		return null
	if parent_node.has_node("AudioSettingsModal"):
		parent_node.get_node("AudioSettingsModal").queue_free()

	var overlay := ColorRect.new()
	overlay.name = "AudioSettingsModal"
	overlay.color = Color(0.02, 0.02, 0.06, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 90
	parent_node.add_child(overlay)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 340)
	panel.position = Vector2(380, 190)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.14, 0.98)
	sb.border_color = Color(0.95, 0.78, 0.28, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚙ AUDIO & COMMENTATOR SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	vbox.add_child(title)

	# Sound Effects Section
	var sfx_box := VBoxContainer.new()
	sfx_box.add_theme_constant_override("separation", 6)
	vbox.add_child(sfx_box)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 12)
	sfx_box.add_child(sfx_row)

	var sfx_lbl := Label.new()
	sfx_lbl.text = "🔊 Sound Effects (SFX)"
	sfx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_lbl.add_theme_font_size_override("font_size", 15)
	sfx_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	sfx_row.add_child(sfx_lbl)

	var sfx_mute_btn := CheckButton.new()
	sfx_mute_btn.text = "Enabled" if not sfx_muted else "Muted"
	sfx_mute_btn.button_pressed = not sfx_muted
	sfx_row.add_child(sfx_mute_btn)

	var sfx_slider_row := HBoxContainer.new()
	sfx_slider_row.add_theme_constant_override("separation", 10)
	sfx_box.add_child(sfx_slider_row)

	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.step = 5.0
	sfx_slider.value = get_sfx_volume_percent()
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.custom_minimum_size = Vector2(280, 24)
	sfx_slider_row.add_child(sfx_slider)

	var sfx_pct_lbl := Label.new()
	sfx_pct_lbl.custom_minimum_size = Vector2(54, 0)
	sfx_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_pct_lbl.text = ("MUTE" if sfx_muted else str(int(sfx_slider.value)) + "%")
	sfx_slider_row.add_child(sfx_pct_lbl)

	# Commentator Voice Section
	var vo_box := VBoxContainer.new()
	vo_box.add_theme_constant_override("separation", 6)
	vbox.add_child(vo_box)

	var vo_row := HBoxContainer.new()
	vo_row.add_theme_constant_override("separation", 12)
	vo_box.add_child(vo_row)

	var vo_lbl := Label.new()
	vo_lbl.text = "🎙️ Commentator Voice (Sudha-Devarakonda)"
	vo_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vo_lbl.add_theme_font_size_override("font_size", 15)
	vo_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	vo_row.add_child(vo_lbl)

	var vo_mute_btn := CheckButton.new()
	vo_mute_btn.text = "Enabled" if not vo_muted else "Muted"
	vo_mute_btn.button_pressed = not vo_muted
	vo_row.add_child(vo_mute_btn)

	var vo_slider_row := HBoxContainer.new()
	vo_slider_row.add_theme_constant_override("separation", 10)
	vo_box.add_child(vo_slider_row)

	var vo_slider := HSlider.new()
	vo_slider.min_value = 0.0
	vo_slider.max_value = 100.0
	vo_slider.step = 5.0
	vo_slider.value = get_vo_volume_percent()
	vo_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vo_slider.custom_minimum_size = Vector2(280, 24)
	vo_slider_row.add_child(vo_slider)

	var vo_pct_lbl := Label.new()
	vo_pct_lbl.custom_minimum_size = Vector2(54, 0)
	vo_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vo_pct_lbl.text = ("MUTE" if vo_muted else str(int(vo_slider.value)) + "%")
	vo_slider_row.add_child(vo_pct_lbl)

	sfx_mute_btn.toggled.connect(func(enabled: bool):
		set_sfx_muted(not enabled)
		sfx_mute_btn.text = "Enabled" if enabled else "Muted"
		sfx_pct_lbl.text = ("MUTE" if sfx_muted else str(int(sfx_slider.value)) + "%")
		if enabled:
			play_ui_click()
	)
	sfx_slider.value_changed.connect(func(val: float):
		set_sfx_volume_percent(val)
		if val > 0.0 and sfx_muted:
			set_sfx_muted(false)
			sfx_mute_btn.button_pressed = true
			sfx_mute_btn.text = "Enabled"
		sfx_pct_lbl.text = ("MUTE" if sfx_muted else str(int(val)) + "%")
	)

	vo_mute_btn.toggled.connect(func(enabled: bool):
		set_vo_muted(not enabled)
		vo_mute_btn.text = "Enabled" if enabled else "Muted"
		vo_pct_lbl.text = ("MUTE" if vo_muted else str(int(vo_slider.value)) + "%")
		if enabled:
			play_voice("vo_your_turn")
	)
	vo_slider.value_changed.connect(func(val: float):
		set_vo_volume_percent(val)
		if val > 0.0 and vo_muted:
			set_vo_muted(false)
			vo_mute_btn.button_pressed = true
			vo_mute_btn.text = "Enabled"
		vo_pct_lbl.text = ("MUTE" if vo_muted else str(int(val)) + "%")
	)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var test_vo_btn := Button.new()
	test_vo_btn.text = "🎙️ Test Voice"
	test_vo_btn.custom_minimum_size = Vector2(140, 36)
	test_vo_btn.pressed.connect(func():
		play_voice("vo_your_turn")
	)
	btn_row.add_child(test_vo_btn)

	var close_btn := Button.new()
	close_btn.text = "✔ Done"
	close_btn.custom_minimum_size = Vector2(140, 36)
	close_btn.pressed.connect(func():
		play_ui_click()
		overlay.queue_free()
	)
	btn_row.add_child(close_btn)

	return overlay

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

